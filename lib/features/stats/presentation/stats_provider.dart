import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/stats_models.dart';
import '../data/stats_repository.dart';

part 'stats_provider.g.dart';

/// 통계 화면이 보고 있는 기간. 탭을 벗어나도 유지된다.
@riverpod
class StatsPeriodController extends _$StatsPeriodController {
  @override
  StatsPeriod build() => StatsPeriod.week;

  void select(StatsPeriod period) => state = period;
}

/// 기간별 요약. 기간이 바뀌면 자동으로 다시 불린다.
@riverpod
Future<StatsSummary> statsSummary(Ref ref) {
  final period = ref.watch(statsPeriodControllerProvider);
  return ref.watch(statsRepositoryProvider).fetchSummary(period: period);
}

/// 목표 하나의 추이. 목표 상세에서 쓴다.
@riverpod
Future<GoalStats> goalStats(Ref ref, int goalId) {
  final period = ref.watch(statsPeriodControllerProvider);
  return ref.watch(statsRepositoryProvider).fetchGoal(goalId, period: period);
}
