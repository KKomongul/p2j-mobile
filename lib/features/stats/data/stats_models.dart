import 'package:freezed_annotation/freezed_annotation.dart';

part 'stats_models.freezed.dart';
part 'stats_models.g.dart';

/// 통계 기간. 서버의 `/stats/summary?period=` 값과 같다.
///
/// **주 = 오늘로 끝나는 최근 7일**이다. 달력 주(월~일)가 아니다.
/// 그룹 랭킹은 규칙이 달라 달력 주를 쓴다 — 명세가 각각 그렇게 정해 두었다.
enum StatsPeriod {
  @JsonValue('week')
  week,
  @JsonValue('month')
  month,
}

extension StatsPeriodX on StatsPeriod {
  String get wire => switch (this) {
        StatsPeriod.week => 'week',
        StatsPeriod.month => 'month',
      };

  String get label => switch (this) {
        StatsPeriod.week => '최근 7일',
        StatsPeriod.month => '최근 30일',
      };
}

@freezed
abstract class StatsRange with _$StatsRange {
  const factory StatsRange({
    @JsonKey(name: 'from') String? fromDate,
    @JsonKey(name: 'to') String? toDate,
  }) = _StatsRange;

  factory StatsRange.fromJson(Map<String, dynamic> json) =>
      _$StatsRangeFromJson(json);
}

/// 하루치 달성률. 막대 하나에 대응한다.
@freezed
abstract class DayRate with _$DayRate {
  const factory DayRate({
    required String date,
    @Default(0.0) double achievementRate,
  }) = _DayRate;

  factory DayRate.fromJson(Map<String, dynamic> json) =>
      _$DayRateFromJson(json);
}

/// 시간대별 완료 수. 서버가 완료가 있는 시간대만 내려준다.
@freezed
abstract class HourCount with _$HourCount {
  const factory HourCount({
    @Default(0) int hour,
    @Default(0) int completed,
  }) = _HourCount;

  factory HourCount.fromJson(Map<String, dynamic> json) =>
      _$HourCountFromJson(json);
}

/// 자주 미룬 항목. 목표가 있으면 목표 단위로 합산되고, 없으면 할 일 하나다.
@freezed
abstract class DeferredEntry with _$DeferredEntry {
  const factory DeferredEntry({
    int? goalId,
    @Default('') String title,
    @Default(0) int deferCount,
  }) = _DeferredEntry;

  factory DeferredEntry.fromJson(Map<String, dynamic> json) =>
      _$DeferredEntryFromJson(json);
}

/// `GET /stats/summary`.
@freezed
abstract class StatsSummary with _$StatsSummary {
  const factory StatsSummary({
    @JsonKey(unknownEnumValue: StatsPeriod.week)
    @Default(StatsPeriod.week)
    StatsPeriod period,
    @Default(StatsRange()) StatsRange range,
    @Default(0.0) double achievementRate,
    @Default(0) int totalTodos,
    @Default(0) int completedTodos,
    @Default(0) int totalActualMinutes,

    /// 그날 할 일을 전부 끝낸 날이 연속으로 이어진 수.
    /// 오늘은 진행 중이라 못 끝냈어도 어제까지의 기록은 살아 있다.
    @Default(0) int currentStreak,
    @Default(0) int longestStreak,
    @Default(<DayRate>[]) List<DayRate> byDay,
    @Default(<HourCount>[]) List<HourCount> byHour,
    @Default(<DeferredEntry>[]) List<DeferredEntry> mostDeferred,
  }) = _StatsSummary;

  factory StatsSummary.fromJson(Map<String, dynamic> json) =>
      _$StatsSummaryFromJson(json);
}

extension StatsSummaryX on StatsSummary {
  /// 기간 안에 기록이 하나도 없는지. 빈 상태 화면 판단에 쓴다.
  bool get isEmpty => totalTodos == 0;

  /// 가장 많이 끝낸 시간대. 기록이 없으면 null.
  HourCount? get peakHour {
    if (byHour.isEmpty) return null;
    return byHour.reduce((a, b) => b.completed > a.completed ? b : a);
  }
}

/// `GET /stats/goals/{goal_id}` 의 일자별 항목.
@freezed
abstract class GoalDayStat with _$GoalDayStat {
  const factory GoalDayStat({
    required String date,
    @Default(0) int total,
    @Default(0) int done,
    @Default(0.0) double achievementRate,
  }) = _GoalDayStat;

  factory GoalDayStat.fromJson(Map<String, dynamic> json) =>
      _$GoalDayStatFromJson(json);
}

/// `GET /stats/goals/{goal_id}`. 기간 추이와 전체 누계를 함께 준다.
@freezed
abstract class GoalStats with _$GoalStats {
  const factory GoalStats({
    required int goalId,
    @Default('') String title,
    String? color,
    String? status,
    @JsonKey(unknownEnumValue: StatsPeriod.week)
    @Default(StatsPeriod.week)
    StatsPeriod period,
    @Default(StatsRange()) StatsRange range,

    /// 기간과 무관한 전체 누계. 목표 화면의 "n/N 회" 와 같은 값이다.
    @Default(0) int totalTodos,
    @Default(0) int completedTodos,
    @Default(0.0) double achievementRate,
    @Default(0) int totalActualMinutes,
    @Default(0) int currentWeekDone,
    @Default(<GoalDayStat>[]) List<GoalDayStat> byDay,
  }) = _GoalStats;

  factory GoalStats.fromJson(Map<String, dynamic> json) =>
      _$GoalStatsFromJson(json);
}
