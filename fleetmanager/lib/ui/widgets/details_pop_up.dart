import 'package:flutter/material.dart';
import 'package:fleetmanager/core/theme/index.dart';

class DetailsPopUp extends StatelessWidget {
  final String title;
  final IconData titleIcon;
  final List<Widget> details;
  final List<Widget>? actions;
  final String closeLabel;
  final VoidCallback? onClose;

  final String? extraSectionTitle;
  final Widget? extraContent;
  final String? actionsSectionTitle;

  const DetailsPopUp({
    super.key,
    required this.title,
    required this.titleIcon,
    required this.details,
    this.actions,
    this.closeLabel = "CHIUDI",
    this.onClose,
    this.extraSectionTitle,
    this.extraContent,
    this.actionsSectionTitle,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.white,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xxl,
      ),
      contentPadding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      titlePadding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.sm,
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
        constraints: const BoxConstraints(
          minWidth: 260,
          maxWidth: 340,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Section(
                title: "INFORMAZIONI",
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: details,
                ),
              ),
              if (extraSectionTitle != null && extraContent != null) ...[
                const SizedBox(height: AppSpacing.lg),
                _Section(
                  title: extraSectionTitle!.toUpperCase(),
                  highlighted: true,
                  child: extraContent!,
                ),
              ],
              if (actions != null && actions!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                _Section(
                  title: (actionsSectionTitle ?? "AZIONI").toUpperCase(),
                  highlighted: true,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var index = 0; index < actions!.length; index++) ...[
                        if (index > 0) const SizedBox(height: AppSpacing.sm),
                        actions![index],
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: onClose ?? () => Navigator.pop(context),
          child: Text(closeLabel.toUpperCase()),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  final bool highlighted;

  const _Section({
    required this.title,
    required this.child,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
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
            color: highlighted ? AppColors.grey50 : AppColors.white,
            borderRadius: BorderRadius.circular(AppSpacing.radiusDefault),
            border: Border.all(
              color: highlighted ? AppColors.primaryLight : AppColors.border,
            ),
          ),
          child: child,
        ),
      ],
    );
  }
}
