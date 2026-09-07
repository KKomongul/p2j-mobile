import '../../../core/network/api_response.dart';
import '../../../core/network/dio_client.dart';
import 'todo_models.dart';

/// `/v1/todos/*` 호출만 담당한다. 상태 관리나 낙관적 갱신은 하지 않는다.
///
/// 서버가 구현한 엔드포인트를 전부 덮는다. 아직 화면이 없는 것도 있는데,
/// 화면을 만들 때 여기부터 다시 짜지 않아도 되게 두었다.
class TodoApi {
  const TodoApi(this._client);

  final ApiClient _client;

  /// 하루 목록 + summary. `GET /todos?date=`
  ///
  /// date 를 생략하면 서버가 04:00 KST 기준 오늘로 채운다.
  Future<DayTodos> fetchDay([String? date]) async {
    final response = await _client.get(
      '/todos',
      query: date == null ? null : <String, dynamic>{'date': date},
    );
    return ApiResponse.object(response, DayTodos.fromJson).data;
  }

  /// 7일 달성률 스트립. `GET /todos/week`
  ///
  /// start_date 를 넘기지 않으면 서버가 오늘-6일부터 7일을 준다.
  /// 클라이언트가 날짜를 계산하지 않기 위해 기본값을 그대로 쓴다.
  Future<List<DayAchievement>> fetchWeek({String? startDate}) async {
    final response = await _client.get(
      '/todos/week',
      query: startDate == null
          ? null
          : <String, dynamic>{'start_date': startDate},
    );
    return ApiResponse.list(response, DayAchievement.fromJson).data;
  }

  /// 단건 조회. `GET /todos/{id}`
  Future<Todo> fetchOne(int todoId) async {
    final response = await _client.get('/todos/$todoId');
    return ApiResponse.object(response, Todo.fromJson).data;
  }

  /// 단건 생성. `POST /todos` → 201
  ///
  /// date 를 생략하면 서버가 오늘로 채운다.
  Future<Todo> create({
    required String title,
    String? date,
    int? estimatedMinutes,
    int? goalId,
    String? memo,
  }) async {
    final response = await _client.post(
      '/todos',
      data: <String, dynamic>{
        'title': title,
        if (date != null) 'date': date,
        if (estimatedMinutes != null) 'estimated_minutes': estimatedMinutes,
        if (goalId != null) 'goal_id': goalId,
        if (memo != null) 'memo': memo,
      },
    );
    return ApiResponse.object(response, Todo.fromJson).data;
  }

  /// AI 초안 확정 저장. `POST /todos/bulk` → 201
  ///
  /// 하나라도 실패하면 서버가 전부 롤백한다. 부분 저장은 없다.
  /// [parseId] 는 `/ai/parse` 응답의 값을 그대로 넘긴다.
  Future<TodoBulkResult> createBulk({
    required List<TodoDraftInput> items,
    String source = 'ai_suggested',
    String? parseId,
  }) async {
    final response = await _client.post(
      '/todos/bulk',
      data: <String, dynamic>{
        'source': source,
        if (parseId != null) 'parse_id': parseId,
        'items': items.map((e) => e.toJson()).toList(growable: false),
      },
    );
    return ApiResponse.object(response, TodoBulkResult.fromJson).data;
  }

  /// 부분 수정. `PATCH /todos/{id}`
  ///
  /// 서버는 **보낸 필드만** 바꾼다. null 을 넘겨 값을 지우려면 clear 플래그를 쓴다.
  /// (Dart 에서는 "안 보냄"과 "null 로 보냄"을 named 인자만으로 구분할 수 없다)
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
  }) async {
    final response = await _client.patch(
      '/todos/$todoId',
      data: <String, dynamic>{
        if (title != null) 'title': title,
        if (date != null) 'date': date,
        if (clearGoal) 'goal_id': null else if (goalId != null) 'goal_id': goalId,
        if (estimatedMinutes != null) 'estimated_minutes': estimatedMinutes,
        if (order != null) 'order': order,
        if (clearMemo) 'memo': null else if (memo != null) 'memo': memo,
      },
    );
    return ApiResponse.object(response, Todo.fromJson).data;
  }

  /// 제목만 바꾸는 흔한 경우의 지름길.
  Future<Todo> updateTitle(int todoId, String title) =>
      update(todoId, title: title);

  /// 완료. `POST /todos/{id}/complete`
  ///
  /// 응답에 목표 진행률과 연속 기록이 함께 온다.
  /// 선언 잠금(`is_declared`)과 무관하게 항상 허용된다.
  Future<TodoCompleteResult> complete(int todoId, {int? actualMinutes}) async {
    final response = await _client.post(
      '/todos/$todoId/complete',
      data: <String, dynamic>{
        if (actualMinutes != null) 'actual_minutes': actualMinutes,
      },
    );
    return ApiResponse.object(response, TodoCompleteResult.fromJson).data;
  }

  /// 완료 취소. `POST /todos/{id}/uncomplete` → **204, 본문 없음**
  ///
  /// 응답이 없으므로 호출한 쪽에서 summary 를 다시 계산해야 한다.
  Future<void> uncomplete(int todoId) =>
      _client.post('/todos/$todoId/uncomplete');

  /// 미루기. `POST /todos/{id}/postpone`
  ///
  /// to_date 를 생략하면 서버가 다음 날로 옮기고 postpone_count 를 올린다.
  Future<Todo> postpone(int todoId, {String? toDate}) async {
    final response = await _client.post(
      '/todos/$todoId/postpone',
      data: <String, dynamic>{if (toDate != null) 'to_date': toDate},
    );
    return ApiResponse.object(response, Todo.fromJson).data;
  }

  /// 삭제(soft delete). `DELETE /todos/{id}` → **204, 본문 없음**
  Future<void> delete(int todoId) => _client.delete('/todos/$todoId');
}
