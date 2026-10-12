import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../auth/presentation/auth_controller.dart';
import '../data/todo_models.dart';
import '../../goal/presentation/goal_provider.dart';
import '../../group/presentation/group_provider.dart';
import '../data/todo_repository.dart';

part 'todo_provider.g.dart';

/// 홈에서 보고 있는 날짜.
///
/// 서버 기준 오늘이 바뀌면(04:00 KST 경계 통과) 선택도 오늘로 되돌아간다.
@Riverpod(keepAlive: true)
class SelectedDate extends _$SelectedDate {
  @override
  String build() => ref.watch(serverTodayProvider) ?? '';

  void select(String date) => state = date;
}

/// 특정 날짜의 투두 목록.
///
/// 완료 토글은 서버 응답을 기다리지 않고 즉시 반영한다. 체크박스가 0.5초
/// 멈춰 있으면 앱이 느리게 느껴진다. 실패하면 되돌리고 예외를 다시 던져서
/// 화면이 스낵바를 띄우게 한다.
@riverpod
class DayTodosController extends _$DayTodosController {
  @override
  Future<DayTodos> build(String date) =>
      ref.watch(todoRepositoryProvider).fetchDay(date);

  Future<void> toggle(Todo todo) async {
    final snapshot = state.value;
    if (snapshot == null) return;

    final willComplete = !todo.status.isDone;
    state = AsyncData(
      _recount(
        snapshot,
        snapshot.items
            .map(
              (e) => e.todoId == todo.todoId
                  ? e.copyWith(
                      status: willComplete
                          ? TodoStatus.done
                          : TodoStatus.pending,
                      rawStatus: willComplete ? 'done' : 'pending',
                    )
                  : e,
            )
            .toList(),
      ),
    );
    _syncWeek();

    try {
      if (willComplete) {
        // 응답에 목표 진행률(goal_progress)과 연속 기록(personal_streak)도 함께 온다.
        // 이 화면은 아직 쓰지 않지만, 목표 카드를 붙일 때 여기서 꺼내 쓰면 된다.
        final updated =
            (await ref.read(todoRepositoryProvider).complete(todo.todoId)).todo;
        final current = state.value;
        if (current == null) return;
        state = AsyncData(
          current.copyWith(
            items: current.items
                .map((e) => e.todoId == updated.todoId ? updated : e)
                .toList(),
          ),
        );
      } else {
        // 204 라 응답 바디가 없다. summary 는 로컬에서 이미 다시 셌다.
        await ref.read(todoRepositoryProvider).uncomplete(todo.todoId);
      }
      // 선언한 항목을 체크하면 그룹의 달성률·연속 기록이 같이 움직인다.
      // 하단 탭은 IndexedStack 이라 살아 있으므로 여기서 비워 주지 않으면 낡는다.
      for (final link in todo.declarations) {
        invalidateGroupFrom(ref, link.groupId);
      }
    } catch (_) {
      state = AsyncData(snapshot);
      _syncWeek();
      rethrow;
    }
  }

  Future<void> add({required String title, int? estimatedMinutes}) async {
    final created = await ref
        .read(todoRepositoryProvider)
        .create(title: title, date: date, estimatedMinutes: estimatedMinutes);
    final snapshot = state.value;
    if (snapshot == null) return;
    state = AsyncData(_recount(snapshot, [...snapshot.items, created]));
    _syncWeek();
  }

  /// 목표를 갈아끼운다. [goalId] 가 null 이면 뗀다.
  ///
  /// 선언한 항목은 서버가 422 DECLARED_TODO_LOCKED 로 막는다. 화면에서 먼저
  /// 걸러 내지만, 두 사람이 동시에 만졌을 때를 대비해 여기서도 그대로 던진다.
  Future<void> changeGoal(Todo todo, int? goalId) async {
    final updated = await ref
        .read(todoRepositoryProvider)
        .update(todo.todoId, goalId: goalId, clearGoal: goalId == null);
    final snapshot = state.value;
    if (snapshot == null) return;
    state = AsyncData(
      snapshot.copyWith(
        items: snapshot.items
            .map((e) => e.todoId == updated.todoId ? updated : e)
            .toList(),
      ),
    );
    // 양쪽 목표의 진행률이 모두 바뀐다 (뗀 쪽과 붙인 쪽).
    ref.invalidate(activeGoalsProvider);
  }

