import '../../../core/network/api_response.dart';
import '../../../core/network/dio_client.dart';
import 'ai_models.dart';

/// `/v1/ai/*` 호출만 담당한다.
///
/// **여기서는 아무것도 저장되지 않는다.** 사용자가 초안을 확인한 뒤
/// `TodoApi.createBulk` 로 넘겨야 실제 할 일이 생긴다.
class AiApi {
  const AiApi(this._client);

  final ApiClient _client;

  /// 자유 문장 → 할 일 초안. `POST /ai/parse`
  ///
  /// 서버가 3단계로 폴백한다. LLM → 규칙 파서 → 제목만 담긴 초안 1건.
  /// 어느 단계였는지는 응답의 `parse_method` 로 알 수 있다.
  ///
  /// [goalIds] 를 주면 그 목표들만 매칭 후보로 본다. 생략하면 진행 중인 목표 전부.
  /// [referenceDate] 는 "내일", "이번 주" 같은 표현의 기준일이다.
  /// 생략하면 서버가 04:00 KST 기준 오늘을 쓴다.
  ///
  /// 한도를 넘기면 `429 AI_QUOTA_EXCEEDED`, LLM 장애면 `503 AI_UNAVAILABLE` 이 온다.
  /// 둘 다 사용자를 직접 입력 화면으로 보내야 하는 신호다.
  Future<AiParseResult> parse({
    required String text,
    String? referenceDate,
    List<int>? goalIds,
  }) async {
    final response = await _client.post(
      '/ai/parse',
      data: <String, dynamic>{
        'text': text,
        if (referenceDate != null) 'reference_date': referenceDate,
        if (goalIds != null && goalIds.isNotEmpty)
          'context': <String, dynamic>{'goal_ids': goalIds},
      },
    );
    return ApiResponse.object(response, AiParseResult.fromJson).data;
  }

  /// 오늘 남은 호출 수. `GET /ai/quota`
  ///
  /// 음성 입력 버튼을 누르기 전에 미리 보여줄 때 쓴다.
  Future<AiQuota> fetchQuota() async {
    final response = await _client.get('/ai/quota');
    return ApiResponse.object(response, AiQuota.fromJson).data;
  }
}
