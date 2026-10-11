import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/group_models.dart';

/// 그룹 목록의 한 줄.
///
/// 카드로 감싸지 않고 흰 바탕에 줄로 늘어놓는다. 여러 방을 빠르게 훑는 화면이라
/// 면이 많으면 시선이 흩어진다. 오른쪽 타일이 "들어가면 무슨 일이 있는지" 를 말한다 —
/// 안 읽은 인증샷이 있으면 숫자, 없으면 조용한 아이콘.
class GroupListRow extends StatelessWidget {
  const GroupListRow({required this.group, required this.onTap, super.key});

  final Group group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final meta = <String>[
      '${group.memberCount}/${group.maxMembers}명',
      if (group.groupStreak > 0) '${group.groupStreak}일 연속',
      if (group.lastActivityAt != null) relativeTime(group.lastActivityAt!),
    ].join(' · ');

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenH,
          vertical: AppSpacing.s16,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleM,
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                      if (group.myRole.isOwner) ...[
                        const SizedBox(width: AppSpacing.s8),
                        const Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: AppColors.amberInk,
                          semanticLabel: '방장',
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.s16),
            _ActivityTile(unread: group.unreadCount),
          ],
        ),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.unread});

  final int unread;

  @override
  Widget build(BuildContext context) {
    final hasUnread = unread > 0;
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: hasUnread ? AppColors.purpleSurface : AppColors.neutralFill,
        borderRadius: BorderRadius.circular(AppRadius.r8),
      ),
      alignment: Alignment.center,
      child: hasUnread
          ? Text(
              unread > 99 ? '99+' : '$unread',
              style: AppTypography.titleM.copyWith(color: AppColors.purple),
            )
          : const Icon(
              Icons.photo_library_outlined,
              size: 22,
              color: AppColors.disabled,
            ),
    );
  }
}

/// 마지막 활동 시각. 분 단위까지만 말하고 그보다 옛날이면 날짜로 바꾼다.
String relativeTime(DateTime at) {
  final diff = DateTime.now().difference(at);
  if (diff.inMinutes < 1) return '방금';
  if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
  if (diff.inHours < 24) return '${diff.inHours}시간 전';
  if (diff.inDays < 7) return '${diff.inDays}일 전';
  return '${at.month}월 ${at.day}일';
}