  /// AI 초안을 한 번에 저장한다. 서버가 전부 만들거나 전부 만들지 않는다.
  ///
  /// AI 가 다른 날짜로 잡은 초안도 함께 저장되므로, 이 목록에는 보고 있는
  /// 날짜의 것만 넣는다. 나머지는 주간 스트립을 다시 불러 반영한다.
  Future<int> addMany(List<TodoDraftInput> items, {String? parseId}) async {
    final result = await ref
        .read(todoRepositoryProvider)
        .createBulk(items: items, parseId: parseId);
    final snapshot = state.value;
    if (snapshot != null) {
      final forThisDay = result.items
          .where((todo) => todo.date == date)
          .toList();
      state = AsyncData(_recount(snapshot, [...snapshot.items, ...forThisDay]));
    }
    _syncWeek();
    return result.createdCount;
  }

  Future<void> rename(Todo todo, String title) async {
    final updated = await ref
        .read(todoRepositoryProvider)
        .updateTitle(todo.todoId, title);
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        items: [
          for (final item in current.items)
            if (item.todoId == todo.todoId)
              item.copyWith(title: updated.title)
            else
              item,
        ],
      ),
    );
  }

  Future<void> remove(Todo todo) async {
    final snapshot = state.value;
    if (snapshot == null) return;

    state = AsyncData(
      _recount(
        snapshot,
        snapshot.items.where((e) => e.todoId != todo.todoId).toList(),
      ),
    );
    _syncWeek();

    try {
      await ref.read(todoRepositoryProvider).delete(todo.todoId);
    } catch (_) {
      state = AsyncData(snapshot);
      _syncWeek();
      rethrow;
    }
  }

  /// 목록이 바뀌면 summary 를 로컬에서 다시 센다.
  /// 서버 조회 결과의 summary 는 그대로 믿고, 낙관적 변경분만 여기서 반영한다.
  DayTodos _recount(DayTodos source, List<Todo> items) {
    final total = items.length;
    final done = items.where((e) => e.status.isDone).length;
    return source.copyWith(
      items: items,
      summary: source.summary.copyWith(
        total: total,
        done: done,
        achievementRate: total == 0 ? 0 : done / total,
        totalEstimatedMinutes: items.fold<int>(
          0,
          (sum, e) => sum + (e.estimatedMinutes ?? 0),
        ),
      ),
    );
  }

  /// 7일 스트립의 해당 칸도 같이 맞춘다. 재조회하면 스트립이 깜빡인다.
  void _syncWeek() {
    final summary = state.value?.summary;
    if (summary == null) return;
    ref
        .read(weekAchievementsProvider.notifier)
        .patch(date, total: summary.total, done: summary.done);
  }
}

/// 7일 달성률 스트립.
///
/// start_date 를 보내지 않으면 서버가 오늘-6일부터 7행을 항상 채워서 준다.
/// 빈 날짜를 클라이언트가 계산해 채우지 않는다.
@Riverpod(keepAlive: true)
class WeekAchievements extends _$WeekAchievements {
  @override
  Future<List<DayAchievement>> build() {
    // 오늘이 바뀌면 스트립도 다시 불러온다.
    ref.watch(serverTodayProvider);
    return ref.watch(todoRepositoryProvider).fetchWeek();
  }

  void patch(String date, {required int total, required int done}) {
    final days = state.value;
    if (days == null) return;
    state = AsyncData([
      for (final day in days)
        if (day.date == date)
          day.copyWith(
            total: total,
            done: done,
            achievementRate: total == 0 ? 0 : done / total,
          )
        else
          day,
    ]);
  }
}
