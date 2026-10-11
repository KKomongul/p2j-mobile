import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/stats_models.dart';
import 'stat_card.dart';

/// 날짜별 달성률 꺾은선. 0 · 50 · 100% 에만 옅은 기준선을 긋는다.
///
/// 차트 라이브러리를 들이지 않고 직접 그린다. 선 하나와 점 몇 개뿐이라
/// 의존성을 늘릴 이유가 없다. 마지막 점(오늘)만 크게 찍는다.
class RateLineChart extends StatelessWidget {
  const RateLineChart({required this.days, super.key});

  final List<DayRate> days;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const SizedBox.shrink();
    final values = [for (final d in days) d.achievementRate.clamp(0.0, 1.0)];

    return Column(
      children: [
        SizedBox(
          height: 120,
          width: double.infinity,
          child: CustomPaint(painter: _LinePainter(values)),
        ),
        const SizedBox(height: AppSpacing.s8),
        Row(
          children: [
            Text(
              shortDate(days.first.date),
              style: AppTypography.label.copyWith(color: AppColors.disabled),
            ),
            const Spacer(),
            Text(
              '오늘 ${(values.last * 100).round()}%',
              style: AppTypography.label.copyWith(color: AppColors.purple),
            ),
          ],
        ),
      ],
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.values);

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 6.0; // 끝점이 잘리지 않게
    final height = size.height - inset * 2;
    double y(double v) => inset + height * (1 - v);
    double x(int i) => values.length == 1
        ? size.width / 2
        : inset + (size.width - inset * 2) * i / (values.length - 1);

    final grid = Paint()
      ..color = AppColors.neutralLine
      ..strokeWidth = 1;
    for (final v in const [0.0, 0.5, 1.0]) {
      canvas.drawLine(Offset(0, y(v)), Offset(size.width, y(v)), grid);
    }

    final path = Path()..moveTo(x(0), y(values[0]));
    for (var i = 1; i < values.length; i++) {
      path.lineTo(x(i), y(values[i]));
    }

    // 선 아래를 옅게 채워 높낮이가 면으로도 읽히게 한다.
    final area = Path.from(path)
      ..lineTo(x(values.length - 1), y(0))
      ..lineTo(x(0), y(0))
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.purple.withValues(alpha: 0.18),
            AppColors.purple.withValues(alpha: 0.0),
          ],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.purple
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    final last = Offset(x(values.length - 1), y(values.last));
    canvas.drawCircle(last, 5, Paint()..color = AppColors.surface);
    canvas.drawCircle(
      last,
      5,
      Paint()
        ..color = AppColors.purple
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(_LinePainter oldDelegate) => oldDelegate.values != values;
}
