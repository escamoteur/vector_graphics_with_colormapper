// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui';

/// Base class for color mapping during vector graphics rendering.
///
/// This is compatible with flutter_svg's ColorMapper and uses dart:ui Color
/// for runtime color transformations.
abstract class ColorMapper {
  /// Allows const constructors on subclasses.
  const ColorMapper();

  /// Returns a new color to use in place of [color] during rendering.
  ///
  /// This method will be called for every color encountered in the vector graphic.
  Color substitute(
    String? id,
    String elementName,
    String attributeName,
    Color color,
  );
}
