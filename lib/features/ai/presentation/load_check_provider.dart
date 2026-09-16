import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_exception.dart';
import '../../todo/data/todo_repository.dart';
import '../data/ai_repository.dart';
import '../data/load_check_models.dart';

part 'load_check_provider.g.dart';

/// 오늘의 계획량 안내.
///
/// 홈 화면이 진입할 때마다 부르지만 서버가 하루 한 번만 계산하므로 부담이 없다.
/// **실패해도 화면을 막지 않는다.** 안내는 있으면 좋은 것이지 필수가 아니다 —
/// 오류를 그대로 던지면 오늘 할 일 목록까지 오류 화면이 된다.
@riverpod
class TodayLoadCheck extends _$TodayLoadCheck {
  @override
  Future<LoadCheck?> build() async {
    try {
      return await ref.watch(aiRepositoryProvider).fetchLoadCheck();
    } on ApiException {
      return null;
    }
  }

  /// 제안대로 미룬다. 실제 미루기는 `/todos/{id}/defer` 가 하고,
  /// 여기서는 그 결과를 안내 기록에 남긴다 (수락률이 다음 판정의 근거가 된다).
  Future<int> acceptSuggestions() async {
    final check = state.value;
    if (check == null || check.suggestions.isEmpty) return 0;

    final todos = ref.read(todoRepositoryProvider);
    final moved = <int>[];
    for (final suggestion in check.suggestions) {
      try {
        await todos.postpone(suggestion.todoId, toDate: suggestion.toDate);
        moved.add(suggestion.todoId);
      } on ApiException {
        // 이미 완료했거나 선언된 항목일 수 있다. 한 건이 막혀도 나머지는 계속한다.
        continue;
      }
    }

    await _record(check.checkId, accepted: moved.isNotEmpty, ids: moved);
    return moved.length;
  }

  /// 안내를 받아들이지 않는다. 배너만 닫고 기록을 남긴다.
  Future<void> dismiss() async {
    final check = state.value;
    if (check == null) return;
    await _record(check.checkId, accepted: false, ids: const <int>[]);
  }

  Future<void> _record(
    String checkId, {
    required bool accepted,
    required List<int> ids,
  }) async {
    try {
      final updated = await ref.read(aiRepositoryProvider).respondLoadCheck(
            checkId,
            accepted: accepted,
            appliedTodoIds: ids,
          );
      state = AsyncData(updated);
    } on ApiException {
      // 기록에 실패해도 배너는 닫는다. 사용자가 이미 결정을 내렸다.
      state = AsyncData(state.value?.copyWith(accepted: accepted));
    }
  }
}
