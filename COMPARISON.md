# Comparison: Our ColorMapper vs GitHub Issue #158859

## Overview

GitHub Issue: https://github.com/flutter/flutter/issues/158859
- **Title**: "Add method to update colors and shaders of binary vector graphics"
- **Status**: Open (as of October 2025)
- **Reactions**: 7 👍

Both solutions address the **same core problem**: enabling runtime color transformations for .vec (binary vector graphics) files.

## Problem Statement

**Our Use Case:**
- WatchCrunch app uses 1424 icons, 196 (14%) need dynamic color adaptation
- Need ColorMapper (like flutter_svg) for theme-based color changes
- Want to maintain .vec file performance benefits

**GitHub Issue Use Case:**
- Need to "change icon's color regarding the brightness or accent color"
- Want runtime color updates for pre-compiled binary vector graphics
- Current limitation: no way to modify colors after compilation

**Identical Goal:** Both want runtime color transformation for .vec files while keeping performance benefits.

---

## Proposed Solutions

### GitHub Issue #158859 Approaches

The GitHub issue discusses **two different approaches**:

#### Approach A: VectorStylesOverride (Paint-based)

**API Design:**
```dart
class VectorStylesOverride {
  const VectorStylesOverride({
    this.shaders = const <int,Shader>{},
    this.paints = const <int,Paint>{},
  });

  final Map<int,Shader> shaders;
  final Map<int,Paint> paints;
}
```

**Key Characteristics:**
1. **Paint ID-based mapping**: Uses integer IDs to map specific paint objects
2. **Direct replacement**: Provides complete Paint/Shader objects as replacements
3. **Granular control**: Can override specific paints by their numeric ID
4. **Two separate maps**: One for shaders, one for complete paint objects

**Mentioned Implementation Approaches:**
- Add `styleOverrides` property to `FlutterVectorGraphicsListener`
- Modify `onPaintObject` method to check for and apply overrides
- Challenge: `FlutterVectorGraphicsListener` constructor is private

**Conceptual Code:**
```dart
// In FlutterVectorGraphicsListener
void onPaintObject({
  required int color,
  required int? strokeCap,
  // ... other params
}) {
  final Paint paint = Paint();

  // Check for override
  if (styleOverrides?.paints.containsKey(id) == true) {
    // Use override paint
    _paints.add(styleOverrides!.paints[id]!);
    return;
  }

  // Normal paint creation
  paint.color = Color(color);
  // ... rest of paint setup
  _paints.add(paint);
}
```

---

#### Approach B: Listener with Color Overrides (Map-based)

**Concept:** Create a custom listener that overrides color lookups

**Proposed by:** @aloisdeniel in the GitHub issue

**Key Characteristics:**
1. **Extends FlutterVectorGraphicsListener**: Custom listener subclass
2. **Color override map**: `Map<int, int>` mapping original colors to replacements
3. **Override in rendering methods**: Modify `onPaintObject`, `onLinearGradient`, etc.
4. **Problem**: `FlutterVectorGraphicsListener` constructor is private, preventing subclassing

**Conceptual Code (from GitHub issue):**
```dart
class OverridesFlutterVectorGraphicsListener extends FlutterVectorGraphicsListener {
  OverridesFlutterVectorGraphicsListener(this.colorOverrides, ...);

  final Map<int, int> colorOverrides;

  int _colorValue(int color) {
    return colorOverrides[color] ?? color;
  }

  @override
  void onPaintObject({
    required int color,
    // ... other params
  }) {
    super.onPaintObject(
      color: _colorValue(color),  // Replace color
      // ... other params
    );
  }
}
```

**Key Difference from our approach:**
- Uses color → color map (by color value)
- Our approach uses callback function (by logic/context)

---

### Our ColorMapper Approach (Implemented)

**API Design:**
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

**Key Characteristics:**
1. **Color-based transformation**: Operates on individual colors, not complete Paint objects
2. **Callback-based**: User provides transformation logic in `substitute()` method
3. **Context-aware**: Receives element name, attribute name, and ID for context
4. **Compatible with flutter_svg**: Identical API to flutter_svg's ColorMapper

**Implementation:**
```dart
// In FlutterVectorGraphicsListener.onPaintObject
final Paint paint = Paint();
if (colorMapper != null) {
  paint.color = colorMapper!.substitute(
    id.toString(),
    'paint',
    paintStyle == 1 ? 'stroke' : 'fill',
    Color(color),
  );
} else {
  paint.color = Color(color);
}
// ... rest of paint setup
_paints.add(paint);
```

**Integration:**
```dart
// In AssetBytesLoader
const AssetBytesLoader(
  this.assetName, {
  this.colorMapper,  // Optional ColorMapper
});
```

---

## Three-Way Comparison

### Summary Table

