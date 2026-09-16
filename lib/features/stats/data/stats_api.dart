import '../../../core/network/api_response.dart';
import '../../../core/network/dio_client.dart';
import 'stats_models.dart';

/// `/v1/stats/*` 호출만 담당한다.
class StatsApi {
  const StatsApi(this._client);

  final ApiClient _client;

  /// 기간별 요약. `GET /stats/summary?period=`
  ///
  /// 일자별 달성률은 서버의 집계표에서 오고, 시간대 분포와 자주 미룬 항목만
  /// 할 일을 직접 센 값이다.
  Future<StatsSummary> fetchSummary({
    StatsPeriod period = StatsPeriod.week,
  }) async {
    final response = await _client.get(
      '/stats/summary',
      query: <String, dynamic>{'period': period.wire},
    );
    return ApiResponse.object(response, StatsSummary.fromJson).data;
  }

  /// 목표 하나의 기간별 추이. `GET /stats/goals/{goal_id}?period=`
  Future<GoalStats> fetchGoal(
    int goalId, {
    StatsPeriod period = StatsPeriod.week,
  }) async {
    final response = await _client.get(
      '/stats/goals/$goalId',
      query: <String, dynamic>{'period': period.wire},
    );
    return ApiResponse.object(response, GoalStats.fromJson).data;
  }
}
