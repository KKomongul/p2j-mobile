import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// 말하기 버튼.
///
/// 듣는 동안 테두리가 부드럽게 커졌다 작아진다. 화면이 지금 내 말을 듣고
/// 있다는 걸 알려주는 게 목적이라, 파형처럼 요란하게 만들지 않았다.
class MicButton extends StatefulWidget {
  const MicButton({
    required this.listening,
    required this.onTap,
    this.size = 96,
    super.key,
  });

  final bool listening;
  final VoidCallback onTap;
  final double size;

  @override
  State<MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<MicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    if (widget.listening) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(MicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.listening == oldWidget.listening) return;
    if (widget.listening) {
      _pulse.repeat(reverse: true);
    } else {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: widget.size * 1.5,
        height: widget.size * 1.5,
        child: Center(
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (context, child) {
              final spread = widget.listening ? 8 + _pulse.value * 14 : 0.0;
              return Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  color: widget.listening ? AppColors.purple : AppColors.ink,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.purple.withValues(
                        alpha: widget.listening ? 0.35 : 0,
                      ),
                      spreadRadius: spread,
                    ),
                  ],
                ),
                child: child,
              );
            },
            child: Icon(
              widget.listening ? Icons.graphic_eq_rounded : Icons.mic_rounded,
              color: Colors.white,
              size: widget.size * 0.42,
            ),
          ),
        ),
      ),
    );
  }
}
