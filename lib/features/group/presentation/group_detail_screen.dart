import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../data/group_models.dart';
import '../data/group_repository.dart';
import 'group_provider.dart';
import 'widgets/declaration_tab.dart';
import 'widgets/feed_tab.dart';
import 'widgets/invite_sheet.dart';
import 'widgets/ranking_tab.dart';

/// 그룹 상세 — 오늘 · 피드 · 순위.
///
/// 하루의 흐름을 그대로 탭 순서로 뒀다. 아침에 **오늘**에서 선언하고, 저녁에
/// **피드**에서 서로 확인하고, **순위**는 주 단위로 가끔 본다.
class GroupDetailScreen extends ConsumerWidget {
  const GroupDetailScreen({required this.groupId, super.key});

  final int groupId;

  static Future<void> push(BuildContext context, int groupId) {
    return Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute(builder: (_) => GroupDetailScreen(groupId: groupId)),
    );
  }

  Future<void> _leave(BuildContext context, WidgetRef ref, Group group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('그룹에서 나갈까요?'),
        content: Text(
          group.myRole.isOwner && group.memberCount > 1
              ? '방장이라 먼저 다른 사람에게 넘겨야 해요.'
              : '지금까지의 선언과 인증 기록은 남아요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('그대로 둘게요'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              '나가기',
              style: AppTypography.body.copyWith(color: AppColors.coral),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(groupRepositoryProvider).leave(groupId);
      if (!context.mounted) return;
      ref.invalidate(myGroupsProvider);
      Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (context.mounted) AppSnackBar.show(context, error.message);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = ref.watch(groupDetailProvider(groupId));

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            group.value?.name ?? '그룹',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            if (group.hasValue)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (value) async {
                  switch (value) {
                    case 'invite':
                      await InviteSheet.show(context, group.value!);
                    case 'leave':
                      await _leave(context, ref, group.value!);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'invite', child: Text('초대 코드')),
                  PopupMenuItem(value: 'leave', child: Text('그룹 나가기')),
                ],
              ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: '오늘'),
              Tab(text: '피드'),
              Tab(text: '순위'),
            ],
          ),
        ),
        body: group.when(
          loading: () => const LoadingView(),
          error: (error, _) => ErrorView(
            error: error,
            onRetry: () => ref.invalidate(groupDetailProvider(groupId)),
          ),
          data: (data) => TabBarView(
            children: [
              DeclarationTab(group: data),
              FeedTab(groupId: groupId),
              RankingTab(groupId: groupId),
            ],
          ),
        ),
      ),
    );
  }
}

/// 탭 본문이 공통으로 쓰는 좌우 여백.
const EdgeInsets kGroupTabPadding = EdgeInsets.fromLTRB(
  AppSpacing.screenH,
  AppSpacing.s16,
  AppSpacing.screenH,
  AppSpacing.s40,
);
