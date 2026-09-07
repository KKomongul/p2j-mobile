import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/dio_client.dart';
import 'ai_api.dart';
import 'ai_models.dart';

part 'ai_repository.g.dart';

/// AI 파싱 저장소. 테스트에서 가짜 구현으로 갈아끼울 수 있게 인터페이스를 분리한다.
abstract interface class AiRepository {
  Future<AiParseResult> parse({
    required String text,
    String? referenceDate,
    List<int>? goalIds,
  });

  Future<AiQuota> fetchQuota();
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
}

@Riverpod(keepAlive: true)
AiRepository aiRepository(Ref ref) =>
    AiRepositoryImpl(AiApi(ref.watch(apiClientProvider)));
