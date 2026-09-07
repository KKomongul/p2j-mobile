import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 달성률 바.
class ProgressBar extends StatelessWidget {
  const ProgressBar({
    required this.value,
    this.height = 8,
    this.trackColor = AppColors.fill,
    this.fillColor = AppColors.purple,
    super.key,
  });

  /// 0.0 ~ 1.0.
  final double value;
  final double height;
  final Color trackColor;
  final Color fillColor;

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                Container(color: trackColor),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  width: constraints.maxWidth * clamped,
                  decoration: BoxDecoration(
                    color: fillColor,
                    borderRadius: BorderRadius.circular(height / 2),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
