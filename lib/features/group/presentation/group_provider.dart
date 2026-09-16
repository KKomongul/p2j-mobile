import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/group_models.dart';
import '../data/group_repository.dart';

part 'group_provider.g.dart';

/// 내가 속한 그룹 목록. 미확인 수와 마지막 활동 시각이 함께 온다.
@riverpod
Future<List<Group>> myGroups(Ref ref) =>
    ref.watch(groupRepositoryProvider).fetchMyGroups();

/// 그룹 상세.
@riverpod
Future<Group> groupDetail(Ref ref, int groupId) =>
    ref.watch(groupRepositoryProvider).fetchOne(groupId);

/// 구성원과 오늘 현황.
@riverpod
Future<List<GroupMember>> groupMembers(Ref ref, int groupId) =>
    ref.watch(groupRepositoryProvider).fetchMembers(groupId);

/// 오늘의 선언 현황. 미선언 구성원도 함께 온다.
@riverpod
Future<List<DeclarationRow>> groupDeclarations(Ref ref, int groupId) =>
    ref.watch(groupRepositoryProvider).fetchDeclarations(groupId);

/// 피드 첫 페이지.
///
/// 이 호출이 서버의 미확인 배지를 0 으로 만든다. 그래서 읽고 나면 그룹 목록을
/// 무효화해 배지가 실제로 사라지게 한다.
@riverpod
Future<List<FeedEntry>> groupFeed(Ref ref, int groupId) async {
  final page = await ref.watch(groupRepositoryProvider).fetchFeed(groupId);
  ref.invalidate(myGroupsProvider);
  return page.items;
}

/// 순위표가 보고 있는 기간.
@riverpod
class RankingPeriodController extends _$RankingPeriodController {
  @override
  RankingPeriod build() => RankingPeriod.week;

  void select(RankingPeriod period) => state = period;
}

@riverpod
Future<GroupRanking> groupRanking(Ref ref, int groupId) {
  final period = ref.watch(rankingPeriodControllerProvider);
  return ref
      .watch(groupRepositoryProvider)
      .fetchRanking(groupId, period: period);
}

@riverpod
Future<GroupStreak> groupStreak(Ref ref, int groupId) =>
    ref.watch(groupRepositoryProvider).fetchStreak(groupId);

/// 한 게시물의 댓글.
@riverpod
Future<List<PostComment>> postComments(Ref ref, int postId) async {
  final page = await ref.watch(groupRepositoryProvider).fetchComments(postId);
  return page.items;
}

/// 그룹 화면 전체를 다시 읽는다. 선언·완료·인증처럼 여러 화면에 걸친 변화 뒤에 부른다.
///
/// 선언 하나가 오늘 현황·피드·순위·연속 기록을 동시에 바꾼다. 화면마다 따로
/// 무효화하면 하나씩 빠뜨리게 되므로 한 곳에 모은다.
///
/// 위젯에서는 [invalidateGroup], Notifier 안에서는 [invalidateGroupFrom] 을 쓴다.
/// `WidgetRef` 와 `Ref` 는 공통 상위 타입이 없어서 얇은 껍데기를 하나 더 둔다.
void _invalidateGroupWith(
  void Function(ProviderOrFamily provider) invalidate,
  int groupId,
) {
  invalidate(groupDetailProvider(groupId));
  invalidate(groupMembersProvider(groupId));
  invalidate(groupDeclarationsProvider(groupId));
  invalidate(groupFeedProvider(groupId));
  invalidate(groupRankingProvider(groupId));
  invalidate(groupStreakProvider(groupId));
  invalidate(myGroupsProvider);
}

void invalidateGroup(WidgetRef ref, int groupId) =>
    _invalidateGroupWith(ref.invalidate, groupId);

void invalidateGroupFrom(Ref ref, int groupId) =>
    _invalidateGroupWith(ref.invalidate, groupId);
