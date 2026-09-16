import 'package:freezed_annotation/freezed_annotation.dart';

part 'load_check_models.freezed.dart';
part 'load_check_models.g.dart';

/// 계획량 안내의 판정 결과.
///
/// 서버는 **집계 쿼리만으로** 판정한다. LLM 을 쓰지 않으므로 같은 근거에 다른 말이
/// 나오지 않는다. 근거가 얇으면(최근 14일 중 실행 기록 7일 미만) 조용히 [ok] 로 끝낸다.
enum LoadCheckLevel {
  @JsonValue('ok')
  ok,
  @JsonValue('warning')
  warning,
  unknown,
}

/// 조정 제안의 동작. 지금은 미루기 하나뿐이다.
enum LoadSuggestionAction {
  @JsonValue('defer')
  defer,
  unknown,
}

@freezed
abstract class LoadEvidence with _$LoadEvidence {
  const factory LoadEvidence({
    @Default(14) int windowDays,
    @Default(60) int heavyTaskThresholdMinutes,

    /// 최근 창에서 무거운 일을 3개 이상 끝낸 날의 수.
    @JsonKey(name: 'days_with_3plus_heavy') @Default(0) int daysWith3plusHeavy,
    @Default(0) int avgCompletedMinutesPerDay,
    @Default(0) int todayPlannedMinutes,

    /// 근거로 인정된 실행 일수. 7 미만이면 판정하지 않는다.
    @Default(0) int recordDays,
    @Default(0) int todayHeavyCount,
    @Default(0) int todayPlannedCount,
  }) = _LoadEvidence;

  factory LoadEvidence.fromJson(Map<String, dynamic> json) =>
      _$LoadEvidenceFromJson(json);
}

/// "이건 내일로 미루면 어떨까요" 한 줄.
@freezed
abstract class LoadSuggestion with _$LoadSuggestion {
  const factory LoadSuggestion({
    required int todoId,
    @JsonKey(unknownEnumValue: LoadSuggestionAction.unknown)
    @Default(LoadSuggestionAction.unknown)
    LoadSuggestionAction action,
    String? toDate,
    @Default('') String reason,
  }) = _LoadSuggestion;

  factory LoadSuggestion.fromJson(Map<String, dynamic> json) =>
      _$LoadSuggestionFromJson(json);
}

/// `GET /ai/load-check`.
///
/// 하루 한 번만 계산되고 이후 조회는 같은 결과가 온다. 아침에 한 말을 점심에
/// 바꾸지 않기 위한 것이라, 할 일을 더 넣어도 그날 판정은 그대로다.
@freezed
abstract class LoadCheck with _$LoadCheck {
  const factory LoadCheck({
    required String checkId,
    String? date,
    @JsonKey(unknownEnumValue: LoadCheckLevel.unknown)
    @Default(LoadCheckLevel.unknown)
    LoadCheckLevel level,

    /// 안내 문구. 근거가 없으면 null 이다.
    String? message,
    @Default(LoadEvidence()) LoadEvidence evidence,
    @Default(<LoadSuggestion>[]) List<LoadSuggestion> suggestions,

    /// 사용자가 받아들였는지. 아직 응답 전이면 null.
    bool? accepted,
    @Default(<int>[]) List<int> appliedTodoIds,
    DateTime? respondedAt,
  }) = _LoadCheck;

  factory LoadCheck.fromJson(Map<String, dynamic> json) =>
      _$LoadCheckFromJson(json);
}

extension LoadCheckX on LoadCheck {
  /// 화면에 띄울 안내가 실제로 있는지.
  bool get shouldShow =>
      level == LoadCheckLevel.warning &&
      (message?.isNotEmpty ?? false) &&
      accepted == null;
}
