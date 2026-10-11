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
import 'widgets/feed_tab.dart';
import 'widgets/group_home_tab.dart';
import 'widgets/group_tool_bar.dart';
import 'widgets/invite_sheet.dart';
import 'widgets/ranking_tab.dart';

/// 그룹 상세 — 홈 · 피드 · 순위, 그리고 초대.
///
/// 하루의 흐름을 그대로 툴바 순서로 뒀다. 아침에 **홈**에서 선언하고, 저녁에
/// **피드**에서 서로 확인하고, **순위**는 주 단위로 가끔 본다.
///
/// 그룹에 들어오면 앱 바텀 네비게이션 대신 그룹 전용 툴바가 맨 아래에 뜬다
/// (루트 내비게이터로 띄우므로 앱 셸 위를 덮는다). 화면은 흰 바탕이다 —
/// 여러 사람의 현황을 훑는 곳이라 종이 질감보다 정돈이 먼저다.
class GroupDetailScreen extends ConsumerStatefulWidget {
  const GroupDetailScreen({required this.groupId, super.key});

  final int groupId;

  static Future<void> push(BuildContext context, int groupId) {
    return Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute(builder: (_) => GroupDetailScreen(groupId: groupId)),
    );
  }

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> {
  int _index = 0;

  /// 한 번이라도 연 칸. 피드는 처음 열 때 읽는다 — 읽는 순간 서버가 미확인 배지를
  /// 0 으로 만들기 때문에, 홈만 보고 나간 사람의 배지를 지우면 안 된다.
  final Set<int> _opened = {0};

  int get _groupId => widget.groupId;

  void _select(int next) => setState(() {
    _index = next;
    _opened.add(next);
  });

  Future<void> _leave(Group group) async {
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
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(groupRepositoryProvider).leave(_groupId);
      if (!mounted) return;
      ref.invalidate(myGroupsProvider);
      Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (mounted) AppSnackBar.show(context, error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = ref.watch(groupDetailProvider(_groupId));
    final data = group.value;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        centerTitle: true,
        title: Text(
          data?.name ?? '그룹',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.titleM,
        ),
        actions: [
          if (data != null)
            PopupMenuButton<String>(
              tooltip: '그룹 설정',
              icon: const Icon(Icons.settings_rounded),
              onSelected: (value) async {
                switch (value) {
                  case 'invite':
                    await InviteSheet.show(context, data);
                  case 'leave':
                    await _leave(data);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'invite', child: Text('초대 코드')),
                PopupMenuItem(value: 'leave', child: Text('그룹 나가기')),
              ],
            ),
        ],
      ),
      bottomNavigationBar: data == null
          ? null
          : GroupToolBar(
              index: _index,
              feedBadge: _opened.contains(1) ? 0 : data.unreadCount,
              onSelect: _select,
              onInvite: () => InviteSheet.show(context, data),
            ),
      body: group.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(groupDetailProvider(_groupId)),
        ),
        // IndexedStack: 다른 칸에 다녀와도 스크롤 위치가 그대로 남는다.
        data: (group) => IndexedStack(
          index: _index,
          children: [
            GroupHomeTab(group: group),
            if (_opened.contains(1))
              FeedTab(groupId: _groupId)
            else
              const SizedBox.shrink(),
            if (_opened.contains(2))
              RankingTab(groupId: _groupId)
            else
              const SizedBox.shrink(),
          ],
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
