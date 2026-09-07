import 'package:freezed_annotation/freezed_annotation.dart';

part 'ai_models.freezed.dart';
part 'ai_models.g.dart';

/// 서버가 초안을 어떻게 만들었는지.
///
/// 3단계 폴백의 결과다. LLM 이 죽거나 한도를 넘기면 [rules] 로 내려오고,
/// 규칙 파서도 못 잡으면 [none] 으로 제목만 담긴 초안 하나가 온다.
enum ParseMethod {
  @JsonValue('llm')
  llm,
  @JsonValue('rules')
  rules,
  @JsonValue('none')
  none,
  unknown,
}

extension ParseMethodX on ParseMethod {
  /// 사용자에게 "AI 가 정리했다"고 말해도 되는 경우.
  bool get isAiGenerated => this == ParseMethod.llm;

  /// 사용자가 손볼 것을 전제로 보여줘야 하는 경우.
  bool get needsReview => this != ParseMethod.llm;
}

enum TimeHint {
  @JsonValue('morning')
  morning,
  @JsonValue('afternoon')
  afternoon,
  @JsonValue('evening')
  evening,
  unknown,
}

extension TimeHintX on TimeHint {
  String? get label => switch (this) {
        TimeHint.morning => '오전',
        TimeHint.afternoon => '오후',
        TimeHint.evening => '저녁',
        TimeHint.unknown => null,
      };
}

/// 아직 저장되지 않은 할 일 초안.
///
/// **서버는 `/ai/parse` 단계에서 아무것도 저장하지 않는다.**
/// 사용자가 확인한 뒤 `POST /todos/bulk` 로 넘겨야 실제로 생긴다.
@freezed
abstract class TodoDraft with _$TodoDraft {
  const factory TodoDraft({
    required String draftId,
    required String title,
    required String date,
    @JsonKey(unknownEnumValue: TimeHint.unknown) TimeHint? timeHint,
    int? goalId,
    String? goalTitle,
    int? estimatedMinutes,

    /// 0~1. 낮으면 사용자에게 확인을 더 강하게 요구한다.
    @Default(0.5) double confidence,
  }) = _TodoDraft;

  factory TodoDraft.fromJson(Map<String, dynamic> json) =>
      _$TodoDraftFromJson(json);
}

/// 오늘 남은 AI 호출 수.
///
/// `GET /ai/quota` 는 네 필드를 모두 채워 준다.
/// `/ai/parse` 응답 안에 들어 있는 quota 는 remaining_today 와 reset_at 만 온다.
@freezed
abstract class AiQuota with _$AiQuota {
  const factory AiQuota({
    @Default(0) int limitPerDay,
    @Default(0) int usedToday,
    @Default(0) int remainingToday,

    /// 한도가 초기화되는 시각(ISO 8601 +09:00). 서버가 비워 보낼 수 있어 String 으로 둔다.
    String? resetAt,
  }) = _AiQuota;

  factory AiQuota.fromJson(Map<String, dynamic> json) =>
      _$AiQuotaFromJson(json);

  const AiQuota._();

  bool get isExhausted => remainingToday <= 0;
}

/// `POST /ai/parse` 응답.
@freezed
abstract class AiParseResult with _$AiParseResult {
  const factory AiParseResult({
    /// bulk 저장 때 그대로 돌려보낸다. 서버는 저장하지 않는 임시 식별자다.
    required String parseId,
    @JsonKey(unknownEnumValue: ParseMethod.unknown)
    @Default(ParseMethod.unknown)
    ParseMethod parseMethod,
    @Default(<TodoDraft>[]) List<TodoDraft> drafts,

    /// 서버가 붙이는 경고. 예: `quota_exceeded`(일 한도를 넘어 규칙 파서로 처리함).
    @Default(<String>[]) List<String> warnings,
    AiQuota? quota,
  }) = _AiParseResult;

  factory AiParseResult.fromJson(Map<String, dynamic> json) =>
      _$AiParseResultFromJson(json);

  const AiParseResult._();

  /// 일 한도를 넘겨 규칙 파서로 처리된 결과. 정확도가 낮으니 확인을 권해야 한다.
  bool get quotaExceeded => warnings.contains('quota_exceeded');
}
