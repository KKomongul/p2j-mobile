import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// 말풍선.
///
/// 어두운 화면 위에 밝은 종이처럼 얹힌다. 아래쪽 꼬리가 말하는 쪽을 가리켜서
/// 글이 화면이 아니라 캐릭터의 말이라는 걸 알려준다.
class SpeechBubble extends StatelessWidget {
  const SpeechBubble({
    required this.child,
    // 인트로의 네이비 면 위에 뜨는 말풍선. 회색 배경색을 쓰면 탁해 보인다.
    this.color = AppColors.onNavy,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.s24,
      vertical: AppSpacing.s20,
    ),
    super.key,
  });

  final Widget child;
  final Color color;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: padding,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppRadius.r16),
          ),
          child: child,
        ),
        CustomPaint(
          size: const Size(22, 13),
          painter: _TailPainter(color: color),
        ),
      ],
    );
  }
}

class _TailPainter extends CustomPainter {
  const _TailPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // 왼쪽 위에서 시작해 아래로 흘러내리는 꼬리. 대칭 삼각형보다 말하는 느낌이 난다.
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width * 0.22, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TailPainter oldDelegate) => oldDelegate.color != color;
}
