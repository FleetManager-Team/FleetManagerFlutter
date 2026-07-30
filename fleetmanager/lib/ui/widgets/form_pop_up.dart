import 'package:fleetmanager/core/theme/index.dart';
import 'package:flutter/material.dart';

class FormPopUp extends StatelessWidget {
  final String title;
  final IconData titleIcon;
  final String sectionTitle;
  final Widget content;
  final List<Widget> actions;
  final double maxWidth;

  const FormPopUp({
    super.key,
    required this.title,
    required this.titleIcon,
    required this.content,
    required this.actions,
    this.sectionTitle = "DATI",
    this.maxWidth = 520,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final maxHeight = mediaQuery.size.height * 0.74;

    return AlertDialog(
      backgroundColor: AppColors.white,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xxl,
      ),
      titlePadding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.sm,
      ),
      contentPadding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.md + mediaQuery.viewInsets.bottom,
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      buttonPadding: const EdgeInsets.only(left: AppSpacing.sm),
      actionsAlignment: MainAxisAlignment.end,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXLarge),
      ),
      title: Row(
        children: [
          Icon(titleIcon, color: AppColors.primary, size: AppSpacing.iconSmall),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.headlineMedium.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: 280,
          maxWidth: maxWidth,
          maxHeight: maxHeight,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sectionTitle.toUpperCase(),
                style: AppTextStyles.overline.copyWith(
                  color: AppColors.primary,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.grey50,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusDefault),
                  border: Border.all(color: AppColors.border),
                ),
                child: content,
              ),
            ],
          ),
        ),
      ),
      actions: actions,
    );
  }
}
