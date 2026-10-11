import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../../todo/presentation/todo_provider.dart';
import '../../data/group_models.dart';
import '../group_detail_screen.dart';
import '../group_provider.dart';
import 'declare_sheet.dart';
import 'member_sheet.dart';
import 'member_tile.dart';

/// 그룹 홈 — 연속 기록 한 줄, 오늘 현황 한 줄, 그리고 구성원 칸.
///
/// 한 화면에서 "누가 선언했고 누가 다 끝냈는지" 가 바로 보여야 한다.
/// **아직 선언하지 않은 사람도 칸으로 남는다.** 빼면 압력 장치가 사라진다.
class GroupHomeTab extends ConsumerWidget {
  const GroupHomeTab({required this.group, super.key});

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
    final streak = ref.watch(groupStreakProvider(group.groupId)).value;
    final members = ref.watch(groupMembersProvider(group.groupId)).value;
    final myId = ref.watch(authControllerProvider).value?.userId;

    return rows.when(
      loading: () => const LoadingView(),
      error: (error, _) => ErrorView(
        error: error,
        onRetry: () => invalidateGroup(ref, group.groupId),
      ),
      data: (items) {
        final mine = items.where((r) => r.user.userId == myId).firstOrNull;
        final declared = items.where((r) => r.declared).length;
        final cleared = items
            .where(
              (r) =>
                  r.declared &&
                  r.items.isNotEmpty &&
                  r.doneCount == r.items.length,
            )
            .length;

        return RefreshIndicator(
          color: AppColors.ink,
          onRefresh: () async => invalidateGroup(ref, group.groupId),
          child: ListView(
            padding: kGroupTabPadding,
            children: [
              if (streak != null) _StreakBanner(streak: streak),
              const SizedBox(height: AppSpacing.s20),
              _TodaySummary(declared: declared, cleared: cleared),
              const SizedBox(height: AppSpacing.s12),
              if (mine != null && !mine.declared) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _declare(context, ref),
                    icon: const Icon(Icons.campaign_rounded, size: 20),
                    label: const Text('오늘 할 일 선언하기'),
                  ),
                ),
                const SizedBox(height: AppSpacing.s16),
              ],
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: AppSpacing.s8,
                crossAxisSpacing: AppSpacing.s8,
                childAspectRatio: 0.7,
                children: [
                  for (final row in items)
                    MemberTile(
                      row: row,
                      isMe: row.user.userId == myId,
                      onTap: () => MemberSheet.show(
                        context,
                        row: row,
                        isMe: row.user.userId == myId,
                        member: members
                            ?.where((m) => m.userId == row.user.userId)
                            .firstOrNull,
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 그룹 연속 기록 한 줄. 규칙은 아래에 작게 붙인다.
class _StreakBanner extends StatelessWidget {
  const _StreakBanner({required this.streak});

  final GroupStreak streak;

  @override
  Widget build(BuildContext context) {
    final (tone, label) = switch (streak.todayStatus) {
      GroupStreakStatus.success => (ChipTone.done, '오늘 성공'),
      GroupStreakStatus.broken => (ChipTone.warn, '오늘은 끊겼어요'),
      _ => (ChipTone.active, '진행 중'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s12,
      ),
      decoration: BoxDecoration(
        color: AppColors.neutralFill,
        borderRadius: BorderRadius.circular(AppRadius.r8),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.local_fire_department_rounded,
            size: 20,
            color: AppColors.amberInk,
          ),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '그룹 ${streak.groupStreak}일 연속',
                  style: AppTypography.bodyStrong,
                ),
                Text(
                  '선언한 사람 전원이 다 끝낸 날만 쌓여요',
                  style: AppTypography.label.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
          StatusChip(label: label, tone: tone),
        ],
      ),
    );
  }
}

/// "2명 선언 | 1명 다 끝냄" — 레퍼런스의 "0명 공부중" 자리.
class _TodaySummary extends StatelessWidget {
  const _TodaySummary({required this.declared, required this.cleared});

  final int declared;
  final int cleared;

  @override
  Widget build(BuildContext context) {
    final strong = AppTypography.bodyStrong;
    final muted = AppTypography.body.copyWith(color: AppColors.muted);

    return Row(
      children: [
        Text('$declared명', style: strong.copyWith(color: AppColors.purple)),
        Text(' 선언', style: muted),
        Container(
          width: 1,
          height: 12,
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
          color: AppColors.neutralLine,
        ),
        Text('$cleared명', style: strong.copyWith(color: AppColors.mintInk)),
        Text(' 다 끝냄', style: muted),
      ],
    );
  }
}
