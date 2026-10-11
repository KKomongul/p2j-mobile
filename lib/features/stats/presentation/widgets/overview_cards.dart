import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/stats_models.dart';
import 'stat_card.dart';

/// 맨 위 두 칸 — 지금 연속 · 들인 시간.
class SummaryTiles extends StatelessWidget {
  const SummaryTiles({required this.summary, super.key});

  final StatsSummary summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Tile(
            icon: Icons.local_fire_department_rounded,
            iconColor: AppColors.amberInk,
            iconBackground: AppColors.amberSurface,
            label: '지금 연속',
            value: summary.currentStreak == 0
                ? '없음'
                : '${summary.currentStreak}일',
          ),
        ),
        const SizedBox(width: AppSpacing.s12),
        Expanded(
          child: _Tile(
            icon: Icons.schedule_rounded,
            label: '들인 시간',
            value: summary.totalActualMinutes == 0
                ? '—'
                : formatMinutes(summary.totalActualMinutes),
          ),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor = AppColors.purple,
    this.iconBackground = AppColors.purpleSurface,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return StatCard(
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Row(
        children: [
          StatIcon(icon: icon, color: iconColor, background: iconBackground),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.label.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleM,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 달성률 — 끝낸 몫(보라)과 남은 몫(분홍)을 한 줄에.
///
/// 이 화면에서 가장 큰 숫자는 여기 하나다.
class AchievementCard extends StatelessWidget {
  const AchievementCard({required this.summary, super.key});

  final StatsSummary summary;

  @override
  Widget build(BuildContext context) {
    final rate = summary.achievementRate.clamp(0.0, 1.0);
    final percent = (rate * 100).round();

    return StatCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StatIcon(icon: Icons.task_alt_rounded),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('달성률', style: AppTypography.bodyStrong),
                    const Spacer(),
                    Text(
                      '${summary.totalTodos}개 중 ${summary.completedTodos}개',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s8),
                Text('$percent%', style: AppTypography.numberM),
                const SizedBox(height: AppSpacing.s12),
                _SplitBar(value: rate),
                const SizedBox(height: AppSpacing.s8),
                Row(
                  children: [
                    const _Legend(color: AppColors.purple, label: '끝냄'),
                    const SizedBox(width: AppSpacing.s12),
                    const _Legend(color: AppColors.rose, label: '남음'),
                    const Spacer(),
                    Text(
                      '${shortDate(summary.range.fromDate)} – ${shortDate(summary.range.toDate)}',
                      style: AppTypography.label.copyWith(
                        color: AppColors.disabled,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SplitBar extends StatelessWidget {
  const _SplitBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final done = (value * 1000).round();
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 8,
        child: Row(
          // stretch: 자식 없는 ColoredBox 는 높이 0 으로 접힌다. 8dp 를 채우게 한다.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (done > 0)
              Expanded(
                flex: done,
                child: const ColoredBox(color: AppColors.purple),
              ),
            if (done < 1000)
              Expanded(
                flex: 1000 - done,
                child: const ColoredBox(color: AppColors.rose),
              ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.s4),
        Text(
          label,
          style: AppTypography.label.copyWith(color: AppColors.muted),
        ),
      ],
    );
  }
}

/// 가장 길었던 연속. 지금 기록과 겹치지 않게 한 줄로만.
class BestStreakCard extends StatelessWidget {
  const BestStreakCard({required this.summary, super.key});

  final StatsSummary summary;

  @override
  Widget build(BuildContext context) {
    final best = summary.longestStreak;
    final left = best - summary.currentStreak;

    return StatCard(
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Row(
        children: [
          const StatIcon(icon: Icons.event_available_rounded),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  best == 0 ? '아직 연속 기록이 없어요' : '가장 길었던 연속 $best일',
                  style: AppTypography.bodyStrong,
                ),
                const SizedBox(height: 2),
                Text(
                  best == 0
                      ? '그날 할 일을 다 끝내면 하루가 쌓여요.'
                      : left <= 0
                      ? '지금이 최고 기록이에요.'
                      : '$left일 더 이어 가면 최고 기록과 같아요.',
                  style: AppTypography.caption.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
