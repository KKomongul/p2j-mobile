import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/dio_client.dart';
import 'todo_api.dart';
import 'todo_models.dart';

part 'todo_repository.g.dart';

/// 투두 저장소. 테스트에서 가짜 구현으로 갈아끼울 수 있게 인터페이스를 분리한다.
///
/// 서버가 구현한 `/v1/todos/*` 를 전부 덮는다.
abstract interface class TodoRepository {
  Future<DayTodos> fetchDay(String date);

  Future<List<DayAchievement>> fetchWeek({String? startDate});

  Future<Todo> fetchOne(int todoId);

  Future<Todo> create({
    required String title,
    String? date,
    int? estimatedMinutes,
    int? goalId,
    String? memo,
  });

  /// AI 초안 확정 저장. 전부 성공하거나 전부 롤백된다.
  Future<TodoBulkResult> createBulk({
    required List<TodoDraftInput> items,
    String source,
    String? parseId,
  });

  /// 부분 수정. 보낸 필드만 바뀐다.
  Future<Todo> update(
    int todoId, {
    String? title,
    String? date,
    int? goalId,
    bool clearGoal,
    int? estimatedMinutes,
    int? order,
    String? memo,
    bool clearMemo,
  });

  Future<Todo> updateTitle(int todoId, String title);

  /// 완료. 응답에 목표 진행률과 연속 기록이 함께 온다.
  Future<TodoCompleteResult> complete(int todoId, {int? actualMinutes});

  /// 완료 취소. 204 라 응답 본문이 없다. summary 는 호출한 쪽에서 다시 센다.
  Future<void> uncomplete(int todoId);

  /// 미루기. to_date 를 생략하면 다음 날로 옮긴다.
  Future<Todo> postpone(int todoId, {String? toDate});

  Future<void> delete(int todoId);
}

class TodoRepositoryImpl implements TodoRepository {
  const TodoRepositoryImpl(this._api);

  final TodoApi _api;

  @override
  Future<DayTodos> fetchDay(String date) => _api.fetchDay(date);

  @override
  Future<List<DayAchievement>> fetchWeek({String? startDate}) =>
      _api.fetchWeek(startDate: startDate);

  @override
  Future<Todo> fetchOne(int todoId) => _api.fetchOne(todoId);

  @override
  Future<Todo> create({
    required String title,
    String? date,
    int? estimatedMinutes,
    int? goalId,
    String? memo,
  }) =>
      _api.create(
        title: title,
        date: date,
        estimatedMinutes: estimatedMinutes,
        goalId: goalId,
        memo: memo,
      );

  @override
  Future<TodoBulkResult> createBulk({
    required List<TodoDraftInput> items,
    String source = 'ai_suggested',
    String? parseId,
  }) =>
      _api.createBulk(items: items, source: source, parseId: parseId);

  @override
  Future<Todo> update(
    int todoId, {
    String? title,
    String? date,
    int? goalId,
    bool clearGoal = false,
    int? estimatedMinutes,
    int? order,
    String? memo,
    bool clearMemo = false,
  }) =>
      _api.update(
        todoId,
        title: title,
        date: date,
        goalId: goalId,
        clearGoal: clearGoal,
        estimatedMinutes: estimatedMinutes,
        order: order,
        memo: memo,
        clearMemo: clearMemo,
      );

  @override
  Future<Todo> updateTitle(int todoId, String title) =>
      _api.updateTitle(todoId, title);

  @override
  Future<TodoCompleteResult> complete(int todoId, {int? actualMinutes}) =>
      _api.complete(todoId, actualMinutes: actualMinutes);

  @override
  Future<void> uncomplete(int todoId) => _api.uncomplete(todoId);

  @override
  Future<Todo> postpone(int todoId, {String? toDate}) =>
      _api.postpone(todoId, toDate: toDate);

  @override
  Future<void> delete(int todoId) => _api.delete(todoId);
}

@Riverpod(keepAlive: true)
TodoRepository todoRepository(Ref ref) =>
    TodoRepositoryImpl(TodoApi(ref.watch(apiClientProvider)));
