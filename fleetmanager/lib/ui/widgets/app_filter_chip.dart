import 'package:fleetmanager/core/theme/index.dart';
import 'package:flutter/material.dart';

class AppFilterChip extends StatefulWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  const AppFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.color = AppColors.primary,
  });

  @override
  State<AppFilterChip> createState() => _AppFilterChipState();
}

class _AppFilterChipState extends State<AppFilterChip> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final foreground = AppButtonStyles.chipForeground(
      widget.selected,
      color: widget.color,
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          constraints: const BoxConstraints(
            minHeight: AppButtonStyles.filterChipMinHeight,
          ),
          padding: AppButtonStyles.filterChipPadding,
          decoration: ShapeDecoration(
            color: AppButtonStyles.chipBackground(
              widget.selected,
              color: widget.color,
              hovered: _hovered,
              pressed: _pressed,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
              side: AppButtonStyles.chipSide(
                widget.selected,
                color: widget.color,
                hovered: _hovered,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  size: AppButtonStyles.filterChipIconSize,
                  color: foreground,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                widget.label,
                style: AppButtonStyles.filterChipLabelStyle(
                  widget.selected,
                  color: widget.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
