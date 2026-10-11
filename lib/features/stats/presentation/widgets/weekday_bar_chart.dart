import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/stats_models.dart';

/// 요일별 평균 달성률 막대. 막대를 누르면 위에 말풍선이 뜬다.
///
/// 날짜별 그래프는 "언제 무너졌는지" 를, 이 그래프는 "어느 요일이 약한지" 를 말한다.
/// 가장 약한 요일만 분홍으로 칠한다. 둘 이상을 강조하면 아무것도 강조되지 않는다.
class WeekdayBarChart extends StatefulWidget {
  const WeekdayBarChart({required this.days, super.key});

  final List<DayRate> days;

  @override
  State<WeekdayBarChart> createState() => _WeekdayBarChartState();
}

const List<String> _labels = ['월', '화', '수', '목', '금', '토', '일'];
const double _maxBar = 96;
const double _labelHeight = 18;

/// 막대 높이. 막대와 말풍선 위치가 같은 식을 쓴다.
double _barHeight(double? value) {
  final v = value ?? 0;
  return v == 0 ? 6.0 : 6 + (_maxBar - 6) * v;
}

class _WeekdayBarChartState extends State<WeekdayBarChart> {
  int? _selected;

  /// 요일(0=월)별 평균. 그 요일이 기간에 없으면 null.
  List<double?> _averages() {
    final sums = List<double>.filled(7, 0);
    final counts = List<int>.filled(7, 0);
    for (final day in widget.days) {
      final date = DateTime.tryParse(day.date);
      if (date == null) continue;
      final i = date.weekday - 1;
      sums[i] += day.achievementRate.clamp(0.0, 1.0);
      counts[i]++;
    }
    return [
      for (var i = 0; i < 7; i++) counts[i] == 0 ? null : sums[i] / counts[i],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final averages = _averages();
    final present = [for (final a in averages) ?a];
    final weakest = present.isEmpty || present.every((a) => a == present.first)
        ? null
        : averages.indexOf(present.reduce((a, b) => a < b ? a : b));
    final selected = _selected;
    final selectedValue = selected == null ? null : averages[selected];

    // 말풍선은 막대들 위 한 겹에 따로 그린다. 막대 칸 안에 넣으면 오른쪽 막대가
    // 나중에 그려지면서 말풍선을 덮는다.
    return SizedBox(
      height: _maxBar + 80, // 말풍선 40 + 간격 + 요일 글자
      child: LayoutBuilder(
        builder: (context, constraints) {
          final slot = constraints.maxWidth / 7;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < 7; i++)
                    Expanded(
                      child: _Bar(
                        label: _labels[i],
                        value: averages[i],
                        weakest: i == weakest,
                        selected: i == selected,
                        onTap: () => setState(
                          () => _selected = _selected == i ? null : i,
                        ),
                      ),
                    ),
                ],
              ),
              if (selected != null && selectedValue != null)
                Positioned(
                  left: (slot * (selected + 0.5) - _Tooltip.width / 2).clamp(
                    0.0,
                    constraints.maxWidth - _Tooltip.width,
                  ),
                  bottom:
                      _labelHeight +
                      AppSpacing.s8 +
                      _barHeight(selectedValue) +
                      AppSpacing.s4,
                  child: _Tooltip(
                    text:
                        '${_labels[selected]}요일 평균\n'
                        '${(selectedValue * 100).round()}%',
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.label,
    required this.value,
    required this.weakest,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final double? value;
  final bool weakest;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final v = value ?? 0;
    // 가장 약한 요일은 0% 여도 분홍으로 남긴다. 회색이면 "기록 없음" 과 구분이 안 된다.
    final color = weakest
        ? AppColors.rose
        : value == null || v == 0
        ? AppColors.neutralFill
        : AppColors.lavender;

    return GestureDetector(
      onTap: value == null ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            width: 24,
            height: _barHeight(value),
            decoration: BoxDecoration(
              color: selected
                  ? (weakest ? AppColors.roseInk : AppColors.purple)
                  : color,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          SizedBox(
            height: _labelHeight,
            child: Text(
              label,
              style: AppTypography.label.copyWith(
                color: weakest ? AppColors.roseInk : AppColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tooltip extends StatelessWidget {
  const _Tooltip({required this.text});

  static const double width = 96;

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(AppRadius.r8),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppTypography.label.copyWith(color: Colors.white, height: 1.25),
      ),
    );
  }
}
