import 'dart:io';

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_response.dart';
import '../../../core/network/dio_client.dart';
import 'group_api.dart';
import 'group_models.dart';

part 'group_repository.g.dart';

/// 그룹 저장소. 서버가 구현한 `/v1/groups/*` · `/v1/posts/*` 를 전부 덮는다.
abstract interface class GroupRepository {
  Future<List<Group>> fetchMyGroups();

  Future<Group> create({required String name, int maxMembers});

  Future<Group> fetchOne(int groupId);

  Future<Group> join(String inviteCode);

  /// 새 코드를 만든다. 이전 코드는 폐기된다.
  Future<GroupInvite> issueInvite(int groupId);

  Future<List<GroupMember>> fetchMembers(int groupId, {String? date});

  Future<Group> transferOwner(int groupId, int toUserId);

  Future<void> leave(int groupId);

  /// 아침 선언. 만드는 순간 잠긴다.
  Future<Declaration> declare(
    int groupId, {
    required List<int> todoIds,
    String? date,
  });

  Future<List<DeclarationRow>> fetchDeclarations(int groupId, {String? date});

  Future<Proof> createProof(
    int groupId, {
    required int declarationItemId,
    required String fileKey,
    String? caption,
  });

  /// 사진을 스토리지에 올리고 `file_key` 를 돌려준다.
  ///
  /// presign → 서명 URL 로 직접 PUT 두 단계다. 파일이 서버를 거치지 않는다.
  /// 스토리지가 설정되지 않았으면 presign 에서 503 STORAGE_UNAVAILABLE 이 난다.
  Future<String> uploadImage(File file, {String contentType});

  Future<PagedResponse<FeedEntry>> fetchFeed(
    int groupId, {
    String? date,
    String? cursor,
    int? limit,
  });

  Future<Proof> fetchPost(int postId);

  Future<void> deletePost(int postId);

  Future<PagedResponse<PostComment>> fetchComments(
    int postId, {
    String? cursor,
    int? limit,
  });

  Future<PostComment> addComment(int postId, String content);

  Future<void> deleteComment(int commentId);

  /// 사용자당 1개. 다른 종류를 보내면 교체된다.
  Future<ReactionTally> setReaction(int postId, ReactionType type);

  Future<void> clearReaction(int postId);

  Future<GroupRanking> fetchRanking(int groupId, {RankingPeriod period});

  Future<GroupStreak> fetchStreak(int groupId);
}

class GroupRepositoryImpl implements GroupRepository {
  const GroupRepositoryImpl(this._api, this._uploader);

  final GroupApi _api;

  /// 서명 URL 전용. 인증 헤더가 붙지 않는다 (dio_client.buildUploadDio 참고).
  final Dio _uploader;

  @override
  Future<List<Group>> fetchMyGroups() => _api.fetchMyGroups();

  @override
  Future<Group> create({required String name, int maxMembers = 6}) =>
      _api.create(name: name, maxMembers: maxMembers);

  @override
  Future<Group> fetchOne(int groupId) => _api.fetchOne(groupId);

  @override
  Future<Group> join(String inviteCode) => _api.join(inviteCode);

  @override
  Future<GroupInvite> issueInvite(int groupId) => _api.issueInvite(groupId);

  @override
  Future<List<GroupMember>> fetchMembers(int groupId, {String? date}) =>
      _api.fetchMembers(groupId, date: date);

  @override
  Future<Group> transferOwner(int groupId, int toUserId) =>
      _api.transferOwner(groupId, toUserId);

  @override
  Future<void> leave(int groupId) => _api.leave(groupId);

  @override
  Future<Declaration> declare(
    int groupId, {
    required List<int> todoIds,
    String? date,
  }) =>
      _api.declare(groupId, todoIds: todoIds, date: date);

  @override
  Future<List<DeclarationRow>> fetchDeclarations(int groupId, {String? date}) =>
      _api.fetchDeclarations(groupId, date: date);

  @override
  Future<Proof> createProof(
    int groupId, {
    required int declarationItemId,
    required String fileKey,
    String? caption,
  }) =>
      _api.createProof(
        groupId,
        declarationItemId: declarationItemId,
        fileKey: fileKey,
        caption: caption,
      );

  @override
  Future<String> uploadImage(
    File file, {
    String contentType = 'image/jpeg',
  }) async {
    final presigned = await _api.presign(contentType: contentType);
    await _uploader.put<void>(
      presigned.uploadUrl,
      data: file.openRead(),
      options: Options(
        contentType: presigned.contentType,
        headers: <String, dynamic>{
          Headers.contentLengthHeader: await file.length(),
        },
      ),
    );
    return presigned.fileKey;
  }

  @override
  Future<PagedResponse<FeedEntry>> fetchFeed(
    int groupId, {
    String? date,
    String? cursor,
    int? limit,
  }) =>
      _api.fetchFeed(groupId, date: date, cursor: cursor, limit: limit);

  @override
  Future<Proof> fetchPost(int postId) => _api.fetchPost(postId);

  @override
  Future<void> deletePost(int postId) => _api.deletePost(postId);

  @override
  Future<PagedResponse<PostComment>> fetchComments(
    int postId, {
    String? cursor,
    int? limit,
  }) =>
      _api.fetchComments(postId, cursor: cursor, limit: limit);

  @override
  Future<PostComment> addComment(int postId, String content) =>
      _api.addComment(postId, content);

  @override
  Future<void> deleteComment(int commentId) => _api.deleteComment(commentId);

  @override
  Future<ReactionTally> setReaction(int postId, ReactionType type) =>
      _api.setReaction(postId, type);

  @override
  Future<void> clearReaction(int postId) => _api.clearReaction(postId);

  @override
  Future<GroupRanking> fetchRanking(
    int groupId, {
    RankingPeriod period = RankingPeriod.week,
  }) =>
      _api.fetchRanking(groupId, period: period);

  @override
  Future<GroupStreak> fetchStreak(int groupId) => _api.fetchStreak(groupId);
}

@Riverpod(keepAlive: true)
GroupRepository groupRepository(Ref ref) => GroupRepositoryImpl(
      GroupApi(ref.watch(apiClientProvider)),
      ref.watch(uploadDioProvider),
    );
