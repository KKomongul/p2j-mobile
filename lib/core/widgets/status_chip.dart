import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// 상태 칩의 뜻. 색을 장식이 아니라 의미로 쓴다.
enum ChipTone {
  /// 정보. 목표 이름, 소요 시간 같은 중립 정보.
  neutral,

  /// 완료.
  done,

  /// 진행 중 · 선언됨. 사용자가 스스로 건 약속.
  active,

  /// 미룸 · 주의. 되돌릴 수 있는 경고.
  warn,

  /// 오류 · 잠김. 지금은 할 수 없는 것.
  danger,
}

/// 짧은 상태 표시.
///
/// **pill 형태를 쓰는 유일한 컴포넌트다.** 칩과 태그 밖에서는 pill 을 쓰지 않는다.
/// 글자는 계열의 짙은 짝(`~Ink`)으로 넣어 대비를 확보한다.
class StatusChip extends StatelessWidget {
  const StatusChip({
    required this.label,
    this.tone = ChipTone.neutral,
    this.icon,
    super.key,
  });

  final String label;
  final ChipTone tone;

  /// 24dp 이하 동작·상태 아이콘. 캐릭터를 넣지 않는다.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (tone) {
      ChipTone.neutral => (AppColors.fill, AppColors.muted),
      ChipTone.done => (AppColors.mintSurface, AppColors.mintInk),
      ChipTone.active => (AppColors.purpleSurface, AppColors.purple),
      ChipTone.warn => (AppColors.amberSurface, AppColors.amberInk),
      ChipTone.danger => (AppColors.coralSurface, AppColors.coral),
    };

    return Container(
      padding: EdgeInsets.only(
        left: icon == null ? AppSpacing.s8 : 6,
        right: AppSpacing.s8,
        top: 3,
        bottom: 3,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: foreground),
            const SizedBox(width: 3),
          ],
          Text(label, style: AppTypography.label.copyWith(color: foreground)),
        ],
      ),
    );
  }
}
