/// 실서버 계약 테스트.
///
/// 모바일이 실제로 쓰는 Api 클래스(AuthApi · GoalApi · TodoApi · AiApi)로
/// 돌고 있는 p2j-server 를 직접 호출한다. Mock 이 아니라 진짜 응답을 파싱한다.
///
/// 서버가 안 떠 있으면 전부 건너뛴다. 서버 없이도 `flutter test` 는 통과해야 한다.
///
///     # p2j-server 에서
///     .venv/Scripts/python -m uvicorn app.main:app --port 8000
///     # p2j-mobile 에서
///     flutter test test/server_contract_test.dart
///
/// 서버 주소를 바꾸려면:
///     flutter test --dart-define=CONTRACT_BASE_URL=http://192.168.0.10:8000/v1
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p2j_mobile/core/network/api_exception.dart';
import 'package:p2j_mobile/core/network/dio_client.dart';
import 'package:p2j_mobile/features/ai/data/ai_api.dart';
import 'package:p2j_mobile/features/ai/data/ai_models.dart';
import 'package:p2j_mobile/features/auth/data/auth_api.dart';
import 'package:p2j_mobile/features/goal/data/goal_api.dart';
import 'package:p2j_mobile/features/goal/data/goal_models.dart';
import 'package:p2j_mobile/features/todo/data/todo_api.dart';
import 'package:p2j_mobile/features/todo/data/todo_models.dart';

const String baseUrl = String.fromEnvironment(
  'CONTRACT_BASE_URL',
  defaultValue: 'http://127.0.0.1:8000/v1',
);

bool serverUp = false;
late String accessToken;
late String today;
late TodoApi todos;
late GoalApi goals;
late AiApi ai;

/// 인터셉터 없이 최소 구성만 쓴다. TokenStorage(플랫폼 채널)를 피하기 위해서다.
ApiClient clientWith({String? accessToken}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
      validateStatus: (s) => s != null && s >= 200 && s < 300,
      headers: accessToken == null
          ? null
          : <String, dynamic>{'Authorization': 'Bearer $accessToken'},
    ),
  );
  return ApiClient(dio);
}

Future<bool> _reachable() async {
  final uri = Uri.parse(baseUrl);
  try {
    final socket = await Socket.connect(
      uri.host,
      uri.port,
      timeout: const Duration(seconds: 2),
    );
    socket.destroy();
    return true;
  } on SocketException {
    return false;
  }
}

/// 서버가 없으면 통과가 아니라 skip 으로 남긴다. 조용히 초록이 되면 안 된다.
bool skipIfNoServer() {
  if (serverUp) return false;
  markTestSkipped('p2j-server 가 $baseUrl 에 없어 건너뜁니다.');
  return true;
}

