import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_illustrations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import 'group_detail_screen.dart';
import 'group_provider.dart';
import 'widgets/group_list_row.dart';
import 'widgets/group_start_sheet.dart';

/// 그룹 탭 — 내가 속한 그룹 목록.
///
/// 목록이 비어 있을 때가 기본값이다. 처음 보는 사람이 **무엇을 하는 곳인지**
/// 읽고 바로 시작할 수 있어야 해서, 빈 화면에 설명과 두 갈래 버튼을 함께 둔다.
class GroupListScreen extends ConsumerWidget {
  const GroupListScreen({super.key});

  Future<void> _start(
    BuildContext context,
    WidgetRef ref, {
    bool join = false,
  }) async {
    final group = await GroupStartSheet.show(context, join: join);
    if (group == null || !context.mounted) return;

    ref.invalidate(myGroupsProvider);
    AppSnackBar.show(context, join ? '${group.name}에 참여했어요.' : '그룹을 만들었어요.');
    await GroupDetailScreen.push(context, group.groupId);
    if (context.mounted) ref.invalidate(myGroupsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(myGroupsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('내가 가입한 그룹'),
        actions: [
          IconButton(
            tooltip: '코드로 참여',
            icon: const Icon(Icons.login_rounded),
            onPressed: () => _start(context, ref, join: true),
          ),
        ],
      ),
      floatingActionButton: groups.value?.isEmpty ?? true
          ? null
          : FloatingActionButton(
              // 탭 셸이 세 화면을 함께 살려 두므로 기본 hero 태그가 겹친다.
              heroTag: 'fab-groups',
              backgroundColor: AppColors.ink,
              foregroundColor: Colors.white,
              elevation: 0,
              tooltip: '새 그룹',
              onPressed: () => _start(context, ref),
              child: const Icon(Icons.add_rounded),
            ),
      body: groups.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(myGroupsProvider),
        ),
        data: (items) {
          if (items.isEmpty) return _EmptyBody(onStart: _start);

          return RefreshIndicator(
            color: AppColors.ink,
            onRefresh: () async => ref.invalidate(myGroupsProvider),
            // 다른 탭과 같이 회색 바탕 위 흰 카드 한 장에 줄을 담는다.
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.s16,
                AppSpacing.screenH,
                AppSpacing.s40 * 2, // FAB 에 마지막 줄이 가리지 않게
              ),
              children: [
                Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.r16),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: items.length,
                    separatorBuilder: (context, index) => const Divider(
                      height: 1,
                      thickness: 1,
                      indent: AppSpacing.screenH,
                      endIndent: AppSpacing.screenH,
                      color: AppColors.neutralLine,
                    ),
                    itemBuilder: (context, index) {
                      final group = items[index];
                      return GroupListRow(
                        group: group,
                        onTap: () async {
                          await GroupDetailScreen.push(context, group.groupId);
                          if (context.mounted) ref.invalidate(myGroupsProvider);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EmptyBody extends ConsumerWidget {
  const _EmptyBody({required this.onStart});

  final Future<void> Function(BuildContext, WidgetRef, {bool join}) onStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.s40,
        AppSpacing.screenH,
        AppSpacing.s40,
      ),
      children: [
        const EmptyView(
          imagePath: AppIllustrations.groupShare,
          title: '같이 할 사람이 있으면 달라져요',
          description: '아침에 오늘 할 일을 선언하고\n저녁에 해낸 걸 보여 주는 3~6명짜리 방이에요.',
        ),
        const SizedBox(height: AppSpacing.s8),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => onStart(context, ref),
            child: const Text('그룹 만들기'),
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () => onStart(context, ref, join: true),
            child: Text(
              '초대 코드를 받았어요',
              style: AppTypography.body.copyWith(color: AppColors.purple),
            ),
          ),
        ),
      ],
    );
  }
}
