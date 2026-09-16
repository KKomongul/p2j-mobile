import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/dio_client.dart';
import 'stats_api.dart';
import 'stats_models.dart';

part 'stats_repository.g.dart';

/// 통계 저장소. 서버가 구현한 `/v1/stats/*` 를 전부 덮는다.
abstract interface class StatsRepository {
  Future<StatsSummary> fetchSummary({StatsPeriod period});

  Future<GoalStats> fetchGoal(int goalId, {StatsPeriod period});
}

class StatsRepositoryImpl implements StatsRepository {
  const StatsRepositoryImpl(this._api);

  final StatsApi _api;

  @override
  Future<StatsSummary> fetchSummary({StatsPeriod period = StatsPeriod.week}) =>
      _api.fetchSummary(period: period);

  @override
  Future<GoalStats> fetchGoal(
    int goalId, {
    StatsPeriod period = StatsPeriod.week,
  }) =>
      _api.fetchGoal(goalId, period: period);
}

@Riverpod(keepAlive: true)
StatsRepository statsRepository(Ref ref) =>
    StatsRepositoryImpl(StatsApi(ref.watch(apiClientProvider)));