void main() {
  setUpAll(() async {
    serverUp = await _reachable();
    if (!serverUp) return;

    // 매 실행마다 새 계정을 만든다. 앞선 실행의 데이터에 기대지 않는다.
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final session = await AuthApi(clientWith()).signup(
      email: 'flutter-contract-$stamp@p2j.dev',
      password: 'testpass123',
      nickname: '계약테스트',
    );
    accessToken = session.accessToken;
    today = session.user.today;

    final authed = clientWith(accessToken: accessToken);
    todos = TodoApi(authed);
    goals = GoalApi(authed);
    ai = AiApi(authed);
  });

  group('auth', () {
    test('signup 응답이 AuthSession 으로 파싱된다', () async {
      if (skipIfNoServer()) return;
      expect(accessToken, isNotEmpty);
      expect(today, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    });

    test('GET /auth/me 의 today 가 가입 응답과 같다', () async {
      if (skipIfNoServer()) return;
      final me = await AuthApi(clientWith(accessToken: accessToken)).fetchMe();
      expect(me.today, today);
      expect(me.nickname, '계약테스트');
    });

    test('틀린 계정은 INVALID_CREDENTIALS 로 온다', () async {
      if (skipIfNoServer()) return;
      await expectLater(
        AuthApi(clientWith())
            .login(email: 'nobody@p2j.dev', password: 'nope123456'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.code,
            'code',
            ApiErrorCode.invalidCredentials,
          ),
        ),
      );
    });
  });

  group('goals', () {
    late int goalId;

    test('생성: 반복 목표', () async {
      if (skipIfNoServer()) return;
      final goal = await goals.create(
        title: '주 3회 운동하기',
        type: GoalType.recurring,
        frequency: const GoalFrequency(times: 3, per: FrequencyPer.week),
        durationWeeks: 4,
        estimatedMinutes: 60,
        color: '#F2C55C',
      );
      goalId = goal.goalId;

      expect(goal.type, GoalType.recurring);
      expect(goal.status, GoalStatus.active);
      expect(goal.color, '#F2C55C');
      expect(goal.frequency?.times, 3);
      expect(goal.frequency?.per, FrequencyPer.week);
      expect(goal.progress.targetCount, 12); // 3회 × 4주
      expect(goal.endDate, isNotNull);
    });

    test('목록: status 필터와 page 정보', () async {
      if (skipIfNoServer()) return;
      final page = await goals.fetchPage(status: GoalStatus.active);
      expect(page.items.map((g) => g.goalId), contains(goalId));
      expect(page.hasNext, isFalse);
    });

    test('상세', () async {
      if (skipIfNoServer()) return;
      final goal = await goals.fetchOne(goalId);
      expect(goal.title, '주 3회 운동하기');
    });

    test('수정: 제목과 소요시간', () async {
      if (skipIfNoServer()) return;
      final goal = await goals.update(
        goalId,
        title: '주 3회 헬스',
        estimatedMinutes: 45,
      );
      expect(goal.title, '주 3회 헬스');
      expect(goal.estimatedMinutes, 45);
    });

    test('보관하면 목록에서 내려간다', () async {
      if (skipIfNoServer()) return;
      final goal = await goals.archive(goalId);
      expect(goal.status, GoalStatus.archived);

      final active = await goals.fetchPage(status: GoalStatus.active);
      expect(active.items.map((g) => g.goalId), isNot(contains(goalId)));

      final archived = await goals.fetchPage(status: GoalStatus.archived);
      expect(archived.items.map((g) => g.goalId), contains(goalId));
    });

    test('없는 목표는 GOAL_NOT_FOUND', () async {
      if (skipIfNoServer()) return;
      await expectLater(
        goals.fetchOne(999999),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', ApiErrorCode.goalNotFound),
        ),
      );
    });

    test('삭제', () async {
      if (skipIfNoServer()) return;
      await goals.delete(goalId);
      await expectLater(goals.fetchOne(goalId), throwsA(isA<ApiException>()));
    });
  });

  group('todos', () {
    late int todoId;
    late int linkedGoalId;

    test('생성: 목표를 붙이면 goal_title 이 조인돼 온다', () async {
      if (skipIfNoServer()) return;
      linkedGoalId = (await goals.create(title: '알고리즘 문제 풀기')).goalId;

      final todo = await todos.create(
        title: '백준 실버 2문제',
        date: today,
        estimatedMinutes: 45,
        goalId: linkedGoalId,
        memo: '오전에',
      );
      todoId = todo.todoId;

      expect(todo.goalTitle, '알고리즘 문제 풀기');
      expect(todo.status, TodoStatus.pending);
      expect(todo.source, TodoSource.manual);
      expect(todo.memo, '오전에');
      expect(todo.postponeCount, 0);
      expect(todo.isDeclared, isFalse);
    });

    test('상세', () async {
      if (skipIfNoServer()) return;
      final todo = await todos.fetchOne(todoId);
      expect(todo.title, '백준 실버 2문제');
    });

    test('부분 수정: 보낸 필드만 바뀐다', () async {
      if (skipIfNoServer()) return;
      final todo = await todos.update(todoId, title: '백준 골드 1문제');
      expect(todo.title, '백준 골드 1문제');
      expect(todo.estimatedMinutes, 45); // 안 보낸 필드는 그대로
      expect(todo.memo, '오전에');
    });

    test('clearMemo 로 메모를 지운다', () async {
      if (skipIfNoServer()) return;
      final todo = await todos.update(todoId, clearMemo: true);
      expect(todo.memo, isNull);
    });

    test('미루기: 날짜가 옮겨지고 postpone_count 가 오른다', () async {
      if (skipIfNoServer()) return;
      final todo = await todos.postpone(todoId);
      expect(todo.postponeCount, 1);
      expect(todo.date, isNot(today));

      // 오늘로 되돌린다. 뒤 테스트가 오늘 기준으로 센다.
      final back = await todos.update(todoId, date: today);
      expect(back.date, today);
    });

    test('완료: goal_progress 와 personal_streak 이 함께 온다', () async {
      if (skipIfNoServer()) return;
      final result = await todos.complete(todoId, actualMinutes: 60);
      expect(result.todo.status, TodoStatus.done);
      expect(result.todo.actualMinutes, 60);
      expect(result.todo.completedAt, isNotNull);
      expect(result.goalProgress, isNotNull);
      expect(result.goalProgress!.goalId, linkedGoalId);
      expect(result.goalProgress!.doneCount, 1);
      expect(result.personalStreak, isA<int>());
    });

    test('하루 목록의 summary 는 서버가 계산한다', () async {
      if (skipIfNoServer()) return;
      final day = await todos.fetchDay(today);
      expect(day.date, today);
      expect(day.summary.total, day.items.length);
      expect(day.summary.done, day.items.where((t) => t.status.isDone).length);
    });

    test('완료 취소는 204 라 본문이 없다', () async {
      if (skipIfNoServer()) return;
      await todos.uncomplete(todoId);
      final todo = await todos.fetchOne(todoId);
      expect(todo.status, TodoStatus.pending);
      expect(todo.completedAt, isNull);
    });

    test('7일 스트립은 7칸이고 마지막이 오늘', () async {
      if (skipIfNoServer()) return;
      final week = await todos.fetchWeek();
      expect(week, hasLength(7));
      expect(week.last.date, today);
    });

    test('bulk: 여러 건을 한 번에 저장한다', () async {
      if (skipIfNoServer()) return;
      final result = await todos.createBulk(
        parseId: 'prs_contract',
        items: <TodoDraftInput>[
          TodoDraftInput(title: '초안 1', date: today, estimatedMinutes: 20),
          TodoDraftInput(title: '초안 2', date: today),
        ],
      );
      expect(result.createdCount, 2);
      expect(result.items, hasLength(2));
      expect(result.items.first.source, TodoSource.aiSuggested);
    });

    test('빈 제목은 VALIDATION_ERROR + details.title', () async {
      if (skipIfNoServer()) return;
      await expectLater(
        todos.create(title: '   ', date: today),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', ApiErrorCode.validationError)
              .having(
                (e) => e.fieldMessage('title'),
                'details.title',
                isNotNull,
              ),
        ),
      );
    });

    test('삭제 후 조회는 TODO_NOT_FOUND', () async {
      if (skipIfNoServer()) return;
      await todos.delete(todoId);
      await expectLater(
        todos.fetchOne(todoId),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', ApiErrorCode.todoNotFound),
        ),
      );
    });
  });

  group('ai', () {
    test('GET /ai/quota', () async {
      if (skipIfNoServer()) return;
      final quota = await ai.fetchQuota();
      expect(quota.limitPerDay, greaterThan(0));
      expect(quota.remainingToday, lessThanOrEqualTo(quota.limitPerDay));
    });

    test('POST /ai/parse 는 초안만 주고 아무것도 저장하지 않는다', () async {
      if (skipIfNoServer()) return;
      final before = await todos.fetchDay(today);

      final result = await ai.parse(
        text: '내일까지 발표 자료 만들어야 해',
        referenceDate: today,
      );
      expect(result.parseId, isNotEmpty);
      expect(result.parseMethod, isNot(ParseMethod.unknown));
      expect(result.drafts, isNotEmpty);
      expect(result.drafts.first.title, isNotEmpty);

      final after = await todos.fetchDay(today);
      expect(after.items.length, before.items.length);
    });
  });
}
