# vector_graphics with ColorMapper Support

**A patched version of Flutter's `vector_graphics` package that adds `ColorMapper` support for runtime color transformations of `.vec` files.**

This is a fork of the official [`vector_graphics`](https://pub.dev/packages/vector_graphics) package (v1.1.19) with added ColorMapper functionality, providing API compatibility with [`flutter_svg`](https://pub.dev/packages/flutter_svg)'s ColorMapper.

## Why This Patch?

The official `vector_graphics` package renders pre-compiled `.vec` files efficiently but lacks runtime color transformation capabilities. This is a problem when you need to:
- Adapt icon colors to different themes (light/dark mode)
- Apply dynamic color schemes based on context
- Transform colors based on surface backgrounds
- Maintain compatibility with `flutter_svg`'s ColorMapper API

**GitHub Issue:** [flutter/flutter#158859](https://github.com/flutter/flutter/issues/158859)

## What's Added

### 1. ColorMapper Interface
```dart
abstract class ColorMapper {
  const ColorMapper();

  Color substitute(
    String? id,
    String elementName,
    String attributeName,
    Color color,
  );
}
```

### 2. AssetBytesLoader Support
Added optional `colorMapper` parameter:
```dart
const AssetBytesLoader(
  this.assetName, {
  this.assetBundle,
  this.packageName,
  this.colorMapper,  // ← NEW
});
```

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  vector_graphics:
    git:
      url: https://github.com/YOUR_USERNAME/vector_graphics_with_colormapper.git
      ref: main
```

## Usage

```dart
import 'package:vector_graphics/vector_graphics.dart';

class MyColorMapper extends ColorMapper {
  const MyColorMapper({required this.primaryColor});
  final Color primaryColor;

  @override
  Color substitute(String? id, String elementName, String attributeName, Color color) {
    if (color.value == 0xFF000000) return primaryColor;
    return color;
  }
}

VectorGraphic(
  loader: AssetBytesLoader(
    'assets/icon.svg.vec',
    colorMapper: MyColorMapper(primaryColor: Theme.of(context).colorScheme.primary),
  ),
)
```

## Usage with flutter_gen

If you're using `flutter_gen` for asset management, the generated `SvgGenImage.svg()` method doesn't pass `colorMapper` to `.vec` files. You can work around this with an extension method:

**Create `lib/extensions/svg_gen_image_extensions.dart`:**

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart' as svg;
import 'package:vector_graphics/vector_graphics.dart' as vg;
import 'package:your_app/gen/assets.gen.dart';

/// Extension to add ColorMapper support for both .svg and .vec files
extension SvgGenImageColorMapperExtension on SvgGenImage {
  svg.SvgPicture svgWithColorMapper({
    Key? key,
    bool matchTextDirection = false,
    AssetBundle? bundle,
    String? package,
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
    AlignmentGeometry alignment = Alignment.center,
    bool allowDrawingOutsideViewBox = false,
    WidgetBuilder? placeholderBuilder,
    String? semanticsLabel,
    bool excludeFromSemantics = false,
    svg.SvgTheme? theme,
    vg.ColorMapper? colorMapper,
    ColorFilter? colorFilter,
    Clip clipBehavior = Clip.hardEdge,
  }) {
    final svg.BytesLoader loader;
    final isVecFormat = path.endsWith('.vec');

    if (isVecFormat) {
      // For .vec files: Use AssetBytesLoader with ColorMapper
      loader = vg.AssetBytesLoader(
        path,
        assetBundle: bundle,
        packageName: package,
        colorMapper: colorMapper,
      );
    } else {
      // For .svg files: Use SvgAssetLoader with adapted ColorMapper
      loader = svg.SvgAssetLoader(
        path,
        assetBundle: bundle,
        packageName: package,
        theme: theme,
        colorMapper: colorMapper != null
            ? _FlutterSvgColorMapperAdapter(colorMapper)
            : null,
      );
    }

    return svg.SvgPicture(
      loader,
      key: key,
      matchTextDirection: matchTextDirection,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      allowDrawingOutsideViewBox: allowDrawingOutsideViewBox,
      placeholderBuilder: placeholderBuilder,
      semanticsLabel: semanticsLabel,
      excludeFromSemantics: excludeFromSemantics,
      colorFilter: colorFilter,
      clipBehavior: clipBehavior,
    );
  }
}

/// Adapter that converts vg.ColorMapper to svg.ColorMapper for .svg files
class _FlutterSvgColorMapperAdapter extends svg.ColorMapper {
  const _FlutterSvgColorMapperAdapter(this.vgColorMapper);
  final vg.ColorMapper vgColorMapper;

  @override
  Color substitute(String? id, String elementName, String attributeName, Color color) {
    return vgColorMapper.substitute(id, elementName, attributeName, color);
  }
}
```

**Then use it:**

```dart
import 'package:your_app/extensions/svg_gen_image_extensions.dart';
import 'package:vector_graphics/vector_graphics.dart' show ColorMapper;

class MyColorMapper extends ColorMapper {
  const MyColorMapper({required this.foregroundColor});
  final Color foregroundColor;

  @override
  Color substitute(String? id, String elementName, String attributeName, Color color) {
    if (color.computeLuminance() < 0.1) return foregroundColor;
    return color;
  }
}

// Instead of:
// Assets.icons_myIcon.svg(colorMapper: ...) // ❌ Doesn't work for .vec

// Use:
Assets.icons_myIcon.svgWithColorMapper(  // ✅ Works for both .svg and .vec
  colorMapper: MyColorMapper(foregroundColor: theme.primaryColor),
)
```

## Performance

Testing with 350 icons on Pixel 8:
- Baseline (no ColorMapper): 1.21ms avg raster time
- With ColorMapper: 3.22ms avg raster time (~2ms overhead)
- Smooth, stutter-free rendering

## License

BSD-3-Clause (same as original package)
