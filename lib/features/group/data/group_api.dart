import '../../../core/network/api_response.dart';
import '../../../core/network/dio_client.dart';
import 'group_models.dart';

/// `/v1/groups/*` 와 `/v1/posts/*` 호출만 담당한다.
///
/// 그룹·선언·인증·피드·랭킹이 모두 그룹 하위 경로라 한 클래스에 둔다.
/// 댓글과 리액션만 `/posts/*` 아래에 따로 있다.
class GroupApi {
  const GroupApi(this._client);

  final ApiClient _client;

  // ---------------------------------------------------------------- 그룹

  /// 내가 속한 그룹 목록. `GET /groups`
  ///
  /// 각 항목에 `unread_count` 와 `last_activity_at` 이 들어 있다.
  Future<List<Group>> fetchMyGroups() async {
    final response = await _client.get('/groups');
    return ApiResponse.list(response, Group.fromJson).data;
  }

  /// 생성. `POST /groups` → 201
  ///
  /// [maxMembers] 는 서버가 3~6 으로 강제한다. 신청서 기준이다.
  Future<Group> create({required String name, int maxMembers = 6}) async {
    final response = await _client.post(
      '/groups',
      data: <String, dynamic>{'name': name, 'max_members': maxMembers},
    );
    return ApiResponse.object(response, Group.fromJson).data;
  }

  /// 상세. `GET /groups/{id}`
  Future<Group> fetchOne(int groupId) async {
    final response = await _client.get('/groups/$groupId');
    return ApiResponse.object(response, Group.fromJson).data;
  }

  /// 초대 코드로 참여. `POST /groups/join`
  ///
  /// 오류: 422 `INVALID_INVITE_CODE` · `INVITE_CODE_EXPIRED` · `GROUP_FULL`,
  /// 409 `ALREADY_MEMBER`.
  Future<Group> join(String inviteCode) async {
    final response = await _client.post(
      '/groups/join',
      data: <String, dynamic>{'invite_code': inviteCode},
    );
    return ApiResponse.object(response, Group.fromJson).data;
  }

  /// 새 초대 코드 발급. `POST /groups/{id}/invite`
  ///
  /// **이전 코드는 폐기된다.** 유효한 코드는 그룹당 하나뿐이다. 유효기간 7일.
  Future<GroupInvite> issueInvite(int groupId) async {
    final response = await _client.post('/groups/$groupId/invite');
    return ApiResponse.object(response, GroupInvite.fromJson).data;
  }

  /// 구성원과 오늘 현황. `GET /groups/{id}/members?date=`
  Future<List<GroupMember>> fetchMembers(int groupId, {String? date}) async {
    final response = await _client.get(
      '/groups/$groupId/members',
      query: <String, dynamic>{if (date != null) 'date': date},
    );
    return ApiResponse.list(response, GroupMember.fromJson).data;
  }

  /// 방장 넘기기. `POST /groups/{id}/owner`
  Future<Group> transferOwner(int groupId, int toUserId) async {
    final response = await _client.post(
      '/groups/$groupId/owner',
      data: <String, dynamic>{'user_id': toUserId},
    );
    return ApiResponse.object(response, Group.fromJson).data;
  }

  /// 나가기. `DELETE /groups/{id}/members/me` → **204, 본문 없음**
  ///
  /// 방장은 구성원이 남아 있으면 먼저 넘겨야 한다 (422 `ADMIN_MUST_TRANSFER`).
  Future<void> leave(int groupId) =>
      _client.delete('/groups/$groupId/members/me');

  // ---------------------------------------------------------------- 선언

  /// 아침 선언. `POST /groups/{id}/declarations` → 201
  ///
  /// **만드는 순간 잠긴다.** 수정도 삭제도 없다. 하루 한 번, 당일 것만 된다.
  /// 선언한 할 일은 제목·날짜·삭제가 잠기고 완료 체크만 열려 있다.
  Future<Declaration> declare(
    int groupId, {
    required List<int> todoIds,
    String? date,
  }) async {
    final response = await _client.post(
      '/groups/$groupId/declarations',
      data: <String, dynamic>{
        'todo_ids': todoIds,
        if (date != null) 'date': date,
      },
    );
    return ApiResponse.object(response, Declaration.fromJson).data;
  }

  /// 그날의 그룹 선언 현황. `GET /groups/{id}/declarations?date=`
  ///
  /// 미선언 구성원도 함께 온다.
  Future<List<DeclarationRow>> fetchDeclarations(
    int groupId, {
    String? date,
  }) async {
    final response = await _client.get(
      '/groups/$groupId/declarations',
      query: <String, dynamic>{if (date != null) 'date': date},
    );
    return ApiResponse.list(response, DeclarationRow.fromJson).data;
  }

