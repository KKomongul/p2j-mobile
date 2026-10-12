import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/paper_card.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../data/todo_models.dart';

/// 오늘 얼마나 했는지 한 장으로.
///
/// 화면을 절반 넘게 먹는 히어로가 아니라 **한 뼘짜리 종이 한 장**이다.
/// 목록이 주인공이고 이 카드는 머리말이다. 숫자·남은 개수·예상 시간이
/// 한눈에 구분되도록 크기와 색으로만 위계를 준다.
class TodaySummaryCard extends StatelessWidget {
  const TodaySummaryCard({required this.summary, super.key});

  final TodoSummary summary;

  @override
  Widget build(BuildContext context) {
    final rate = summary.achievementRate.clamp(0.0, 1.0);
    final percent = (rate * 100).round();
    final remaining = summary.total - summary.done;
    final cleared = summary.total > 0 && remaining == 0;

    return PaperCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        AppSpacing.s12,
        AppSpacing.s16,
        AppSpacing.s16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                '오늘의 진행',
                style: AppTypography.label.copyWith(color: AppColors.inkSub),
              ),
              const Spacer(),
              if (summary.totalEstimatedMinutes > 0)
                Text(
                  '예상 ${summary.totalEstimatedMinutes}분',
                  style: AppTypography.label.copyWith(color: AppColors.muted),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$percent',
                style: AppTypography.numberM.copyWith(color: AppColors.ink),
              ),
              Text(
                '%',
                style: AppTypography.titleM.copyWith(color: AppColors.inkSub),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Text(
                  '${summary.total}개 중 ${summary.done}개',
                  style: AppTypography.caption.copyWith(color: AppColors.muted),
                ),
              ),
              if (summary.total == 0)
                const StatusChip(label: '할 일 없음')
              else if (cleared)
                const StatusChip(
                  label: '다 끝냈어요',
                  tone: ChipTone.done,
                  icon: Icons.check_rounded,
                )
              else
                StatusChip(label: '$remaining개 남음', tone: ChipTone.warn),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          _Track(value: rate, cleared: cleared),
        ],
      ),
    );
  }
}

/// 진행률 막대. 앰버 면으로 채우고, 다 끝내면 민트로 바뀐다.
class _Track extends StatelessWidget {
  const _Track({required this.value, required this.cleared});

  final double value;
  final bool cleared;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.r4),
      child: SizedBox(
        height: 8,
        child: Stack(
          children: [
            const Positioned.fill(
              child: ColoredBox(color: AppColors.amberSurface),
            ),
            AnimatedFractionallySizedBox(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOut,
              widthFactor: value,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  color: cleared ? AppColors.mint : AppColors.amber,
                  borderRadius: BorderRadius.circular(AppRadius.r4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