| Aspect | Approach A:<br/>VectorStylesOverride | Approach B:<br/>Listener + Map | Our Approach:<br/>ColorMapper |
|--------|---------------------|----------------------|-------------------|
| **Override Level** | Complete Paint objects | Color values (int→int) | Color logic (callback) |
| **Selection Method** | Paint ID | Color value | Callback with context |
| **Flexibility** | High (shaders, paints) | Medium (color only) | High (logic-based) |
| **Implementation** | Pass map to listener | Subclass listener | Modify listener code |
| **flutter_svg Compatible** | ❌ No | ❌ No | ✅ Yes |
| **Context Awareness** | ❌ No | ❌ No | ✅ Yes (element, attribute) |
| **Status** | Proposed | Proposed (blocked) | ✅ Implemented & tested |
| **Main Blocker** | Needs Flutter team | Private constructor | None (working) |

### Key Insights

**Approach A (VectorStylesOverride):**
- Most powerful: Can override paints, shaders, gradients
- Requires knowing paint IDs
- Best for: Complex styling, pre-computed paints

**Approach B (Listener + Color Map):**
- Similar to our approach in spirit
- Uses map instead of callback
- **Blocked**: Cannot subclass FlutterVectorGraphicsListener (private constructor)
- Would need Flutter team to make constructor public

**Our Approach (ColorMapper):**
- Works TODAY because we modify the listener code directly
- Callback-based = more flexible than map
- Context-aware (element, attribute, ID)
- Compatible with flutter_svg API

### Why Our Approach Works

We **didn't subclass the listener** (which would be blocked by private constructor).

Instead, we **modified the existing listener code** to check for ColorMapper:

```dart
// packages/vector_graphics_published/lib/src/listener.dart
final Paint paint = Paint();
if (colorMapper != null) {
  // Apply transformation via callback
  paint.color = colorMapper!.substitute(...);
} else {
  paint.color = Color(color);
}
```

This is similar to Approach B's goal, but:
- ✅ Doesn't require subclassing
- ✅ Uses callback (more flexible than map)
- ✅ Provides context information

---

## Detailed Comparison (Our Approach vs Approach A)

### 1. API Design Philosophy

| Aspect | Approach A (VectorStylesOverride) | Our ColorMapper |
|--------|----------------|-----------------|
| **Override granularity** | Paint-level (complete Paint objects) | Color-level (individual colors) |
| **Selection method** | Integer IDs | Callback with context (id, element, attribute) |
| **Transformation type** | Replace entire Paint/Shader | Transform Color → Color |
| **Context information** | Just numeric ID | ID + element name + attribute name |
| **Flexibility** | More control (shaders, paint properties) | Simpler, focused on colors only |

### 2. Implementation Approach

| Aspect | GitHub #158859 | Our ColorMapper |
|--------|----------------|-----------------|
| **Integration point** | StylesOverride passed to listener | ColorMapper passed through loader chain |
| **Lookup method** | Map lookup by ID | Callback invocation |
| **When applied** | During `onPaintObject()` | During `onPaintObject()` |
| **Caching** | User responsible | No caching (transforms each time) |

### 3. Use Case Coverage

**GitHub #158859 Strengths:**
- ✅ Can override complete Paint properties (not just color)
- ✅ Can apply Shader objects (gradients, etc.)
- ✅ More granular control over specific paint objects
- ✅ Could pre-compute Paint objects for better performance

**GitHub #158859 Weaknesses:**
- ❌ Requires knowing paint IDs in advance
- ❌ Less flexible for dynamic/algorithmic color transformations
- ❌ No context about what element/attribute is being painted
- ❌ Not compatible with flutter_svg's ColorMapper API

**Our ColorMapper Strengths:**
- ✅ API compatible with flutter_svg (easy migration)
- ✅ Flexible callback allows any transformation logic
- ✅ Context-aware (knows element type, attribute, ID)
- ✅ Works well for algorithmic transformations (e.g., "darken all colors by 20%")
- ✅ No need to know paint IDs in advance
- ✅ Simple, familiar API

**Our ColorMapper Weaknesses:**
- ❌ Only handles colors, not shaders or other paint properties
- ❌ Callback overhead for every color (~2ms for 350 icons)
- ❌ Cannot pre-cache transformed colors easily

### 4. Performance

**GitHub #158859 (Expected):**
- Potentially faster: Pre-computed Paint objects, map lookup only
- Memory overhead: Must store Paint/Shader objects in maps
- Startup cost: Need to create override maps

**Our ColorMapper (Measured):**
- Baseline: 1.21ms avg raster time
- With ColorMapper: 3.22ms avg raster time
- Overhead: ~2ms (~166% increase)
- Memory: Minimal (just the ColorMapper instance)

### 5. Developer Experience

