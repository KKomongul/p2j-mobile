import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// 회색 배경 위의 흰 카드 한 장.
///
/// 층은 그림자가 아니라 색(회색 바탕 / 흰 면)으로 나눈다. 그림자는 다른 흰 면 위에
/// 겹쳐 띄워야 할 때만 [elevated] 로 켠다. (이름은 종이 질감이던 시절의 것이다.)
///
/// **모든 정보를 이 카드에 넣지 않는다.** 목록처럼 빠르게 훑어야 하는 것은
/// 평면에 두고, 카드는 한 화면에 한두 장만 쓴다. 카드 안에 카드를 겹치지 않는다.
class PaperCard extends StatelessWidget {
  const PaperCard({
    required this.child,
    this.color = AppColors.paper,
    this.padding = const EdgeInsets.all(AppSpacing.s16),
    this.onTap,
    this.elevated = false,
    super.key,
  });

  final Widget child;

  /// 카드 색. 기본은 흰색. 흰 화면 위에서는 [AppColors.neutralFill] 을 넣는다.
  final Color color;

  final EdgeInsets padding;
  final VoidCallback? onTap;

  /// 그림자를 줄지. 기본은 끈다 — 회색 바탕 위 흰 카드는 색만으로 뜬다.
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final body = Padding(padding: padding, child: child);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.r16),
        boxShadow: elevated
            ? const <BoxShadow>[
                BoxShadow(
                  color: AppColors.paperShadow,
                  blurRadius: 6,
                  offset: Offset(1, 2),
                ),
              ]
            : null,
      ),
      child: onTap == null
          ? body
          : Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(AppRadius.r16),
                child: body,
              ),
            ),
    );
  }
}
