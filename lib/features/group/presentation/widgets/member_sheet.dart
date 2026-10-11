import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../data/group_models.dart';

/// 구성원 칸을 누르면 올라오는 오늘 기록.
///
/// 숫자 네 개(선언 · 완료 · 달성률 · 연속)를 회색 패널에 모으고, 그 아래에 선언한
/// 항목을 그대로 적는다. 못 한 것도 지우지 않고 보여 준다.
class MemberSheet extends StatelessWidget {
  const MemberSheet({
    required this.row,
    required this.isMe,
    this.member,
    super.key,
  });

  final DeclarationRow row;
  final bool isMe;

  /// 연속 기록 · 방장 여부. 아직 못 읽었으면 null 이고 그 칸만 비운다.
  final GroupMember? member;

  static Future<void> show(
    BuildContext context, {
    required DeclarationRow row,
    required bool isMe,
    GroupMember? member,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => MemberSheet(row: row, isMe: isMe, member: member),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = row.items.length;
    final done = row.doneCount;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          0,
          AppSpacing.screenH,
          AppSpacing.s24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    isMe ? '${row.user.nickname} (나)' : row.user.nickname,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleL,
                  ),
                ),
                if (member?.role.isOwner ?? false) ...[
                  const SizedBox(width: AppSpacing.s8),
                  const StatusChip(label: '방장', tone: ChipTone.warn),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              row.declared ? '오늘 $total개를 선언했어요.' : '아직 오늘 선언을 하지 않았어요.',
              style: AppTypography.body.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: AppSpacing.s16),
            _StatsPanel(
              cells: [
                ('선언', row.declared ? '$total개' : '—'),
                ('완료', row.declared ? '$done개' : '—'),
                (
                  '달성률',
                  row.declared
                      ? '${(row.achievementRate * 100).round()}%'
                      : '—',
                ),
                ('연속', member == null ? '—' : '${member!.streak}일'),
              ],
            ),
            if (row.items.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.s20),
              Text('선언한 일', style: AppTypography.bodyStrong),
              const SizedBox(height: AppSpacing.s8),
              for (final item in row.items) _ItemLine(item: item),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatsPanel extends StatelessWidget {
  const _StatsPanel({required this.cells});

  final List<(String, String)> cells;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: AppColors.neutralFill,
        borderRadius: BorderRadius.circular(AppRadius.r8),
      ),
      child: Wrap(
        runSpacing: AppSpacing.s16,
        children: [
          for (final (label, value) in cells)
            FractionallySizedBox(
              widthFactor: 0.5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(value, style: AppTypography.titleL),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ItemLine extends StatelessWidget {
  const _ItemLine({required this.item});

  final DeclarationItem item;

  @override
  Widget build(BuildContext context) {
    final done = item.status.isDone;
    final missed =
        item.status == DeclarationItemStatus.deferred ||
        item.status == DeclarationItemStatus.skipped;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            done
                ? Icons.check_circle_rounded
                : missed
                ? Icons.remove_circle_outline_rounded
                : Icons.circle_outlined,
            size: 18,
            color: done
                ? AppColors.mintInk
                : missed
                ? AppColors.amberInk
                : AppColors.disabled,
          ),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.body.copyWith(
                color: done ? AppColors.muted : AppColors.ink,
              ),
            ),
          ),
          if (missed)
            StatusChip(label: item.status.label, tone: ChipTone.warn)
          else if (item.proof != null)
            const StatusChip(
              label: '인증',
              tone: ChipTone.active,
              icon: Icons.photo_camera_rounded,
            ),
        ],
      ),
    );
  }
}
