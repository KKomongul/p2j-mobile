import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_illustrations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import 'goal_create_screen.dart';
import 'goal_provider.dart';
import 'widgets/goal_card.dart';

/// 목표 목록.
///
/// 상세·수정 화면은 아직 없다. 만들기까지만 있다.
class GoalListScreen extends ConsumerWidget {
  const GoalListScreen({super.key});

  Future<void> _create(BuildContext context) async {
    final created = await GoalCreateScreen.push(context);
    if (created != true || !context.mounted) return;
    AppSnackBar.show(context, '목표를 만들었어요.');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(activeGoalsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('목표')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.ink,
        foregroundColor: Colors.white,
        elevation: 0,
        tooltip: '새 목표',
        onPressed: () => _create(context),
        child: const Icon(Icons.add_rounded),
      ),
      body: goals.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(activeGoalsProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const EmptyView(
                  imagePath: AppIllustrations.goalAdd,
                  title: '아직 목표가 없어요',
                  description: '이루고 싶은 걸 정하면\n주 단위로 나눠 드릴게요.',
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s40,
                  ),
                  child: FilledButton(
                    onPressed: () => _create(context),
                    child: const Text('목표 만들기'),
                  ),
                ),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              AppSpacing.s20,
              AppSpacing.screenH,
              AppSpacing.s40,
            ),
            itemCount: items.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: AppSpacing.s12),
            itemBuilder: (context, index) => GoalCard(goal: items[index]),
          );
        },
      ),
    );
  }
}
