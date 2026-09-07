import '../../../core/network/api_response.dart';
import '../../../core/network/dio_client.dart';
import 'goal_models.dart';

/// `/v1/goals/*` 호출만 담당한다.
///
/// 서버가 구현한 엔드포인트를 전부 덮는다. 목록은 커서 페이지네이션이라
/// [fetchPage] 가 원본이고 [fetchActive] 는 첫 페이지만 쓰는 지름길이다.
class GoalApi {
  const GoalApi(this._client);

  final ApiClient _client;

  /// 목록. `GET /goals?status=&cursor=&limit=`
  ///
  /// [status] 는 active · completed · archived. 생략하면 전부.
  /// [limit] 은 서버가 1~50 으로 자르고 기본 20 이다.
  Future<PagedResponse<Goal>> fetchPage({
    GoalStatus? status,
    String? cursor,
    int? limit,
  }) async {
    final response = await _client.get(
      '/goals',
      query: <String, dynamic>{
        if (status != null) 'status': _statusWire(status),
        if (cursor != null) 'cursor': cursor,
        if (limit != null) 'limit': limit,
      },
    );
    return PagedResponse.parse(response, Goal.fromJson);
  }

  /// 진행 중인 목표 첫 페이지. 홈·목표 탭이 쓴다.
  Future<List<Goal>> fetchActive() async {
    final page = await fetchPage(status: GoalStatus.active);
    return page.items;
  }

  /// 단건 조회. `GET /goals/{id}`
  Future<Goal> fetchOne(int goalId) async {
    final response = await _client.get('/goals/$goalId');
    return ApiResponse.object(response, Goal.fromJson).data;
  }

  /// 생성. `POST /goals` → 201
  ///
  /// [type] 이 recurring 이면 [frequency] 가 필요하다.
  /// start_date 를 생략하면 서버가 오늘로 채우고, end_date 를 직접 계산해 저장한다.
  Future<Goal> create({
    required String title,
    GoalType type = GoalType.single,
    String? color,
    GoalFrequency? frequency,
    int? durationWeeks,
    String? startDate,
    int? estimatedMinutes,
  }) async {
    final response = await _client.post(
      '/goals',
      data: <String, dynamic>{
        'title': title,
        'type': _typeWire(type),
        if (color != null) 'color': color,
        if (frequency != null) 'frequency': _frequencyWire(frequency),
        if (durationWeeks != null) 'duration_weeks': durationWeeks,
        if (startDate != null) 'start_date': startDate,
        if (estimatedMinutes != null) 'estimated_minutes': estimatedMinutes,
      },
    );
    return ApiResponse.object(response, Goal.fromJson).data;
  }

  /// 수정. `PATCH /goals/{id}`
  ///
  /// **type · frequency · start_date 는 바꿀 수 없다.** 진행률의 의미가 깨지기 때문이다.
  /// 서버가 받는 status 는 active · completed 뿐이다. 보관은 [archive] 를 쓴다.
  Future<Goal> update(
    int goalId, {
    String? title,
    String? color,
    int? durationWeeks,
    int? estimatedMinutes,
    GoalStatus? status,
  }) async {
    final response = await _client.patch(
      '/goals/$goalId',
      data: <String, dynamic>{
        if (title != null) 'title': title,
        if (color != null) 'color': color,
        if (durationWeeks != null) 'duration_weeks': durationWeeks,
        if (estimatedMinutes != null) 'estimated_minutes': estimatedMinutes,
        if (status != null) 'status': _statusWire(status),
      },
    );
    return ApiResponse.object(response, Goal.fromJson).data;
  }

  /// 보관. `POST /goals/{id}/archive`
  ///
  /// 지우지 않고 목록에서만 내린다. 지난 기록은 그대로 남는다.
  Future<Goal> archive(int goalId) async {
    final response = await _client.post('/goals/$goalId/archive');
    return ApiResponse.object(response, Goal.fromJson).data;
  }

  /// 삭제. `DELETE /goals/{id}` → **204, 본문 없음**
  ///
  /// 연결된 할 일은 지워지지 않고 goal_id 만 끊긴다.
  /// 서버 쪽에서 이 동작을 유지할지 아직 정해지지 않았다 (결정 필요 A8).
  /// 되돌릴 수 없으므로 화면에서는 [archive] 를 먼저 권한다.
  Future<void> delete(int goalId) => _client.delete('/goals/$goalId');

  static String _statusWire(GoalStatus status) => switch (status) {
        GoalStatus.active => 'active',
        GoalStatus.completed => 'completed',
        GoalStatus.archived => 'archived',
        GoalStatus.unknown =>
          throw ArgumentError('GoalStatus.unknown 은 서버로 보낼 수 없습니다.'),
      };

  static String _typeWire(GoalType type) => switch (type) {
        GoalType.single => 'single',
        GoalType.recurring => 'recurring',
        GoalType.unknown =>
          throw ArgumentError('GoalType.unknown 은 서버로 보낼 수 없습니다.'),
      };

  static Map<String, dynamic> _frequencyWire(GoalFrequency frequency) {
    final per = switch (frequency.per) {
      FrequencyPer.week => 'week',
      FrequencyPer.month => 'month',
      FrequencyPer.unknown =>
        throw ArgumentError('FrequencyPer.unknown 은 서버로 보낼 수 없습니다.'),
    };
    return <String, dynamic>{'times': frequency.times, 'per': per};
  }
}
