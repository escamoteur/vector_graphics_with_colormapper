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

## Performance

Testing with 350 icons on Pixel 8:
- Baseline (no ColorMapper): 1.21ms avg raster time
- With ColorMapper: 3.22ms avg raster time (~2ms overhead)
- Smooth, stutter-free rendering

## License

BSD-3-Clause (same as original package)
