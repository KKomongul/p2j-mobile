import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// 빈 상태 화면.
///
/// 신규 사용자가 처음 보는 화면이다. 안내가 아니라 행동 유도로 쓴다.
class EmptyView extends StatelessWidget {
  const EmptyView({
    required this.title,
    required this.description,
    this.imagePath,
    this.icon = Icons.checklist_rounded,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String description;

  /// 넣으면 아이콘 대신 마스코트 그림이 나온다.
  final String? imagePath;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (imagePath != null)
              Image.asset(imagePath!, height: 160, fit: BoxFit.contain)
            else
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.purpleSurface,
                  borderRadius: BorderRadius.circular(AppRadius.r16),
                ),
                child: Icon(icon, color: AppColors.purple, size: 30),
              ),
            const SizedBox(height: AppSpacing.s16),
            Text(title, style: AppTypography.titleM, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.s8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(color: AppColors.muted),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.s24),
              SizedBox(
                width: 200,
                child: FilledButton(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
