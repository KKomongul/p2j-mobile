import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_illustrations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../core/widgets/paper_card.dart';
import '../../data/todo_models.dart';
import '../../../group/presentation/group_provider.dart';
import '../todo_provider.dart';
import 'today_summary_card.dart';
import 'cleared_card.dart';
import 'attach_proof_sheet.dart';
import 'goal_swap_sheet.dart';
import 'todo_tile.dart';
import 'todo_rename_dialog.dart';

/// 선택한 날짜의 진행 요약과 투두 목록.
///
/// 로딩 / 에러 / 빈 상태를 여기서 전부 처리한다.
class DayTodoList extends ConsumerWidget {
  const DayTodoList({required this.date, super.key});

  final String date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todos = ref.watch(dayTodosControllerProvider(date));

    return todos.when(
      loading: () => const LoadingView(),
      error: (error, _) => ErrorView(
        error: error,
        onRetry: () => ref.invalidate(dayTodosControllerProvider(date)),
      ),
      data: (day) => ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.s40 * 2),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              AppSpacing.s12,
              AppSpacing.screenH,
              AppSpacing.s16,
            ),
            child: TodaySummaryCard(summary: day.summary),
          ),
          if (day.items.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.s32),
              child: EmptyView(
                imagePath: AppIllustrations.todayTodo,
                title: '오늘은 아직 비어 있어요',
                description: '아래 + 를 누르고 편하게 말해 보세요.\n무엇을 할지만 말하면 정리해 드릴게요.',
              ),
            )
          else ...[
            _TodoCard(date: date, items: day.items),
            if (day.summary.total > 0 && day.summary.done == day.summary.total)
              const ClearedCard(),
          ],
        ],
      ),
    );
  }
}

class _TodoCard extends ConsumerWidget {
  const _TodoCard({required this.date, required this.items});

  final String date;
  final List<Todo> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        for (final item in items)
          Padding(
            key: ValueKey(item.todoId),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              0,
              AppSpacing.screenH,
              AppSpacing.s8,
            ),
            child: PaperCard(
              padding: EdgeInsets.zero,
              elevated: false,
              child: _dismissible(context, ref, item),
            ),
          ),
      ],
    );
  }

  Widget _dismissible(BuildContext context, WidgetRef ref, Todo todo) {
    final tile = TodoTile(
      todo: todo,
      onToggle: () => _toggle(context, ref, todo),
      onLockedTap: () => AppSnackBar.show(context, '그룹에 선언한 항목은 오늘 수정할 수 없어요.'),
      onAttachProof: () => _attachProof(context, ref, todo),
      onChangeGoal: () => _changeGoal(context, ref, todo),
      onRename: () => _rename(context, ref, todo),
      onDelete: () async {
        if (await _confirmDelete(context, todo) && context.mounted) {
          await _remove(context, ref, todo);
        }
      },
    );

    // 선언한 항목은 삭제가 막힌다. 스와이프 자체를 열어주지 않는다.
    if (todo.isDeclared) return tile;

    return Dismissible(
      key: ValueKey<int>(todo.todoId),
      direction: DismissDirection.endToStart,
      background: Container(
        color: AppColors.coral,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.s20),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      confirmDismiss: (_) => _confirmDelete(context, todo),
      onDismissed: (_) => _remove(context, ref, todo),
      child: tile,
    );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref, Todo todo) async {
    if (todo.isDeclared) {
      AppSnackBar.show(context, '그룹에 선언한 항목은 이름을 수정할 수 없어요.');
      return;
    }
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TodoRenameDialog(
        title: todo.title,
        onSave: (title) => ref
            .read(dayTodosControllerProvider(date).notifier)
            .rename(todo, title),
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context, Todo todo) async {
    if (todo.isDeclared) {
      AppSnackBar.show(context, '그룹에 선언한 항목은 삭제할 수 없어요.');
      return false;
    }
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('할 일을 삭제할까요?'),
            content: Text('“${todo.title}” 항목이 삭제돼요.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('삭제하기'),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// 목표를 갈아끼운다.
  ///
  /// 선언한 항목은 서버가 막으므로 시트를 열지 않고 이유만 말한다.
  /// 시트를 열어 고르게 한 뒤 실패시키면 헛수고를 시키는 셈이다.
  Future<void> _changeGoal(
    BuildContext context,
    WidgetRef ref,
    Todo todo,
  ) async {
    if (todo.isDeclared) {
      AppSnackBar.show(context, '그룹에 선언한 항목은 목표를 바꿀 수 없어요.');
      return;
    }

    final picked = await GoalSwapSheet.show(
      context,
      currentGoalId: todo.goalId,
    );
    if (picked == null || !context.mounted) return;
    if (picked.goalId == todo.goalId) return;

    try {
      await ref
          .read(dayTodosControllerProvider(date).notifier)
          .changeGoal(todo, picked.goalId);
      if (!context.mounted) return;
      AppSnackBar.show(
        context,
        picked.goalId == null ? '목표에서 뺐어요.' : '목표를 바꿨어요.',
      );
    } on ApiException catch (error) {
      if (context.mounted) AppSnackBar.error(context, error.message);
    }
  }

  /// 인증샷을 올리고 선언한 그룹 피드로 보낸다.
  ///
  /// 올리고 나면 그룹 화면들도 같이 낡는다 — 피드·순위·연속 기록이 한 번에 바뀌므로
  /// 해당 그룹을 통째로 비운다.
  Future<void> _attachProof(
    BuildContext context,
    WidgetRef ref,
    Todo todo,
  ) async {
    final failed = await AttachProofSheet.show(context, todo);
    if (failed == null || !context.mounted) return;

    ref.invalidate(dayTodosControllerProvider(date));
    for (final target in todo.declarations) {
      invalidateGroup(ref, target.groupId);
    }
    if (failed.isEmpty) {
      AppSnackBar.show(context, '인증샷을 올렸어요.');
    } else {
      AppSnackBar.error(context, '${failed.join(' · ')}에는 올리지 못했어요.');
    }
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref, Todo todo) async {
    try {
      await ref.read(dayTodosControllerProvider(date).notifier).toggle(todo);
    } on ApiException catch (error) {
      if (!context.mounted) return;
      AppSnackBar.error(context, error.message);
    }
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, Todo todo) async {
    try {
      await ref.read(dayTodosControllerProvider(date).notifier).remove(todo);
    } on ApiException catch (error) {
      if (!context.mounted) return;
      AppSnackBar.error(context, error.message);
    }
  }
}
