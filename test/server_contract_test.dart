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
import 'package:p2j_mobile/features/ai/data/load_check_models.dart';
import 'package:p2j_mobile/features/group/data/group_api.dart';
import 'package:p2j_mobile/features/group/data/group_models.dart';
import 'package:p2j_mobile/features/stats/data/stats_api.dart';
import 'package:p2j_mobile/features/stats/data/stats_models.dart';
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
late StatsApi stats;
late GroupApi groupApi;

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
    stats = StatsApi(authed);
    groupApi = GroupApi(authed);
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

  group('stats', () {
    test('summary: 주간은 7칸, 범위의 끝이 오늘', () async {
      if (skipIfNoServer()) return;
      final summary = await stats.fetchSummary();
      expect(summary.period, StatsPeriod.week);
      expect(summary.byDay, hasLength(7));
      expect(summary.range.toDate, today);
      expect(summary.byDay.last.date, today);
      // 새 계정이라 완료 기록이 없다. 연속은 0 이어야 한다.
      expect(summary.currentStreak, 0);
    });

    test('summary: 월간은 30칸', () async {
      if (skipIfNoServer()) return;
      final summary = await stats.fetchSummary(period: StatsPeriod.month);
      expect(summary.byDay, hasLength(30));
      expect(summary.period, StatsPeriod.month);
    });

    test('완료하면 집계에 바로 반영된다', () async {
      if (skipIfNoServer()) return;
      final before = await stats.fetchSummary();
      final todo = await todos.create(title: '통계 확인용', estimatedMinutes: 20);
      await todos.complete(todo.todoId, actualMinutes: 25);

      final after = await stats.fetchSummary();
      expect(after.completedTodos, before.completedTodos + 1);
      expect(after.totalActualMinutes, before.totalActualMinutes + 25);
      expect(after.byHour, isNotEmpty);

      await todos.delete(todo.todoId);
    });

    test('없는 목표는 GOAL_NOT_FOUND', () async {
      if (skipIfNoServer()) return;
      await expectLater(
        stats.fetchGoal(99999999),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', ApiErrorCode.goalNotFound),
        ),
      );
    });
  });

  group('load-check', () {
    test('기록이 없으면 ok + message null', () async {
      if (skipIfNoServer()) return;
      final check = await ai.fetchLoadCheck();
      expect(check.checkId, startsWith('chk_'));
      expect(check.level, LoadCheckLevel.ok);
      expect(check.message, isNull);
      expect(check.shouldShow, isFalse);
      expect(check.evidence.windowDays, 14);
      expect(check.evidence.heavyTaskThresholdMinutes, 60);
    });

    test('하루 한 번만 계산된다', () async {
      if (skipIfNoServer()) return;
      final first = await ai.fetchLoadCheck();
      final second = await ai.fetchLoadCheck();
      expect(second.checkId, first.checkId);
    });

    test('응답을 기록한다', () async {
      if (skipIfNoServer()) return;
      final check = await ai.fetchLoadCheck();
      final answered = await ai.respondLoadCheck(check.checkId, accepted: false);
      expect(answered.accepted, isFalse);
      expect(answered.respondedAt, isNotNull);
    });
  });

  group('groups', () {
    late Group group;
    late int declarationItemId;

    test('생성: 정원과 초대 코드가 함께 온다', () async {
      if (skipIfNoServer()) return;
      group = await groupApi.create(name: '계약테스트 조', maxMembers: 4);
      expect(group.memberCount, 1);
      expect(group.maxMembers, 4);
      expect(group.myRole, MemberRole.owner);
      expect(group.inviteCode, startsWith('P2J-'));
    });

    test('정원 밖 값은 VALIDATION_ERROR', () async {
      if (skipIfNoServer()) return;
      await expectLater(
        groupApi.create(name: '너무 큰 조', maxMembers: 9),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', ApiErrorCode.validationError),
        ),
      );
    });

    test('목록에 미확인 수와 마지막 활동이 있다', () async {
      if (skipIfNoServer()) return;
      final mine = await groupApi.fetchMyGroups();
      final found = mine.firstWhere((g) => g.groupId == group.groupId);
      expect(found.unreadCount, 0);
      expect(found.lastActivityAt, isNull);
    });

    test('잘못된 초대 코드는 INVALID_INVITE_CODE', () async {
      if (skipIfNoServer()) return;
      await expectLater(
        groupApi.join('P2J-ZZZZ'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', ApiErrorCode.invalidInviteCode),
        ),
      );
    });

    test('코드를 재발급하면 이전 코드가 바뀐다', () async {
      if (skipIfNoServer()) return;
      final invite = await groupApi.issueInvite(group.groupId);
      expect(invite.inviteCode, startsWith('P2J-'));
      expect(invite.inviteCode, isNot(group.inviteCode));
      expect(invite.expiresAt, isNotNull);
    });

    test('선언하면 잠기고 투두 수정이 막힌다', () async {
      if (skipIfNoServer()) return;
      final todo = await todos.create(title: '선언할 일', estimatedMinutes: 30);
      final declaration = await groupApi.declare(
        group.groupId,
        todoIds: [todo.todoId],
      );
      expect(declaration.items, hasLength(1));
      expect(declaration.items.first.title, '선언할 일');
      expect(declaration.items.first.status, DeclarationItemStatus.pending);
      expect(declaration.lockedAt, isNotNull);
      declarationItemId = declaration.items.first.declarationItemId;

      await expectLater(
        todos.update(todo.todoId, title: '몰래 바꾸기'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', ApiErrorCode.declaredTodoLocked),
        ),
      );

      // 완료 체크는 잠금과 무관하게 열려 있어야 한다.
      await todos.complete(todo.todoId);
    });

    test('같은 날 두 번 선언하면 409', () async {
      if (skipIfNoServer()) return;
      final todo = await todos.create(title: '두 번째 선언 시도');
      await expectLater(
        groupApi.declare(group.groupId, todoIds: [todo.todoId]),
        throwsA(
          isA<ApiException>().having(
            (e) => e.code,
            'code',
            ApiErrorCode.declarationAlreadyExists,
          ),
        ),
      );
      await todos.delete(todo.todoId);
    });

    test('선언 현황에 미선언 구성원도 들어간다', () async {
      if (skipIfNoServer()) return;
      final rows = await groupApi.fetchDeclarations(group.groupId);
      expect(rows, hasLength(1)); // 혼자인 그룹
      expect(rows.first.declared, isTrue);
      expect(rows.first.doneCount, 1);
      expect(rows.first.achievementRate, 1.0);
    });

    test('완료한 항목에 인증샷을 올린다', () async {
      if (skipIfNoServer()) return;
      final proof = await groupApi.createProof(
        group.groupId,
        declarationItemId: declarationItemId,
        fileKey: 'proofs/contract/test.jpg',
        caption: '계약 테스트',
      );
      expect(proof.caption, '계약 테스트');
      expect(proof.commentCount, 0);
      expect(proof.reactions, isEmpty);

      // 1항목 1인증
      await expectLater(
        groupApi.createProof(
          group.groupId,
          declarationItemId: declarationItemId,
          fileKey: 'proofs/contract/again.jpg',
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', ApiErrorCode.proofAlreadyExists),
        ),
      );
    });

    test('피드는 사용자별로 묶이고 못 한 것을 함께 준다', () async {
      if (skipIfNoServer()) return;
      final page = await groupApi.fetchFeed(group.groupId);
      expect(page.items, hasLength(1));
      final entry = page.items.first;
      expect(entry.declaredCount, 1);
      expect(entry.doneCount, 1);
      expect(entry.posts, hasLength(1));
      expect(entry.missedItems, isEmpty);
      expect(entry.posts.first.user?.nickname, '계약테스트');
    });

    test('댓글과 리액션', () async {
      if (skipIfNoServer()) return;
      final page = await groupApi.fetchFeed(group.groupId);
      final postId = page.items.first.posts.first.postId;

      final comment = await groupApi.addComment(postId, '고생했다');
      expect(comment.content, '고생했다');

      final comments = await groupApi.fetchComments(postId);
      expect(comments.items, hasLength(1));

      var tally = await groupApi.setReaction(postId, ReactionType.fire);
      expect(tally.reactions['fire'], 1);
      expect(tally.myReaction, 'fire');

      // 다시 부르면 누적이 아니라 교체다.
      tally = await groupApi.setReaction(postId, ReactionType.clap);
      expect(tally.reactions.containsKey('fire'), isFalse);
      expect(tally.reactions['clap'], 1);

      await groupApi.clearReaction(postId);
      final post = await groupApi.fetchPost(postId);
      expect(post.reactions, isEmpty);
      expect(post.myReaction, isNull);
      expect(post.commentCount, 1);

      await groupApi.deleteComment(comment.commentId);
    });

    test('순위: 달력 주 기준, 나도 목록에 있다', () async {
      if (skipIfNoServer()) return;
      final ranking = await groupApi.fetchRanking(group.groupId);
      expect(ranking.period, RankingPeriod.week);
      expect(ranking.rankings, hasLength(1));
      expect(ranking.rankings.first.rank, 1);
      expect(ranking.rankings.first.achievementRate, 1.0);
      expect(ranking.myRank, 1);
      expect(ranking.range.fromDate, isNotNull);
    });

    test('그룹 스트릭: 혼자 다 끝냈으면 오늘은 success', () async {
      if (skipIfNoServer()) return;
      final streak = await groupApi.fetchStreak(group.groupId);
      expect(streak.todayStatus, GroupStreakStatus.success);
      expect(streak.membersTotal, 1);
      expect(streak.declaredMembersToday, 1);
      expect(streak.membersCompletedToday, 1);
    });

    test('마지막 한 명은 그냥 나갈 수 있다', () async {
      if (skipIfNoServer()) return;
      await groupApi.leave(group.groupId);
      final mine = await groupApi.fetchMyGroups();
      expect(mine.any((g) => g.groupId == group.groupId), isFalse);
    });
  });

  group('uploads', () {
    test('스토리지 미설정이면 503 STORAGE_UNAVAILABLE', () async {
      if (skipIfNoServer()) return;
      final client = clientWith(accessToken: accessToken);
      await expectLater(
        client.post(
          '/uploads/presign',
          data: <String, dynamic>{
            'content_type': 'image/jpeg',
            'purpose': 'proof',
          },
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', ApiErrorCode.storageUnavailable),
        ),
      );
    });
  });
}
