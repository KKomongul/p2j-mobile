import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../core/widgets/paper_card.dart';
import '../../../../core/widgets/progress_bar.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../../todo/presentation/todo_provider.dart';
import '../../data/group_models.dart';
import '../group_detail_screen.dart';
import '../group_provider.dart';
import 'declare_sheet.dart';

/// 오늘 탭 — 그룹 연속 기록과 구성원별 선언 현황.
///
/// **아직 선언하지 않은 사람도 그대로 보인다.** 목록에서 빼면 압력 장치가 사라진다.
class DeclarationTab extends ConsumerWidget {
  const DeclarationTab({required this.group, super.key});

  final Group group;

  Future<void> _declare(BuildContext context, WidgetRef ref) async {
    final declaration = await DeclareSheet.show(context, group.groupId);
    if (declaration == null || !context.mounted) return;

    invalidateGroup(ref, group.groupId);
    // 선언하면 그 할 일이 잠기고 그룹 이름이 붙는다. 오늘 화면도 같이 낡는다.
    ref.invalidate(dayTodosControllerProvider);
    AppSnackBar.show(context, '${declaration.items.length}개를 선언했어요.');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(groupDeclarationsProvider(group.groupId));
    final streak = ref.watch(groupStreakProvider(group.groupId));
    final myId = ref.watch(authControllerProvider).value?.userId;

    return rows.when(
      loading: () => const LoadingView(),
      error: (error, _) => ErrorView(
        error: error,
        onRetry: () => invalidateGroup(ref, group.groupId),
      ),
      data: (items) {
        final mine = items.where((r) => r.user.userId == myId).firstOrNull;
        final canDeclare = mine != null && !mine.declared;

        return RefreshIndicator(
          color: AppColors.ink,
          onRefresh: () async => invalidateGroup(ref, group.groupId),
          child: ListView(
            padding: kGroupTabPadding,
            children: [
              streak.maybeWhen(
                data: (data) => _StreakCard(streak: data),
                orElse: () => const SizedBox.shrink(),
              ),
              const SizedBox(height: AppSpacing.s20),
              if (canDeclare) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _declare(context, ref),
                    icon: const Icon(Icons.campaign_rounded, size: 20),
                    label: const Text('오늘 할 일 선언하기'),
                  ),
                ),
                const SizedBox(height: AppSpacing.s20),
              ],
              Text('오늘의 선언', style: AppTypography.titleM),
              const SizedBox(height: AppSpacing.s12),
              for (final row in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.s16),
                  child: _MemberDeclaration(
                    row: row,
                    isMe: row.user.userId == myId,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// 그룹 연속 기록. 오늘 상태를 색으로만 구분한다.
class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.streak});

  final GroupStreak streak;

  @override
  Widget build(BuildContext context) {
    final (tone, label) = switch (streak.todayStatus) {
      GroupStreakStatus.success => (ChipTone.done, '오늘 성공'),
      GroupStreakStatus.broken => (ChipTone.warn, '오늘은 끊겼어요'),
      _ => (ChipTone.active, '진행 중'),
    };

    return PaperCard(
      padding: const EdgeInsets.all(AppSpacing.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('${streak.groupStreak}', style: AppTypography.display),
              Text(
                '일 연속',
                style: AppTypography.titleM.copyWith(color: AppColors.inkSub),
              ),
              const Spacer(),
              StatusChip(label: label, tone: tone),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(
            streak.declaredMembersToday == 0
                ? '아직 아무도 선언하지 않았어요.'
                : '선언한 ${streak.declaredMembersToday}명 중 '
                    '${streak.membersCompletedToday}명이 다 끝냈어요.',
            style: AppTypography.body.copyWith(color: AppColors.inkSub),
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(
            '선언한 사람 전원이 다 끝낸 날만 하루가 쌓여요.',
            style: AppTypography.caption.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

/// 구성원 한 명의 오늘. 선언하지 않았으면 그 사실만 적는다.
class _MemberDeclaration extends StatelessWidget {
  const _MemberDeclaration({required this.row, required this.isMe});

  final DeclarationRow row;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              isMe ? '${row.user.nickname} (나)' : row.user.nickname,
              style: AppTypography.bodyStrong,
            ),
            const SizedBox(width: AppSpacing.s8),
            if (!row.declared)
              const StatusChip(label: '아직 선언 전')
            else
              StatusChip(
                label: '${row.doneCount}/${row.items.length}',
                tone: row.doneCount == row.items.length
                    ? ChipTone.done
                    : ChipTone.active,
              ),
          ],
        ),
        if (row.declared) ...[
          const SizedBox(height: AppSpacing.s8),
          ProgressBar(value: row.achievementRate),
          const SizedBox(height: AppSpacing.s8),
          for (final item in row.items)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s4),
              child: _ItemRow(item: item),
            ),
        ],
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});

  final DeclarationItem item;

  @override
  Widget build(BuildContext context) {
    final done = item.status.isDone;
    final missed = item.status == DeclarationItemStatus.deferred ||
        item.status == DeclarationItemStatus.skipped;

    return Row(
      children: [
        Icon(
          done
              ? Icons.check_circle_rounded
              : missed
                  ? Icons.remove_circle_outline_rounded
                  : Icons.circle_outlined,
          size: 16,
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
              color: done ? AppColors.muted : AppColors.inkSub,
              // 완료를 취소선으로 지우지 않는다. 해낸 것은 읽히게 둔다.
              decoration: TextDecoration.none,
            ),
          ),
        ),
        if (missed)
          Text(
            item.status.label,
            style: AppTypography.label.copyWith(color: AppColors.amberInk),
          ),
        if (item.proof != null) ...[
          const SizedBox(width: AppSpacing.s4),
          const Icon(
            Icons.photo_camera_rounded,
            size: 14,
            color: AppColors.purple,
          ),
        ],
      ],
    );
  }
}
