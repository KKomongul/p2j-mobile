import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_illustrations.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// 오늘 할 일을 다 끝냈을 때만 목록 아래에 붙는 축하.
///
/// 성취를 보여주는 게 이 앱의 핵심인데, 마지막 항목을 체크한 순간 화면에서
/// 일어나는 일이 숫자가 100이 되는 것뿐이면 심심하다.
class ClearedCard extends StatelessWidget {
  const ClearedCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.s24,
        AppSpacing.screenH,
        0,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s20,
        vertical: AppSpacing.s16,
      ),
      decoration: BoxDecoration(
        color: AppColors.mintSurface,
        borderRadius: BorderRadius.circular(AppRadius.r16),
      ),
      child: Row(
        children: [
          Image.asset(
            AppIllustrations.achievement,
            height: 88,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('오늘 다 끝냈어요', style: AppTypography.titleM),
                const SizedBox(height: AppSpacing.s4),
                Text(
                  '내일도 이 기세로 가요.',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.inkSub,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
