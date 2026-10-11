import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// 통계 화면의 흰 카드 한 장.
///
/// 회색 바탕([AppColors.neutralFill]) 위에 흰 면으로 띄운다. 그림자 없이 색만으로
/// 층을 나눈다 — 그룹 화면과 같은 결이다. 카드마다 제목 · 한 줄 설명 · 본문 순서를 지킨다.
class StatCard extends StatelessWidget {
  const StatCard({
    required this.child,
    this.title,
    this.caption,
    this.trailing,
    this.padding = const EdgeInsets.all(AppSpacing.s20),
    super.key,
  });

  final String? title;
  final String? caption;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.r16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                Expanded(child: Text(title!, style: AppTypography.titleM)),
                ?trailing,
              ],
            ),
            if (caption != null) ...[
              const SizedBox(height: AppSpacing.s4),
              Text(
                caption!,
                style: AppTypography.caption.copyWith(color: AppColors.muted),
              ),
            ],
            const SizedBox(height: AppSpacing.s16),
          ],
          child,
        ],
      ),
    );
  }
}

/// 카드 묶음 위의 소제목. "한눈에 보기", "기록 분석".
class StatSectionTitle extends StatelessWidget {
  const StatSectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s4,
        AppSpacing.s24,
        AppSpacing.s4,
        AppSpacing.s12,
      ),
      child: Text(text, style: AppTypography.titleL),
    );
  }
}

/// 아이콘이 든 둥근 사각 배지. 요약 타일과 카드 머리에 쓴다.
class StatIcon extends StatelessWidget {
  const StatIcon({
    required this.icon,
    this.color = AppColors.purple,
    this.background = AppColors.purpleSurface,
    super.key,
  });

  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.r8 + 4),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 22, color: color),
    );
  }
}

/// 분을 "1시간 40분" 으로. 60분 미만이면 분만 적는다.
String formatMinutes(int minutes) {
  if (minutes < 60) return '$minutes분';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '$hours시간' : '$hours시간 $rest분';
}

/// `2026-10-11` → `10.11`.
String shortDate(String? iso) {
  final parsed = iso == null ? null : DateTime.tryParse(iso);
  return parsed == null ? '' : '${parsed.month}.${parsed.day}';
}
