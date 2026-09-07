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
import '../../data/todo_models.dart';
import '../todo_provider.dart';
import 'today_summary_card.dart';
import 'cleared_card.dart';
import 'todo_tile.dart';

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
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0)
            const Divider(indent: AppSpacing.s20, endIndent: AppSpacing.s20),
          _dismissible(context, ref, items[i]),
        ],
      ],
    );
  }

  Widget _dismissible(BuildContext context, WidgetRef ref, Todo todo) {
    final tile = TodoTile(
      todo: todo,
      onToggle: () => _toggle(context, ref, todo),
      onLockedTap: () => AppSnackBar.show(
        context,
        '그룹에 선언한 항목은 오늘 수정할 수 없어요.',
      ),
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
        child: const Icon(
          Icons.delete_outline_rounded,
          color: Colors.white,
        ),
      ),
      onDismissed: (_) => _remove(context, ref, todo),
      child: tile,
    );
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
