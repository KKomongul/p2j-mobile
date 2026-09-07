import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/todo_models.dart';

/// 7일 달성률 스트립.
///
/// 날짜를 감싸는 링이 그날의 달성률이다. 숫자는 항상 잉크라서 어떤 값에서도
/// 읽히고, 링만 브랜드 색으로 채워진다.
class WeekStrip extends StatelessWidget {
  const WeekStrip({
    required this.days,
    required this.selectedDate,
    required this.today,
    required this.onSelect,
    super.key,
  });

  static const List<String> _weekdayLabels = <String>[
    '월',
    '화',
    '수',
    '목',
    '금',
    '토',
    '일',
  ];

  final List<DayAchievement> days;
  final String selectedDate;
  final String? today;
  final ValueChanged<String> onSelect;

  static String weekdayLabel(String date) {
    final parsed = DateTime.tryParse(date);
    if (parsed == null) return '';
    return _weekdayLabels[parsed.weekday - 1];
  }

  static String dayNumber(String date) {
    final parsed = DateTime.tryParse(date);
    if (parsed == null) return '';
    return parsed.day.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // 배경과 같은 색이면 어디까지가 스트립인지 안 보인다.
      // 흰 띠에 아래 경계선을 둬서 한 덩어리로 끊는다.
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      // 좌우를 화면 여백에 맞춘다. 아래 요약 카드와 모서리가 어긋나면
      // 스트립이 화면 밖으로 새어 나간 것처럼 보인다.
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.s8,
        AppSpacing.screenH,
        AppSpacing.s12,
      ),
      child: Row(
        children: [
          for (final day in days)
            Expanded(
              child: _DayCell(
                day: day,
                selected: day.date == selectedDate,
                isToday: day.date == today,
                onTap: () => onSelect(day.date),
              ),
            ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.selected,
    required this.isToday,
    required this.onTap,
  });

  final DayAchievement day;
  final bool selected;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rate = day.achievementRate.clamp(0.0, 1.0);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.r8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
        decoration: BoxDecoration(
          color: selected ? AppColors.background : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.r8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              WeekStrip.weekdayLabel(day.date),
              style: AppTypography.label.copyWith(
                color: isToday ? AppColors.ink : AppColors.disabled,
              ),
            ),
            const SizedBox(height: AppSpacing.s8),
            SizedBox(
              width: 36,
              height: 36,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: rate),
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return CircularProgressIndicator(
                          value: value,
                          strokeWidth: 3,
                          strokeCap: StrokeCap.round,
                          color: rate >= 1 ? AppColors.mint : AppColors.amber,
                          backgroundColor: AppColors.fill,
                        );
                      },
                    ),
                  ),
                  Text(
                    WeekStrip.dayNumber(day.date),
                    // 가변 폰트라 굵기를 바꿀 때 wght 축도 같이 바꿔야 한다.
                    style: (isToday
                            ? AppTypography.titleL
                            : AppTypography.caption)
                        .copyWith(
                      color: AppColors.ink,
                      fontSize: AppTypography.label.fontSize,
                      height: AppTypography.label.height,
                      letterSpacing: AppTypography.label.letterSpacing,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
