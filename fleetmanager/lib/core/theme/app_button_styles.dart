import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';

class AppButtonStyles {
  static const _height = Size(0, 40);
  static const _padding = EdgeInsets.symmetric(
    horizontal: AppSpacing.xl,
    vertical: AppSpacing.md,
  );
  static const _compactPadding = EdgeInsets.symmetric(
    horizontal: AppSpacing.lg,
    vertical: AppSpacing.sm,
  );
  static final _shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
  );
  static const _textStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w800,
    letterSpacing: 0,
  );

  static ButtonStyle elevated({
    Color color = AppColors.primary,
    Color foregroundColor = AppColors.white,
  }) {
    return ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(_height),
      padding: const WidgetStatePropertyAll(_padding),
      shape: WidgetStatePropertyAll(_shape),
      textStyle: const WidgetStatePropertyAll(_textStyle),
      elevation: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return 0;
        if (states.contains(WidgetState.pressed)) return 0;
        if (states.contains(WidgetState.hovered)) return 2;
        return 0;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return AppColors.grey500;
        return foregroundColor;
      }),
      iconColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return AppColors.grey500;
        return foregroundColor;
      }),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return AppColors.grey200;
        if (states.contains(WidgetState.pressed)) return _darken(color);
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return _lighten(color);
        }
        return color;
      }),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return foregroundColor.withValues(alpha: 0.12);
        }
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return foregroundColor.withValues(alpha: 0.08);
        }
        return Colors.transparent;
      }),
      shadowColor: WidgetStatePropertyAll(color.withValues(alpha: 0.22)),
    );
  }

  static ButtonStyle outlined({
    Color color = AppColors.primary,
    Color borderColor = AppColors.border,
  }) {
    return ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(_height),
      padding: const WidgetStatePropertyAll(_padding),
      shape: WidgetStatePropertyAll(_shape),
      textStyle: const WidgetStatePropertyAll(_textStyle),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return AppColors.grey500;
        if (states.contains(WidgetState.pressed)) return _darken(color);
        return color;
      }),
      iconColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return AppColors.grey500;
        if (states.contains(WidgetState.pressed)) return _darken(color);
        return color;
      }),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return AppColors.grey100;
        if (states.contains(WidgetState.pressed)) {
          return color.withValues(alpha: 0.14);
        }
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return color.withValues(alpha: 0.08);
        }
        return AppColors.surface;
      }),
      side: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return const BorderSide(color: AppColors.grey300, width: 1.2);
        }
        if (states.contains(WidgetState.pressed) ||
            states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return BorderSide(color: color, width: 1.4);
        }
        return BorderSide(color: borderColor, width: 1.2);
      }),
      overlayColor: WidgetStatePropertyAll(color.withValues(alpha: 0.08)),
    );
  }

  static ButtonStyle text({Color color = AppColors.primary}) {
    return ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(_height),
      padding: const WidgetStatePropertyAll(_compactPadding),
      shape: WidgetStatePropertyAll(_shape),
      textStyle: const WidgetStatePropertyAll(_textStyle),
      side: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return const BorderSide(color: AppColors.grey300, width: 1.2);
        }
        if (states.contains(WidgetState.pressed) ||
            states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return BorderSide(color: color, width: 1.4);
        }
        return const BorderSide(color: AppColors.border, width: 1.2);
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return AppColors.grey500;
        if (states.contains(WidgetState.pressed)) return _darken(color);
        return color;
      }),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return AppColors.grey100;
        if (states.contains(WidgetState.pressed)) {
          return color.withValues(alpha: 0.14);
        }
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return color.withValues(alpha: 0.08);
        }
        return AppColors.surface;
      }),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return color.withValues(alpha: 0.14);
        }
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return color.withValues(alpha: 0.08);
        }
        return Colors.transparent;
      }),
    );
  }

  static FloatingActionButtonThemeData floatingActionButton({
    Color color = AppColors.primary,
    Color foregroundColor = AppColors.white,
  }) {
    return FloatingActionButtonThemeData(
      backgroundColor: color,
      foregroundColor: foregroundColor,
      elevation: 4,
      highlightElevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
      ),
    );
  }

  static const chipPadding = EdgeInsets.symmetric(
    horizontal: AppSpacing.md,
    vertical: AppSpacing.sm,
  );

  static OutlinedBorder get chipShape => _shape;

  static Color chipBackground(bool selected,
      {Color color = AppColors.primary}) {
    return selected ? color : AppColors.surface;
  }

  static Color chipForeground(bool selected,
      {Color color = AppColors.primary}) {
    return selected ? AppColors.white : color;
  }

  static BorderSide chipSide(bool selected, {Color color = AppColors.primary}) {
    return BorderSide(
      color: selected ? color : AppColors.border,
      width: selected ? 1.4 : 1.2,
    );
  }

  static TextStyle chipLabelStyle(
    bool selected, {
    Color color = AppColors.primary,
  }) {
    return _textStyle.copyWith(color: chipForeground(selected, color: color));
  }

  static ButtonStyle icon({Color color = AppColors.primary}) {
    return ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size.square(40)),
      fixedSize: const WidgetStatePropertyAll(Size.square(40)),
      shape: WidgetStatePropertyAll(_shape),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return AppColors.grey500;
        if (states.contains(WidgetState.pressed)) return _darken(color);
        return color;
      }),
      iconColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return AppColors.grey500;
        if (states.contains(WidgetState.pressed)) return _darken(color);
        return color;
      }),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return Colors.transparent;
        if (states.contains(WidgetState.pressed)) {
          return color.withValues(alpha: 0.14);
        }
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return color.withValues(alpha: 0.08);
        }
        return Colors.transparent;
      }),
      overlayColor: WidgetStatePropertyAll(color.withValues(alpha: 0.08)),
    );
  }

  static Color _darken(Color color) {
    return Color.lerp(color, AppColors.black, 0.12) ?? color;
  }

  static Color _lighten(Color color) {
    return Color.lerp(color, AppColors.white, 0.10) ?? color;
  }
}
