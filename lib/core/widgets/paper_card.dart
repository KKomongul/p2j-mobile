import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// 오려 붙인 색종이 한 장.
///
/// 배경 위에 살짝 떠 있는 층을 만든다. 조명은 좌측 상단에서 들어오므로
/// 그림자는 오른쪽 아래로 짧게 진다.
///
/// **모든 정보를 이 카드에 넣지 않는다.** 목록처럼 빠르게 훑어야 하는 것은
/// 평면에 두고, 카드는 한 화면에 한두 장만 쓴다. 카드 안에 카드를 겹치지 않는다.
class PaperCard extends StatelessWidget {
  const PaperCard({
    required this.child,
    this.color = AppColors.paper,
    this.padding = const EdgeInsets.all(AppSpacing.s16),
    this.onTap,
    this.elevated = true,
    super.key,
  });

  final Widget child;

  /// 종이 색. 기본은 크림. 강조가 필요하면 [AppColors.amber] 를 넣는다.
  final Color color;

  final EdgeInsets padding;
  final VoidCallback? onTap;

  /// 그림자를 줄지. 다른 면 위에 겹쳐 놓을 때는 꺼서 층을 하나로 유지한다.
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final body = Padding(padding: padding, child: child);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.r8),
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
                borderRadius: BorderRadius.circular(AppRadius.r8),
                child: body,
              ),
            ),
    );
  }
}
