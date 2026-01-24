import 'package:flutter/material.dart';

/// Extension to provide deprecated-free opacity and color utilities
extension ColorExtension on Color {
  /// Replaces the deprecated withOpacity() method
  /// Provides a modern way to set color opacity using withValues()
  Color withTransparency(double opacity) {
    return withValues(alpha: opacity);
  }

  /// Quick opacity variants
  Color get veryTransparent => withValues(alpha: 0.05);
  Color get lightTransparent => withValues(alpha: 0.1);
  Color get semiTransparent => withValues(alpha: 0.2);
  Color get mediumTransparent => withValues(alpha: 0.3);
  Color get transparent50 => withValues(alpha: 0.5);
}
