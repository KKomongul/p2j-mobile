import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/paper_card.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../data/group_models.dart';

/// 그룹 목록의 한 장.
///
/// 카톡 방 목록과 같은 역할이라 **미확인 수와 마지막 활동 시각**이 가장 중요하다.
/// 연속 기록은 있을 때만 칩으로 붙인다 — 0일을 크게 적으면 시작하기가 부담스러워진다.
class GroupCard extends StatelessWidget {
  const GroupCard({required this.group, required this.onTap, super.key});

  final Group group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PaperCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  group.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleM,
                ),
              ),
              if (group.hasUnread) ...[
                const SizedBox(width: AppSpacing.s8),
                _UnreadBadge(count: group.unreadCount),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          Row(
            children: [
              Text(
                '${group.memberCount}/${group.maxMembers}명',
                style: AppTypography.caption.copyWith(color: AppColors.muted),
              ),
              if (group.lastActivityAt != null) ...[
                Text(
                  '  ·  ',
                  style: AppTypography.caption.copyWith(color: AppColors.muted),
                ),
                Text(
                  _relative(group.lastActivityAt!),
                  style: AppTypography.caption.copyWith(color: AppColors.muted),
                ),
              ],
              const Spacer(),
              if (group.groupStreak > 0)
                StatusChip(
                  label: '${group.groupStreak}일 연속',
                  tone: ChipTone.done,
                ),
              if (group.myRole.isOwner) ...[
                const SizedBox(width: AppSpacing.s4),
                const StatusChip(label: '방장'),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// 마지막 활동 시각. 분 단위까지만 말하고 그보다 옛날이면 날짜로 바꾼다.
  static String _relative(DateTime at) {
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${at.month}월 ${at.day}일';
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.coral,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: AppTypography.label.copyWith(color: Colors.white),
      ),
    );
  }
}
