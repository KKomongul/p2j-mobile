import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// 입력 묶음 위의 짧은 라벨.
///
/// `AppTextField` 는 자기 라벨을 갖고 있다. 이건 그 밖의 컨트롤
/// (선택지·스테퍼·색)에 같은 위계를 주려고 쓴다.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTypography.label.copyWith(color: AppColors.inkSub),
    );
  }
}

/// 폼 전체에 걸리는 오류. 필드 하나로 지목할 수 없을 때만 쓴다.
class FormErrorBanner extends StatelessWidget {
  const FormErrorBanner({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s12,
      ),
      decoration: BoxDecoration(
        color: AppColors.coralSurface,
        borderRadius: BorderRadius.circular(AppRadius.r8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: AppColors.coral,
          ),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Text(
              message,
              style: AppTypography.caption.copyWith(color: AppColors.coral),
            ),
          ),
        ],
      ),
    );
  }
}

/// 선택지 하나.
class SegmentOption<T> {
  const SegmentOption({required this.value, required this.label});

  final T value;
  final String label;
}

/// 두세 개 중 하나를 고르는 가로 선택지.
///
/// 드롭다운을 쓰지 않는다. 선택지가 셋 이하면 펼쳐 두는 쪽이 탭 수가 적다.
class SegmentedChoice<T> extends StatelessWidget {
  const SegmentedChoice({
    required this.value,
    required this.options,
    required this.onChanged,
    this.compact = false,
    super.key,
  });

  final T value;
  final List<SegmentOption<T>> options;

  /// null 이면 비활성.
  final ValueChanged<T>? onChanged;

  /// 다른 컨트롤과 한 줄에 놓을 때. 가로로 늘리지 않는다.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < options.length; i++) {
      if (i > 0) children.add(const SizedBox(width: AppSpacing.s8));
      final option = options[i];
      final button = _Segment(
        label: option.label,
        selected: option.value == value,
        enabled: onChanged != null,
        compact: compact,
        onTap: () => onChanged?.call(option.value),
      );
      children.add(compact ? button : Expanded(child: button));
    }
    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.compact,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final background = !enabled
        ? AppColors.fill
        : selected
            ? AppColors.purple
            : AppColors.fill;
    final foreground = !enabled
        ? AppColors.disabled
        : selected
            ? Colors.white
            : AppColors.inkSub;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(AppRadius.r8),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppRadius.r8),
        child: Container(
          height: 48,
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? AppSpacing.s20 : AppSpacing.s12,
          ),
          child: Text(
            label,
            style: AppTypography.bodyStrong.copyWith(color: foreground),
          ),
        ),
      ),
    );
  }
}

/// 숫자를 한 칸씩 올리고 내리는 컨트롤.
///
/// 키보드를 띄우지 않는다. 1~14 회, 1~52 주처럼 범위가 좁고 자주 바꾸는 값에 쓴다.
/// 버튼은 48dp 를 채운다.
class CountStepper extends StatelessWidget {
  const CountStepper({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.suffix = '',
    super.key,
  });

  final int value;
  final int min;
  final int max;
  final String suffix;

  /// null 이면 비활성.
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.fill,
        borderRadius: BorderRadius.circular(AppRadius.r8),
      ),
      child: Row(
        children: [
          _StepButton(
            icon: Icons.remove_rounded,
            tooltip: '하나 줄이기',
            onTap: enabled && value > min ? () => onChanged!(value - 1) : null,
          ),
          Expanded(
            child: Center(
              child: Text(
                '$value$suffix',
                style: AppTypography.bodyStrong.copyWith(
                  color: enabled ? AppColors.ink : AppColors.disabled,
                ),
              ),
            ),
          ),
          _StepButton(
            icon: Icons.add_rounded,
            tooltip: '하나 늘리기',
            onTap: enabled && value < max ? () => onChanged!(value + 1) : null,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: IconButton(
        icon: Icon(icon, size: 20),
        tooltip: tooltip,
        onPressed: onTap,
        color: AppColors.inkSub,
        disabledColor: AppColors.disabled,
      ),
    );
  }
}

/// 목표 색 고르기.
///
/// 팔레트 안의 색만 고를 수 있다. 자유 색상 선택기를 주면 화면 전체의
/// 색 규칙이 무너진다. 서버는 `#RRGGBB` 형식만 받는다.
class ColorSwatches extends StatelessWidget {
  const ColorSwatches({required this.value, required this.onChanged, super.key});

  /// `#RRGGBB` 또는 null(색 없음).
  final String? value;

  /// null 이면 비활성.
  final ValueChanged<String?>? onChanged;

  static const List<String> palette = <String>[
    '#7B658F', // purple
    '#C8AFD2', // lavender
    '#EDA85E', // amber
    '#92AC91', // mint
    '#AD4C39', // coral
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.s12,
      runSpacing: AppSpacing.s12,
      children: [
        _Swatch(
          color: null,
          selected: value == null,
          enabled: onChanged != null,
          onTap: () => onChanged?.call(null),
        ),
        for (final hex in palette)
          _Swatch(
            color: Color(int.parse('FF${hex.substring(1)}', radix: 16)),
            selected: value?.toUpperCase() == hex,
            enabled: onChanged != null,
            onTap: () => onChanged?.call(hex),
          ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  /// null 이면 '색 없음'.
  final Color? color;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: color == null ? '색 없음' : '색 선택',
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        behavior: HitTestBehavior.opaque,
        // 그림은 36dp 지만 터치는 48dp 를 채운다.
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color ?? AppColors.fill,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.ink : AppColors.line,
                  width: selected ? 2 : 1,
                ),
              ),
              child: color == null
                  ? Icon(
                      Icons.block_rounded,
                      size: 16,
                      color: AppColors.muted,
                    )
                  : selected
                      ? const Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: Colors.white,
                        )
                      : null,
            ),
          ),
        ),
      ),
    );
  }
}