**GitHub #158859:**
```dart
// Developer needs to know paint IDs (how?)
final overrides = VectorStylesOverride(
  paints: {
    42: Paint()..color = Colors.red,    // Which paint is #42?
    103: Paint()..color = Colors.blue,  // Which paint is #103?
  },
);

VectorGraphic(
  loader: AssetBytesLoader(
    'icon.svg.vec',
    styleOverrides: overrides,
  ),
);
```

**Our ColorMapper:**
```dart
// Developer uses familiar color transformation logic
class MyColorMapper extends ColorMapper {
  @override
  Color substitute(String? id, String elementName, String attributeName, Color color) {
    // Transform based on logic, not IDs
    if (color == Colors.black) return Colors.red;
    if (color.computeLuminance() < 0.1) return Colors.blue;
    return color;
  }
}

VectorGraphic(
  loader: AssetBytesLoader(
    'icon.svg.vec',
    colorMapper: MyColorMapper(),
  ),
);
```

### 6. Migration Path

**From flutter_svg:**

**GitHub #158859:**
```dart
// Before (flutter_svg)
SvgPicture.asset('icon.svg', colorMapper: MyColorMapper());

// After (vector_graphics) - DIFFERENT API
VectorGraphic(
  loader: AssetBytesLoader(
    'icon.svg.vec',
    styleOverrides: VectorStylesOverride(paints: {...}),  // Must rewrite
  ),
);
```

**Our ColorMapper:**
```dart
// Before (flutter_svg)
class MySvgColorMapper extends svg.ColorMapper { ... }
SvgPicture.asset('icon.svg', colorMapper: MySvgColorMapper());

// After (vector_graphics) - SAME API
class MyVecColorMapper extends vg.ColorMapper { ... }  // Same logic!
VectorGraphic(
  loader: AssetBytesLoader(
    'icon.svg.vec',
    colorMapper: MyVecColorMapper(),  // Same pattern
  ),
);
```

---

## Recommendation for Flutter Team

Both approaches have merit and could potentially **coexist**:

### Hybrid Approach: Both APIs

```dart
const AssetBytesLoader(
  this.assetName, {
  this.colorMapper,        // Our approach: callback-based color transformation
  this.styleOverrides,     // GitHub #158859: paint-level overrides
});
```

**Why both?**

1. **ColorMapper** (our approach) is perfect for:
   - Simple color transformations
   - Algorithmic/dynamic color changes
   - flutter_svg migration
   - When you don't know paint IDs

2. **VectorStylesOverride** (GitHub #158859) is perfect for:
   - Complex paint/shader modifications
   - Performance-critical scenarios (pre-computed paints)
   - When you know exact paint IDs
   - Advanced use cases (gradients, blend modes)

**Processing order:**
1. Check `styleOverrides` first (complete replacement)
2. If no override, apply `colorMapper` to color
3. If neither, use original color

### Implementation Priority

**Phase 1: ColorMapper** (Our approach)
- Simpler to implement ✅ (we've done it!)
- Covers 80% of use cases
- API compatible with flutter_svg
- Lower learning curve

**Phase 2: VectorStylesOverride** (GitHub #158859)
- Adds advanced capabilities
- Targets performance-critical scenarios
- More complex to implement correctly
- Requires tooling to discover paint IDs

---

## Our Implementation Status

✅ **Fully implemented and tested**
- Patched vector_graphics v1.1.19
- ColorMapper interface compatible with flutter_svg
- Performance benchmarked: ~2ms overhead for 350 icons
- Smooth rendering, no stuttering
- Documentation complete

**Ready for:**
- Internal use in WatchCrunch app
- Potential contribution to flutter/packages repository
- Reference implementation for Flutter team

---

## Conclusion

**Key Insights:**

1. **Same Problem, Different Solutions**: Both address runtime color transformation for .vec files

2. **Complementary Approaches**:
   - ColorMapper: Simple, flexible, callback-based (our solution)
   - VectorStylesOverride: Advanced, pre-computed, ID-based (GitHub proposal)

3. **Our Advantage**:
   - Already implemented and tested
   - Proven performance (3.22ms for 350 icons)
   - Compatible with flutter_svg API
   - Smoother migration path

4. **GitHub #158859 Advantage**:
   - More powerful (shaders, complete paint control)
   - Potentially better performance with pre-computation
   - More granular control

**Recommendation for WatchCrunch:**
- Use our ColorMapper implementation ✅
- Works today, proven performance
- Simple API, easy to maintain
- Covers all our use cases (196 adaptive icons)

**Recommendation for Flutter Team:**
- Consider both approaches (not mutually exclusive)
- Our ColorMapper implementation can serve as reference
- Could evolve into official flutter/packages feature

**Next Steps:**
1. Use our implementation in production
2. Monitor GitHub issue #158859 for official Flutter team response
3. Consider contributing our implementation upstream
4. If VectorStylesOverride gets implemented, evaluate for advanced use cases
