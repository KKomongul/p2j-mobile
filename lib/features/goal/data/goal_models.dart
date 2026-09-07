import 'package:freezed_annotation/freezed_annotation.dart';

part 'goal_models.freezed.dart';
part 'goal_models.g.dart';

enum GoalType {
  @JsonValue('single')
  single,
  @JsonValue('recurring')
  recurring,
  unknown,
}

enum GoalStatus {
  @JsonValue('active')
  active,
  @JsonValue('completed')
  completed,
  @JsonValue('archived')
  archived,
  unknown,
}

enum FrequencyPer {
  @JsonValue('week')
  week,
  @JsonValue('month')
  month,
  unknown,
}

extension GoalStatusX on GoalStatus {
  String? get badgeLabel => switch (this) {
        GoalStatus.completed => '완료',
        GoalStatus.archived => '보관',
        _ => null,
      };
}

extension FrequencyPerX on FrequencyPer {
  String get label => switch (this) {
        FrequencyPer.week => '주',
        FrequencyPer.month => '달',
        FrequencyPer.unknown => '',
      };
}

@freezed
abstract class GoalFrequency with _$GoalFrequency {
  const factory GoalFrequency({
    @Default(0) int times,
    @JsonKey(unknownEnumValue: FrequencyPer.unknown)
    @Default(FrequencyPer.unknown)
    FrequencyPer per,
  }) = _GoalFrequency;

  factory GoalFrequency.fromJson(Map<String, dynamic> json) =>
      _$GoalFrequencyFromJson(json);
}

@freezed
abstract class GoalProgress with _$GoalProgress {
  const factory GoalProgress({
    int? goalId,
    @Default(0) int targetCount,
    @Default(0) int doneCount,
    @Default(0.0) double achievementRate,
    @Default(0) int currentWeekDone,
    @Default(0) int currentWeekTarget,
  }) = _GoalProgress;

  factory GoalProgress.fromJson(Map<String, dynamic> json) =>
      _$GoalProgressFromJson(json);
}

@freezed
abstract class Goal with _$Goal {
  const factory Goal({
    required int goalId,
    required String title,
    @JsonKey(unknownEnumValue: GoalType.unknown)
    @Default(GoalType.unknown)
    GoalType type,
    @JsonKey(unknownEnumValue: GoalStatus.unknown)
    @Default(GoalStatus.unknown)
    GoalStatus status,
    @Default(GoalProgress()) GoalProgress progress,
    /// #RRGGBB. 서버가 형식을 검증한다.
    String? color,
    GoalFrequency? frequency,
    int? durationWeeks,
    String? startDate,
    String? endDate,
    int? estimatedMinutes,
    DateTime? createdAt,
  }) = _Goal;

  factory Goal.fromJson(Map<String, dynamic> json) => _$GoalFromJson(json);
}
