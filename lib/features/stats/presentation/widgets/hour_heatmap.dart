import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/stats_models.dart';

/// 끝낸 시간대 — 하루 24칸을 6칸씩 네 줄(새벽 · 오전 · 오후 · 밤)로.
///
/// 칸이 진할수록 그 시간에 많이 끝냈다. 숫자를 읽게 하지 않고 "어디가 진한지" 만
/// 보이게 한다. 칸을 누르면 그 시간의 개수를 알려 준다.
class HourHeatmap extends StatefulWidget {
  const HourHeatmap({required this.hours, super.key});

  final List<HourCount> hours;

  @override
  State<HourHeatmap> createState() => _HourHeatmapState();
}

class _HourHeatmapState extends State<HourHeatmap> {
  int? _selected;

  static const _rows = ['새벽', '오전', '오후', '밤'];

  @override
  Widget build(BuildContext context) {
    final counts = {for (final h in widget.hours) h.hour: h.completed};
    final peak = counts.values.fold<int>(0, (a, b) => b > a ? b : a);
    final selected = _selected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var row = 0; row < 4; row++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  child: Text(
                    _rows[row],
                    style: AppTypography.label.copyWith(color: AppColors.muted),
                  ),
                ),
                for (var col = 0; col < 6; col++) ...[
                  if (col > 0) const SizedBox(width: 6),
                  Expanded(
                    child: _Cell(
                      hour: row * 6 + col,
                      count: counts[row * 6 + col] ?? 0,
                      peak: peak,
                      selected: selected == row * 6 + col,
                      onTap: () => setState(() => _selected = row * 6 + col),
                    ),
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.s4),
        Row(
          children: [
            Text(
              selected == null
                  ? '칸을 누르면 그 시간에 끝낸 개수를 볼 수 있어요'
                  : '$selected시 – ${selected + 1}시 · ${counts[selected] ?? 0}개 끝냄',
              style: AppTypography.label.copyWith(
                color: selected == null ? AppColors.disabled : AppColors.purple,
              ),
            ),
            const Spacer(),
            Text(
              '적음',
              style: AppTypography.label.copyWith(color: AppColors.disabled),
            ),
            const SizedBox(width: AppSpacing.s4),
            for (final t in const [0.15, 0.45, 0.75, 1.0])
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(left: 2),
                decoration: BoxDecoration(
                  color: Color.lerp(
                    AppColors.purpleSurface,
                    AppColors.purple,
                    t,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            const SizedBox(width: AppSpacing.s4),
            Text(
              '많음',
              style: AppTypography.label.copyWith(color: AppColors.disabled),
            ),
          ],
        ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.hour,
    required this.count,
    required this.peak,
    required this.selected,
    required this.onTap,
  });

  final int hour;
  final int count;
  final int peak;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = peak == 0 || count == 0 ? 0.0 : 0.15 + 0.85 * (count / peak);
    final color = count == 0
        ? AppColors.neutralFill
        : Color.lerp(AppColors.purpleSurface, AppColors.purple, t)!;

    return Semantics(
      label: '$hour시 $count개',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: AspectRatio(
          aspectRatio: 1.4,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
              border: selected
                  ? Border.all(color: AppColors.ink, width: 1.5)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
