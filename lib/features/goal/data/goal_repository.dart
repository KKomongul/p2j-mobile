import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_response.dart';
import '../../../core/network/dio_client.dart';
import 'goal_api.dart';
import 'goal_models.dart';

part 'goal_repository.g.dart';

/// 목표 저장소. 서버가 구현한 `/v1/goals/*` 를 전부 덮는다.
abstract interface class GoalRepository {
  /// 진행 중인 목표 첫 페이지.
  Future<List<Goal>> fetchActive();

  /// 커서 페이지네이션 목록. 다음 페이지는 [PagedResponse.nextCursor] 로 이어 부른다.
  Future<PagedResponse<Goal>> fetchPage({
    GoalStatus? status,
    String? cursor,
    int? limit,
  });

  Future<Goal> fetchOne(int goalId);

  Future<Goal> create({
    required String title,
    GoalType type,
    String? color,
    GoalFrequency? frequency,
    int? durationWeeks,
    String? startDate,
    int? estimatedMinutes,
  });

  /// 수정. type · frequency · start_date 는 서버가 받지 않는다.
  Future<Goal> update(
    int goalId, {
    String? title,
    String? color,
    int? durationWeeks,
    int? estimatedMinutes,
    GoalStatus? status,
  });

  /// 보관. 지우지 않고 목록에서만 내린다.
  Future<Goal> archive(int goalId);

  /// 삭제. 되돌릴 수 없다. 화면에서는 [archive] 를 먼저 권한다.
  Future<void> delete(int goalId);
}

class GoalRepositoryImpl implements GoalRepository {
  const GoalRepositoryImpl(this._api);

  final GoalApi _api;

  @override
  Future<List<Goal>> fetchActive() => _api.fetchActive();

  @override
  Future<PagedResponse<Goal>> fetchPage({
    GoalStatus? status,
    String? cursor,
    int? limit,
  }) =>
      _api.fetchPage(status: status, cursor: cursor, limit: limit);

  @override
  Future<Goal> fetchOne(int goalId) => _api.fetchOne(goalId);

  @override
  Future<Goal> create({
    required String title,
    GoalType type = GoalType.single,
    String? color,
    GoalFrequency? frequency,
    int? durationWeeks,
    String? startDate,
    int? estimatedMinutes,
  }) =>
      _api.create(
        title: title,
        type: type,
        color: color,
        frequency: frequency,
        durationWeeks: durationWeeks,
        startDate: startDate,
        estimatedMinutes: estimatedMinutes,
      );

  @override
  Future<Goal> update(
    int goalId, {
    String? title,
    String? color,
    int? durationWeeks,
    int? estimatedMinutes,
    GoalStatus? status,
  }) =>
      _api.update(
        goalId,
        title: title,
        color: color,
        durationWeeks: durationWeeks,
        estimatedMinutes: estimatedMinutes,
        status: status,
      );

  @override
  Future<Goal> archive(int goalId) => _api.archive(goalId);

  @override
  Future<void> delete(int goalId) => _api.delete(goalId);
}

@Riverpod(keepAlive: true)
GoalRepository goalRepository(Ref ref) =>
    GoalRepositoryImpl(GoalApi(ref.watch(apiClientProvider)));