  // ---------------------------------------------------------- 인증 · 피드

  /// 인증샷 등록. `POST /groups/{id}/proofs` → 201
  ///
  /// 끝낸 항목에만 붙일 수 있다 (409 `TODO_NOT_DONE`), 1항목 1인증
  /// (422 `PROOF_ALREADY_EXISTS`).
  Future<Proof> createProof(
    int groupId, {
    required int declarationItemId,
    required String fileKey,
    String? caption,
  }) async {
    final response = await _client.post(
      '/groups/$groupId/proofs',
      data: <String, dynamic>{
        'declaration_item_id': declarationItemId,
        'file_key': fileKey,
        if (caption != null) 'caption': caption,
      },
    );
    return ApiResponse.object(response, Proof.fromJson).data;
  }

  /// 피드. `GET /groups/{id}/feed?date=&cursor=&limit=`
  ///
  /// 사용자별·날짜별로 묶여 온다. 첫 페이지를 부르면 미확인 배지가 내려간다.
  Future<PagedResponse<FeedEntry>> fetchFeed(
    int groupId, {
    String? date,
    String? cursor,
    int? limit,
  }) async {
    final response = await _client.get(
      '/groups/$groupId/feed',
      query: <String, dynamic>{
        if (date != null) 'date': date,
        if (cursor != null) 'cursor': cursor,
        if (limit != null) 'limit': limit,
      },
    );
    return PagedResponse.parse(response, FeedEntry.fromJson);
  }

  /// 인증샷 단건. `GET /posts/{id}`
  Future<Proof> fetchPost(int postId) async {
    final response = await _client.get('/posts/$postId');
    return ApiResponse.object(response, Proof.fromJson).data;
  }

  /// 인증샷 삭제. `DELETE /posts/{id}` → 204. 작성자 본인만.
  Future<void> deletePost(int postId) => _client.delete('/posts/$postId');

  // ------------------------------------------------------- 댓글 · 리액션

  /// 댓글 목록. `GET /posts/{id}/comments` — 오래된 순, 커서.
  Future<PagedResponse<PostComment>> fetchComments(
    int postId, {
    String? cursor,
    int? limit,
  }) async {
    final response = await _client.get(
      '/posts/$postId/comments',
      query: <String, dynamic>{
        if (cursor != null) 'cursor': cursor,
        if (limit != null) 'limit': limit,
      },
    );
    return PagedResponse.parse(response, PostComment.fromJson);
  }

  /// 댓글 달기. `POST /posts/{id}/comments` → 201
  Future<PostComment> addComment(int postId, String content) async {
    final response = await _client.post(
      '/posts/$postId/comments',
      data: <String, dynamic>{'content': content},
    );
    return ApiResponse.object(response, PostComment.fromJson).data;
  }

  /// 댓글 삭제. `DELETE /comments/{id}` → 204. 작성자 본인만.
  Future<void> deleteComment(int commentId) =>
      _client.delete('/comments/$commentId');

  /// 리액션. `PUT /posts/{id}/reactions`
  ///
  /// 사용자당 하나다. 다른 종류를 다시 보내면 **교체**된다.
  Future<ReactionTally> setReaction(int postId, ReactionType type) async {
    final response = await _client.put(
      '/posts/$postId/reactions',
      data: <String, dynamic>{'type': type.wire},
    );
    return ApiResponse.object(response, ReactionTally.fromJson).data;
  }

  /// 리액션 취소. `DELETE /posts/{id}/reactions` → 204. 없어도 성공한다.
  Future<void> clearReaction(int postId) =>
      _client.delete('/posts/$postId/reactions');

  // ------------------------------------------------------ 랭킹 · 스트릭

  /// 순위표. `GET /groups/{id}/ranking?period=`
  ///
  /// 미선언 구성원도 0% 로 목록에 남는다.
  Future<GroupRanking> fetchRanking(
    int groupId, {
    RankingPeriod period = RankingPeriod.week,
  }) async {
    final response = await _client.get(
      '/groups/$groupId/ranking',
      query: <String, dynamic>{'period': period.wire},
    );
    return ApiResponse.object(response, GroupRanking.fromJson).data;
  }

  /// 그룹 연속 기록. `GET /groups/{id}/streak`
  Future<GroupStreak> fetchStreak(int groupId) async {
    final response = await _client.get('/groups/$groupId/streak');
    return ApiResponse.object(response, GroupStreak.fromJson).data;
  }
}
