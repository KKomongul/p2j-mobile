import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/group_models.dart';

/// 구성원 한 명의 오늘을 한 칸에.
///
/// 가운데 고리가 선언 항목의 달성률이다. 선언하지 않은 사람은 빈 고리로 남는다 —
/// 빼지 않고 비워 두는 게 압력 장치다. 내 칸만 테두리를 진하게 둘러 찾기 쉽게 한다.
class MemberTile extends StatelessWidget {
  const MemberTile({
    required this.row,
    required this.isMe,
    required this.onTap,
    super.key,
  });

  final DeclarationRow row;
  final bool isMe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final total = row.items.length;
    final done = row.doneCount;
    final cleared = row.declared && total > 0 && done == total;

    final status = !row.declared
        ? '선언 전'
        : cleared
        ? '다 끝냄'
        : '$done/$total';
    final statusColor = !row.declared
        ? AppColors.disabled
        : cleared
        ? AppColors.mintInk
        : AppColors.purple;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.r8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.r8),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.r8),
            border: Border.all(
              color: isMe ? AppColors.ink : AppColors.neutralLine,
              width: isMe ? 1.5 : 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s4,
            vertical: AppSpacing.s8,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ProgressRing(
                value: total == 0 ? 0 : done / total,
                declared: row.declared,
                cleared: cleared,
              ),
              const SizedBox(height: AppSpacing.s8),
              Text(
                row.user.nickname,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w600,
                  fontVariations: const [FontVariation('wght', 600)],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                status,
                style: AppTypography.label.copyWith(color: statusColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({
    required this.value,
    required this.declared,
    required this.cleared,
  });

  final double value;
  final bool declared;
  final bool cleared;

  @override
  Widget build(BuildContext context) {
    const size = 44.0;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: declared ? value : 0,
              strokeWidth: 4,
              strokeCap: StrokeCap.round,
              backgroundColor: AppColors.neutralFill,
              color: cleared ? AppColors.mint : AppColors.purple,
            ),
          ),
          Icon(
            cleared
                ? Icons.check_rounded
                : declared
                ? Icons.campaign_outlined
                : Icons.hourglass_empty_rounded,
            size: 18,
            color: cleared
                ? AppColors.mintInk
                : declared
                ? AppColors.purple
                : AppColors.disabled,
          ),
        ],
      ),
    );
  }
}
