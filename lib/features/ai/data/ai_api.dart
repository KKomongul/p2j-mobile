import '../../../core/network/api_response.dart';
import '../../../core/network/dio_client.dart';
import 'ai_models.dart';
import 'load_check_models.dart';

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

  /// 오늘 계획이 평소 소화량을 넘는지. `GET /ai/load-check?date=`
  ///
  /// **집계 기반이라 LLM 을 쓰지 않는다.** 실패해도 429·503 이 오지 않는다.
  /// 하루 한 번만 계산되고, 같은 날 다시 부르면 저장된 결과가 그대로 온다.
  Future<LoadCheck> fetchLoadCheck({String? date}) async {
    final response = await _client.get(
      '/ai/load-check',
      query: <String, dynamic>{if (date != null) 'date': date},
    );
    return ApiResponse.object(response, LoadCheck.fromJson).data;
  }

  /// 안내를 받아들였는지 기록. `POST /ai/load-check/{check_id}/response`
  ///
  /// 실제로 미루는 건 `TodoApi.postpone` 이 한다. 여기는 결과만 남긴다 —
  /// 수락률이 다음 판정의 근거가 된다.
  Future<LoadCheck> respondLoadCheck(
    String checkId, {
    required bool accepted,
    List<int> appliedTodoIds = const <int>[],
  }) async {
    final response = await _client.post(
      '/ai/load-check/$checkId/response',
      data: <String, dynamic>{
        'accepted': accepted,
        'applied_todo_ids': appliedTodoIds,
      },
    );
    return ApiResponse.object(response, LoadCheck.fromJson).data;
  }
}
