import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/dio_client.dart';
import 'ai_api.dart';
import 'ai_models.dart';
import 'load_check_models.dart';

part 'ai_repository.g.dart';

/// AI 파싱 저장소. 테스트에서 가짜 구현으로 갈아끼울 수 있게 인터페이스를 분리한다.
abstract interface class AiRepository {
  Future<AiParseResult> parse({
    required String text,
    String? referenceDate,
    List<int>? goalIds,
  });

  Future<AiQuota> fetchQuota();

  /// 오늘 계획이 평소보다 많은지. 하루 한 번 계산된 결과가 온다.
  Future<LoadCheck> fetchLoadCheck({String? date});

  /// 안내 수락 여부 기록. 실제 미루기는 TodoRepository 가 한다.
  Future<LoadCheck> respondLoadCheck(
    String checkId, {
    required bool accepted,
    List<int> appliedTodoIds,
  });
}

class AiRepositoryImpl implements AiRepository {
  const AiRepositoryImpl(this._api);

  final AiApi _api;

  @override
  Future<AiParseResult> parse({
    required String text,
    String? referenceDate,
    List<int>? goalIds,
  }) =>
      _api.parse(text: text, referenceDate: referenceDate, goalIds: goalIds);

  @override
  Future<AiQuota> fetchQuota() => _api.fetchQuota();

  @override
  Future<LoadCheck> fetchLoadCheck({String? date}) =>
      _api.fetchLoadCheck(date: date);

  @override
  Future<LoadCheck> respondLoadCheck(
    String checkId, {
    required bool accepted,
    List<int> appliedTodoIds = const <int>[],
  }) =>
      _api.respondLoadCheck(
        checkId,
        accepted: accepted,
        appliedTodoIds: appliedTodoIds,
      );
}

@Riverpod(keepAlive: true)
AiRepository aiRepository(Ref ref) =>
    AiRepositoryImpl(AiApi(ref.watch(apiClientProvider)));
