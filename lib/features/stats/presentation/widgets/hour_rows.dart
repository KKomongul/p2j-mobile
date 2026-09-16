import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/stats_models.dart';

/// 끝낸 시간대 분포.
///
/// 24칸을 다 그리면 대부분 빈칸이라 읽히지 않는다. **기록이 있는 시간대만**
/// 많은 순으로 몇 줄 보여 준다. 가로 막대라 숫자 비교가 쉽다.
class HourRows extends StatelessWidget {
  const HourRows({required this.hours, this.maxRows = 5, super.key});

  final List<HourCount> hours;
  final int maxRows;

  @override
  Widget build(BuildContext context) {
    if (hours.isEmpty) return const SizedBox.shrink();

    final sorted = [...hours]..sort((a, b) {
        final byCount = b.completed.compareTo(a.completed);
        return byCount != 0 ? byCount : a.hour.compareTo(b.hour);
      });
    final shown = sorted.take(maxRows).toList(growable: false);
    final peak = shown.first.completed;

    return Column(
      children: [
        for (final entry in shown)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s8),
            child: _Row(
              hour: entry.hour,
              completed: entry.completed,
              ratio: peak == 0 ? 0 : entry.completed / peak,
            ),
          ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.hour,
    required this.completed,
    required this.ratio,
  });

  final int hour;
  final int completed;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 44,
          child: Text(
            _label(hour),
            style: AppTypography.caption.copyWith(color: AppColors.inkSub),
          ),
        ),
        const SizedBox(width: AppSpacing.s8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.r4),
            child: Stack(
              children: [
                Container(height: 14, color: AppColors.fill),
                FractionallySizedBox(
                  widthFactor: ratio.clamp(0.06, 1.0),
                  child: Container(height: 14, color: AppColors.lavender),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.s8),
        SizedBox(
          width: 28,
          child: Text(
            '$completed',
            textAlign: TextAlign.right,
            style: AppTypography.caption.copyWith(color: AppColors.muted),
          ),
        ),
      ],
    );
  }

  /// 24시간제 그대로 쓰되 자정·정오만 말로 적는다. "0시" 는 읽기 불편하다.
  static String _label(int hour) => switch (hour) {
        0 => '자정',
        12 => '정오',
        _ => '$hour시',
      };
}
