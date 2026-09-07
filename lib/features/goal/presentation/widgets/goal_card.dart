import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/progress_bar.dart';
import '../../data/goal_models.dart';

/// 목표 한 장.
///
/// 목록은 훑는 곳이라 그림자를 쓰지 않는다. 옅은 채움과 8dp 라운드로만 끊는다.
/// 목표 색은 제목 앞 점 하나로만 쓴다. 카드 전체를 물들이면 진행률이 안 읽힌다.
class GoalCard extends StatelessWidget {
  const GoalCard({required this.goal, super.key});

  final Goal goal;

  /// 서버가 준 #RRGGBB. 형식이 어긋나면 점을 그리지 않는다.
  Color? get _dotColor {
    final hex = goal.color;
    if (hex == null || hex.length != 7 || !hex.startsWith('#')) return null;
    final value = int.tryParse(hex.substring(1), radix: 16);
    return value == null ? null : Color(0xFF000000 | value);
  }

  @override
  Widget build(BuildContext context) {
    final progress = goal.progress;
    final percent = (progress.achievementRate.clamp(0.0, 1.0) * 100).round();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s20),
      decoration: BoxDecoration(
        // 배경도 흰색이라 테두리로만 구분하면 약하다. 옅은 채움으로 띄운다.
        color: AppColors.fill,
        borderRadius: BorderRadius.circular(AppRadius.r8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (_dotColor != null) ...[
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: AppSpacing.s8),
                  decoration: BoxDecoration(
                    color: _dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
              Expanded(child: Text(goal.title, style: AppTypography.titleM)),
              if (goal.status.badgeLabel != null)
                _Badge(label: goal.status.badgeLabel!),
            ],
          ),
          const SizedBox(height: AppSpacing.s16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                percent.toString(),
                style: AppTypography.numberM.copyWith(color: AppColors.ink),
              ),
              Text('%', style: AppTypography.bodyStrong),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(
                  '${progress.targetCount}회 중 ${progress.doneCount}회',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          ProgressBar(
            value: progress.achievementRate,
            trackColor: AppColors.line,
          ),
          const SizedBox(height: AppSpacing.s16),
          _WeekPace(goal: goal),
        ],
      ),
    );
  }
}

/// 이번 주 페이스. 목표 대비 몇 번 했는지를 그대로 말한다.
class _WeekPace extends StatelessWidget {
  const _WeekPace({required this.goal});

  final Goal goal;

  @override
  Widget build(BuildContext context) {
    final progress = goal.progress;
    final target = progress.currentWeekTarget;
    final done = progress.currentWeekDone;
    final onPace = target == 0 || done >= target;

    return Row(
      children: [
        Icon(
          onPace
              ? Icons.trending_up_rounded
              : Icons.access_time_rounded,
          size: 16,
          color: AppColors.muted,
        ),
        const SizedBox(width: AppSpacing.s8),
        Expanded(
          child: Text(
            _paceLabel(done, target),
            style: AppTypography.caption.copyWith(color: AppColors.muted),
          ),
        ),
        if (goal.frequency != null && goal.frequency!.times > 0)
          Text(
            '${goal.frequency!.per.label} ${goal.frequency!.times}회',
            style: AppTypography.label.copyWith(color: AppColors.muted),
          ),
      ],
    );
  }

  String _paceLabel(int done, int target) {
    if (target == 0) return '이번 주 $done회 완료';
    final left = target - done;
    if (left <= 0) return '이번 주 목표 달성';
    return '이번 주 $done/$target회 · $left회 남음';
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s8,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.line,
        borderRadius: BorderRadius.circular(AppRadius.r8),
      ),
      child: Text(
        label,
        style: AppTypography.label.copyWith(color: AppColors.muted),
      ),
    );
  }
}
