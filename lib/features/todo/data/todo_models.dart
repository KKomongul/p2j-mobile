import 'package:freezed_annotation/freezed_annotation.dart';

import '../../goal/data/goal_models.dart';

part 'todo_models.freezed.dart';
part 'todo_models.g.dart';

/// 투두 상태.
///
/// 서버가 나중에 값을 추가할 수 있으므로 [unknown] 폴백을 둔다.
/// deferred/skipped 는 이 UI 가 만들지 않지만 렌더링은 해야 한다.
enum TodoStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('done')
  done,
  @JsonValue('deferred')
  deferred,
  @JsonValue('skipped')
  skipped,
  unknown,
}

enum TodoSource {
  @JsonValue('ai_suggested')
  aiSuggested,
  @JsonValue('manual')
  manual,
  @JsonValue('auto_scheduled')
  autoScheduled,
  unknown,
}

extension TodoStatusX on TodoStatus {
  bool get isDone => this == TodoStatus.done;

  /// 오늘 손댈 수 없는 상태. 회색으로 죽여서 보여준다.
  bool get isInactive =>
      this == TodoStatus.deferred || this == TodoStatus.skipped;

  /// 배지에 쓸 이름. unknown 은 원문을 그대로 노출해야 하므로 여기서 다루지 않는다.
  String? get badgeLabel => switch (this) {
        TodoStatus.deferred => '미룸',
        TodoStatus.skipped => '건너뜀',
        _ => null,
      };
}

/// 알 수 없는 status 가 와도 원문을 잃지 않도록 문자열 그대로 한 번 더 읽는다.
/// 배지에 원문을 노출해서 조용히 숨기지 않기 위한 것이다.
String _rawStatus(Object? value) => value?.toString() ?? 'unknown';

@freezed
abstract class Todo with _$Todo {
  const factory Todo({
    required int todoId,
    required String title,
    required String date,
    @JsonKey(unknownEnumValue: TodoStatus.unknown)
    @Default(TodoStatus.unknown)
    TodoStatus status,
    @JsonKey(name: 'status', fromJson: _rawStatus, includeToJson: false)
    @Default('unknown')
    String rawStatus,
    @JsonKey(unknownEnumValue: TodoSource.unknown)
    @Default(TodoSource.unknown)
    TodoSource source,
    int? goalId,
    String? goalTitle,
    int? estimatedMinutes,
    int? actualMinutes,
    DateTime? completedAt,
    @Default(0) int order,
    @Default(false) bool isDeclared,
    /// 몇 번 미뤘는지. postpone 을 부를 때마다 서버가 올린다.
    @Default(0) int postponeCount,
    String? memo,
  }) = _Todo;

  factory Todo.fromJson(Map<String, dynamic> json) => _$TodoFromJson(json);
}

@freezed
abstract class TodoSummary with _$TodoSummary {
  const factory TodoSummary({
    @Default(0) int total,
    @Default(0) int done,
    @Default(0.0) double achievementRate,
    @Default(0) int totalEstimatedMinutes,
  }) = _TodoSummary;

  factory TodoSummary.fromJson(Map<String, dynamic> json) =>
      _$TodoSummaryFromJson(json);
}

@freezed
abstract class DayTodos with _$DayTodos {
  const factory DayTodos({
    required String date,
    @Default(<Todo>[]) List<Todo> items,
    @Default(TodoSummary()) TodoSummary summary,
  }) = _DayTodos;

  factory DayTodos.fromJson(Map<String, dynamic> json) =>
      _$DayTodosFromJson(json);
}

/// 7일 스트립 한 칸.
@freezed
abstract class DayAchievement with _$DayAchievement {
  const factory DayAchievement({
    required String date,
    @Default(0) int total,
    @Default(0) int done,
    @Default(0.0) double achievementRate,
  }) = _DayAchievement;

  factory DayAchievement.fromJson(Map<String, dynamic> json) =>
      _$DayAchievementFromJson(json);
}

/// `POST /todos/{id}/complete` 응답.
///
/// 목표에 묶인 할 일을 완료하면 서버가 그 목표의 진행률을 다시 계산해 함께 준다.
/// 목표가 없으면 [goalProgress] 는 null 이다.
///
/// [personalStreak] 은 선언 기능(12주차) 전까지 서버가 항상 0 을 준다.
@freezed
abstract class TodoCompleteResult with _$TodoCompleteResult {
  const factory TodoCompleteResult({
    required Todo todo,
    GoalProgress? goalProgress,
    @Default(0) int personalStreak,
  }) = _TodoCompleteResult;

  factory TodoCompleteResult.fromJson(Map<String, dynamic> json) =>
      _$TodoCompleteResultFromJson(json);
}

/// `POST /todos/bulk` 응답. AI 초안을 확정 저장한 결과다.
///
/// 서버는 하나라도 실패하면 전부 롤백한다. 부분 저장은 없다.
@freezed
abstract class TodoBulkResult with _$TodoBulkResult {
  const factory TodoBulkResult({
    @Default(<Todo>[]) List<Todo> items,
    @Default(0) int createdCount,
  }) = _TodoBulkResult;

  factory TodoBulkResult.fromJson(Map<String, dynamic> json) =>
      _$TodoBulkResultFromJson(json);
}

/// `POST /todos/bulk` 의 항목 하나.
///
/// 응답 모델이 아니라 요청 본문이라 freezed 를 쓰지 않는다.
/// `/ai/parse` 가 준 초안(TodoDraft)을 그대로 옮겨 담는 용도다.
class TodoDraftInput {
  const TodoDraftInput({
    required this.title,
    this.date,
    this.goalId,
    this.estimatedMinutes,
    this.memo,
  });

  final String title;

  /// 생략하면 서버가 04:00 KST 기준 오늘로 채운다.
  final String? date;
  final int? goalId;
  final int? estimatedMinutes;
  final String? memo;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'title': title,
        if (date != null) 'date': date,
        if (goalId != null) 'goal_id': goalId,
        if (estimatedMinutes != null) 'estimated_minutes': estimatedMinutes,
        if (memo != null) 'memo': memo,
      };
}
