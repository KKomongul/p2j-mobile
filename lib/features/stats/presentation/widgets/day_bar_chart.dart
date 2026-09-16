import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/stats_models.dart';

/// 날짜별 달성률 막대.
///
/// 카드에 넣지 않고 배경 면 위에 그대로 둔다. 종이를 겹치면 층이 늘어나는데,
/// 훑어보는 그래프는 층이 얕을수록 빨리 읽힌다.
///
/// 색은 장식이 아니다. 100% 는 민트, 그 아래는 앰버, 0 은 빈 트랙이다.
class DayBarChart extends StatelessWidget {
  const DayBarChart({required this.days, super.key});

  final List<DayRate> days;

  /// 막대 최대 높이. 일주일이든 한 달이든 같은 높이로 그린다.
  static const double _barHeight = 92;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const SizedBox.shrink();

    // 한 달이면 30개라 요일을 다 적을 수 없다. 5일 간격으로만 적는다.
    final dense = days.length > 10;

    return SizedBox(
      height: _barHeight + 22,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < days.length; i++)
            Expanded(
              child: _Bar(
                day: days[i],
                label: _label(days[i].date, i, dense),
                isLast: i == days.length - 1,
              ),
            ),
        ],
      ),
    );
  }

  String _label(String date, int index, bool dense) {
    final parsed = DateTime.tryParse(date);
    if (parsed == null) return '';
    if (!dense) return _weekdayKo(parsed.weekday);
    // 촘촘할 때는 5일마다 날짜만. 마지막 칸(오늘)은 항상 적는다.
    final isEdge = index == days.length - 1;
    if (!isEdge && index % 5 != 0) return '';
    return '${parsed.day}';
  }

  static String _weekdayKo(int weekday) =>
      const ['월', '화', '수', '목', '금', '토', '일'][weekday - 1];
}

class _Bar extends StatelessWidget {
  const _Bar({required this.day, required this.label, required this.isLast});

  final DayRate day;
  final String label;

  /// 마지막 칸은 오늘이다. 아직 진행 중이라는 걸 글자 색으로만 구분한다.
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final rate = day.achievementRate.clamp(0.0, 1.0);
    final color = rate >= 1.0
        ? AppColors.mint
        : rate > 0
            ? AppColors.amber
            : AppColors.fill;

    return Semantics(
      label: '${day.date} 달성률 ${(rate * 100).round()}퍼센트',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    // 빈 트랙을 먼저 깔아 "계획이 없던 날" 도 자리를 차지하게 한다.
                    Container(
                      height: DayBarChart._barHeight,
                      decoration: BoxDecoration(
                        color: AppColors.fill,
                        borderRadius: BorderRadius.circular(AppRadius.r4),
                      ),
                    ),
                    Container(
                      // 0 이어도 1dp 는 남겨 막대가 완전히 사라지지 않게 한다.
                      height: (DayBarChart._barHeight * rate).clamp(1.0, 92.0),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(AppRadius.r4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: AppTypography.label.copyWith(
                color: isLast ? AppColors.ink : AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
