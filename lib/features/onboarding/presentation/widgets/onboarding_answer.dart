import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// 어두운 배경 위 선택지 두 개.
class OnboardingChoices extends StatelessWidget {
  const OnboardingChoices({
    required this.options,
    required this.onSelected,
    super.key,
  });

  final List<String> options;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Material(
              color: AppColors.navyFill,
              borderRadius: BorderRadius.circular(AppRadius.r8),
              child: InkWell(
                onTap: () => onSelected(options[i]),
                borderRadius: BorderRadius.circular(AppRadius.r8),
                child: SizedBox(
                  height: 54,
                  child: Center(
                    child: Text(
                      options[i],
                      style: AppTypography.bodyStrong.copyWith(
                        color: AppColors.onNavy,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// 어두운 배경 위 가운데 정렬 입력.
///
/// 상자를 두르지 않는다. 질문 바로 아래에 답이 크게 놓이는 편이
/// 한 화면에 한 문장이라는 규칙을 덜 깬다.
class OnboardingField extends StatelessWidget {
  const OnboardingField({
    required this.controller,
    required this.hintText,
    required this.onSubmitted,
    this.keyboardType,
    this.obscureText = false,
    this.errorText,
    super.key,
  });

  final TextEditingController controller;
  final String hintText;
  final VoidCallback onSubmitted;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: controller,
          textAlign: TextAlign.center,
          textInputAction: TextInputAction.done,
          keyboardType: keyboardType,
          obscureText: obscureText,
          onSubmitted: (_) => onSubmitted(),
          autofocus: true,
          // 글자가 이미 story 크기라 돋보기가 필요 없다. 켜 두면 길게 누를 때
          // 입력칸 바로 위에 같은 글자(빈 칸이면 힌트)가 하나 더 떠서 두 줄로 보인다.
          magnifierConfiguration: TextMagnifierConfiguration.disabled,
          cursorColor: AppColors.amber,
          style: AppTypography.story.copyWith(color: AppColors.onNavy),
          decoration: InputDecoration(
            filled: false,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              vertical: AppSpacing.s12,
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            hintText: hintText,
            hintStyle: AppTypography.story.copyWith(
              color: AppColors.onNavyMuted,
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: AppSpacing.s12),
          Text(
            errorText!,
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(color: AppColors.coral),
          ),
        ],
      ],
    );
  }
}
