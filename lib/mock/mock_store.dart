import 'fixture_loader.dart';
import 'mock_scenario.dart';
import 'mock_social.dart';

/// Mock 응답 한 건.
class MockResult {
  const MockResult(this.statusCode, [this.body]);

  factory MockResult.error(
    int statusCode,
    String code,
    String message, {
    Map<String, dynamic> details = const <String, dynamic>{},
  }) {
    return MockResult(statusCode, <String, dynamic>{
      'error': <String, dynamic>{
        'code': code,
        'message': message,
        'details': details,
      },
    });
  }

  final int statusCode;
  final Object? body;

  bool get isError => statusCode >= 400;
}

/// 메모리에 상태를 들고 있는 가짜 서버.
///
/// 매번 고정 JSON 만 뱉으면 UI 검증이 안 된다. 완료 체크가 다음 조회에도
/// 남아야 하고, 추가한 투두가 목록에 보여야 하며, 달성률이 그에 맞게 다시
/// 계산돼야 한다. fixture 는 최초 seed 로만 쓰고 이후 변경은 여기서 처리한다.
class MockStore {
  MockStore._();

  static final MockStore instance = MockStore._();

  bool _initialized = false;
  Future<void>? _initializing;

  late Map<String, dynamic> _user;
  late String _today;

  /// 날짜(YYYY-MM-DD) -> 투두 목록.
  final Map<String, List<Map<String, dynamic>>> _todosByDate =
      <String, List<Map<String, dynamic>>>{};
  final List<Map<String, dynamic>> _goals = <Map<String, dynamic>>[];

  int _nextTodoId = 900;
  int _nextGoalId = 90;
  int _aiUsedToday = 0;
  int _accessTokenSeq = 1;

  /// tokenExpired 시나리오에서 401 을 한 번만 내기 위한 플래그.
  bool _tokenExpiryFired = false;

  /// 통계·계획량 안내·그룹·피드·랭킹. 투두 원본을 그대로 참조한다.
  late final MockSocial _social = MockSocial(
    todosByDate: _todosByDate,
    currentUser: () => _user,
    today: () => _today,
  );

  String get today => _today;

  /// 서버가 판단하는 '오늘'. 하루의 경계는 자정이 아니라 04:00 KST 다.
  static String serverToday() {
    final kst = DateTime.now().toUtc().add(const Duration(hours: 9));
    return FixtureLoader.formatDate(kst.subtract(const Duration(hours: 4)));
  }

  Future<void> ensureInitialized(MockScenario scenario) {
    if (_initialized) return Future<void>.value();
    return _initializing ??= _initialize(scenario);
  }

  Future<void> _initialize(MockScenario scenario) async {
    _today = serverToday();
    final todayDate = FixtureLoader.parseDate(_today);

    final me = await FixtureLoader.loadMap('auth_me.json', today: todayDate);
    _user = Map<String, dynamic>.from(me['data'] as Map);

    if (scenario != MockScenario.emptyTodos) {
      final seed =
          await FixtureLoader.loadMap('todos_seed.json', today: todayDate);
      seed.forEach((date, items) {
        _todosByDate[date] = (items as List<dynamic>)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      });

      final goals =
          await FixtureLoader.loadList('goals_active.json', today: todayDate);
      _goals.addAll(goals.map((e) => Map<String, dynamic>.from(e as Map)));
    }

    _initialized = true;
  }

  /// 시나리오를 바꿔 다시 시드한다. 개발 중 hot restart 대신 쓸 수 있다.
  void reset() {
    _initialized = false;
    _initializing = null;
    _todosByDate.clear();
    _goals.clear();
    _nextTodoId = 900;
    _nextGoalId = 90;
    _aiUsedToday = 0;
    _tokenExpiryFired = false;
    _social.reset();
  }

  // ---------------------------------------------------------------- 라우팅

  MockResult handle({
    required String method,
    required String path,
    required Map<String, dynamic> query,
    required Object? body,
    required MockScenario scenario,
  }) {
    final segments = Uri.parse(path).pathSegments;

    if (scenario == MockScenario.serverError && !_isAuthPath(segments)) {
      return MockResult.error(500, 'INTERNAL_ERROR', '서버에 문제가 생겼어요.');
    }

    // 로그인 직후 첫 보호 요청 한 번만 401 을 낸다. 재발급 → 재시도를 확인한다.
    if (scenario == MockScenario.tokenExpired &&
        !_isAuthEntryPath(segments) &&
        !_tokenExpiryFired) {
      _tokenExpiryFired = true;
      return MockResult.error(401, 'TOKEN_EXPIRED', '토큰이 만료됐습니다.');
    }

    if (segments.isEmpty) return _notFound();

    if (segments.first == 'auth') return _handleAuth(method, segments, body);
    if (segments.first == 'todos') {
      return _handleTodos(method, segments, query, body);
    }
    if (segments.first == 'goals') {
      return _handleGoals(method, segments, query, body);
    }
    if (segments.first == 'ai') {
      // 계획량 안내는 집계 기반이라 AI 쿼터와 무관하다. 먼저 가로챈다.
      final loadCheck = _social.handleLoadCheck(
        method: method,
        segments: segments,
        query: query,
        body: body,
      );
      if (loadCheck != null) return loadCheck;
      return _handleAi(method, segments, body);
    }

    final social = _social.handle(
      method: method,
      segments: segments,
      query: query,
      body: body,
    );
    if (social != null) return social;

    return _notFound();
  }

  bool _isAuthPath(List<String> segments) =>
      segments.isNotEmpty && segments.first == 'auth';

  /// 로그인/회원가입/재발급. 만료 시나리오에서도 통과해야 한다.
  bool _isAuthEntryPath(List<String> segments) {
    if (segments.length < 2 || segments.first != 'auth') return false;
    return const <String>{'login', 'signup', 'refresh'}.contains(segments[1]);
  }

  // ------------------------------------------------------------------ auth

  MockResult _handleAuth(String method, List<String> segments, Object? body) {
    if (segments.length < 2) return _notFound();

    switch (segments[1]) {
      case 'login':
      case 'signup':
        if (method != 'POST') return _notFound();
        final input = body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
        final email = input['email'] as String?;
        if (email == null || email.isEmpty || !email.contains('@')) {
          return MockResult.error(
            400,
            'VALIDATION_ERROR',
            '입력값을 확인해 주세요.',
            details: <String, dynamic>{'email': '이메일 형식이 올바르지 않아요.'},
          );
        }
        final password = input['password'] as String?;
        if (password != null && password.length < 8) {
          return MockResult.error(
            400,
            'WEAK_PASSWORD',
            '비밀번호는 8자 이상으로 만들어 주세요.',
          );
        }
        if (segments[1] == 'signup' && email == 'taken@p2j.dev') {
          return MockResult.error(
            409,
            'EMAIL_ALREADY_EXISTS',
            '이미 가입된 이메일이에요.',
            details: <String, dynamic>{'email': '이미 가입된 이메일이에요.'},
          );
        }
        final nickname = input['nickname'] as String?;
        if (nickname != null && nickname.isNotEmpty) {
          _user['nickname'] = nickname;
        }
        return MockResult(200, _sessionBody());

      case 'refresh':
        if (method != 'POST') return _notFound();
        _accessTokenSeq++;
        return MockResult(200, <String, dynamic>{
          'data': <String, dynamic>{
            'access_token': 'mock_access_token_v$_accessTokenSeq',
            'refresh_token': 'mock_refresh_token_v$_accessTokenSeq',
            'token_type': 'Bearer',
            'expires_in': 3600,
          },
        });

      case 'logout':
        return const MockResult(204);

      case 'me':
        if (method != 'GET') return _notFound();
        return MockResult(200, <String, dynamic>{
          'data': <String, dynamic>{..._user, 'today': _today},
        });
    }
    return _notFound();
  }

  Map<String, dynamic> _sessionBody() => <String, dynamic>{
        'data': <String, dynamic>{
          'access_token': 'mock_access_token_v$_accessTokenSeq',
          'refresh_token': 'mock_refresh_token_v$_accessTokenSeq',
          'token_type': 'Bearer',
          'expires_in': 3600,
          // /auth/me 의 data 와 완전히 같은 형태다. today 도 함께 준다.
          'user': <String, dynamic>{..._user, 'today': _today},
        },
      };

  MockResult _notFound() =>
      MockResult.error(404, 'NOT_FOUND', '요청한 경로를 찾을 수 없습니다.');

  // ----------------------------------------------------------------- todos

  MockResult _handleTodos(
    String method,
    List<String> segments,
    Map<String, dynamic> query,
    Object? body,
  ) {
    if (segments.length == 1 && method == 'GET') {
      return _dayTodos((query['date'] as String?) ?? _today);
    }
    if (segments.length == 1 && method == 'POST') {
      return _createTodo(body);
    }
    if (segments.length == 2 && segments[1] == 'week' && method == 'GET') {
      return _weekSummary(query['start_date'] as String?);
    }
    if (segments.length == 2 && segments[1] == 'bulk' && method == 'POST') {
      return _createBulk(body);
    }

    if (segments.length >= 2) {
      final id = int.tryParse(segments[1]);
      if (id == null) return _notFound();
      final todo = _findTodo(id);
      if (todo == null) {
        return MockResult.error(404, 'TODO_NOT_FOUND', '해당 투두를 찾을 수 없습니다.');
      }
      if (segments.length == 2) {
        if (method == 'GET') return MockResult(200, <String, dynamic>{'data': todo});
        if (method == 'PATCH') return _patchTodo(todo, body);
        if (method == 'DELETE') return _deleteTodo(todo);
      }
      if (segments.length == 3 && method == 'POST') {
        if (segments[2] == 'complete') return _completeTodo(todo, body);
        if (segments[2] == 'uncomplete') return _uncompleteTodo(todo);
        if (segments[2] == 'postpone') return _postponeTodo(todo, body);
      }
    }
    return _notFound();
  }

  MockResult _dayTodos(String date) {
    final items = List<Map<String, dynamic>>.from(
      _todosByDate[date] ?? const <Map<String, dynamic>>[],
    )..sort(
        (a, b) =>
            ((a['order'] as int?) ?? 0).compareTo((b['order'] as int?) ?? 0),
      );

    return MockResult(200, <String, dynamic>{
      'data': <String, dynamic>{
        'date': date,
        'items': items,
        'summary': _summary(items),
      },
    });
  }

  Map<String, dynamic> _summary(List<Map<String, dynamic>> items) {
    final total = items.length;
    final done = items.where((e) => e['status'] == 'done').length;
    final estimated = items.fold<int>(
      0,
      (sum, e) => sum + ((e['estimated_minutes'] as int?) ?? 0),
    );
    return <String, dynamic>{
      'total': total,
      'done': done,
      'achievement_rate': _rate(done, total),
      'total_estimated_minutes': estimated,
    };
  }

  MockResult _weekSummary(String? startDate) {
    final start = startDate != null
        ? FixtureLoader.parseDate(startDate)
        : FixtureLoader.parseDate(_today).subtract(const Duration(days: 6));

    final days = <Map<String, dynamic>>[];
    for (var i = 0; i < 7; i++) {
      final date = FixtureLoader.formatDate(start.add(Duration(days: i)));
      final items = _todosByDate[date] ?? const <Map<String, dynamic>>[];
      final done = items.where((e) => e['status'] == 'done').length;
      days.add(<String, dynamic>{
        'date': date,
        'total': items.length,
        'done': done,
        'achievement_rate': _rate(done, items.length),
      });
    }
    return MockResult(200, <String, dynamic>{'data': days});
  }

  MockResult _createTodo(Object? body) {
    final input =
        body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
    final title = (input['title'] as String?)?.trim() ?? '';
    if (title.isEmpty) {
      return MockResult.error(
        400,
        'VALIDATION_ERROR',
        '입력값을 확인해 주세요.',
        details: <String, dynamic>{'title': '할 일 이름을 입력하세요.'},
      );
    }

    final date = (input['date'] as String?) ?? _today;
    final goalId = input['goal_id'] as int?;
    final todo = <String, dynamic>{
      'todo_id': _nextTodoId++,
      'goal_id': goalId,
      'goal_title': _goalTitle(goalId),
      'title': title,
      'date': date,
      'status': 'pending',
      'estimated_minutes': input['estimated_minutes'] as int?,
      'actual_minutes': null,
      'completed_at': null,
      'order': (_todosByDate[date]?.length ?? 0) + 1,
      'is_declared': false,
      'source': 'manual',
      'postpone_count': 0,
      'memo': input['memo'] as String?,
    };
    (_todosByDate[date] ??= <Map<String, dynamic>>[]).add(todo);
    return MockResult(201, <String, dynamic>{'data': todo});
  }

  MockResult _patchTodo(Map<String, dynamic> todo, Object? body) {
    if (todo['is_declared'] == true) return _declaredLocked();

    final input =
        body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
    if (input.containsKey('title')) {
      final title = (input['title'] as String?)?.trim() ?? '';
      if (title.isEmpty) {
        return MockResult.error(
          400,
          'VALIDATION_ERROR',
          '입력값을 확인해 주세요.',
          details: <String, dynamic>{'title': '할 일 이름을 입력하세요.'},
        );
      }
      todo['title'] = title;
    }
    if (input.containsKey('estimated_minutes')) {
      todo['estimated_minutes'] = input['estimated_minutes'];
    }
    if (input.containsKey('order')) todo['order'] = input['order'];
    if (input.containsKey('memo')) todo['memo'] = input['memo'];
    if (input.containsKey('goal_id')) {
      todo['goal_id'] = input['goal_id'];
      todo['goal_title'] = _goalTitle(input['goal_id'] as int?);
    }
    if (input.containsKey('date')) {
      _moveTodo(todo, input['date'] as String);
    }
    return MockResult(200, <String, dynamic>{'data': todo});
  }

  String _shiftDate(String date, int days) => FixtureLoader.formatDate(
        FixtureLoader.parseDate(date).add(Duration(days: days)),
      );

  /// 날짜를 바꾸면 저장 위치도 옮긴다. 그러지 않으면 옛 날짜 목록에 남는다.
  void _moveTodo(Map<String, dynamic> todo, String toDate) {
    final from = todo['date'] as String;
    if (from == toDate) return;
    _todosByDate[from]?.removeWhere((e) => e['todo_id'] == todo['todo_id']);
    todo['date'] = toDate;
    todo['order'] = (_todosByDate[toDate]?.length ?? 0) + 1;
    (_todosByDate[toDate] ??= <Map<String, dynamic>>[]).add(todo);
  }

  /// 미루기. to_date 를 안 주면 다음 날로 옮기고 횟수를 올린다.
  MockResult _postponeTodo(Map<String, dynamic> todo, Object? body) {
    if (todo['is_declared'] == true) return _declaredLocked();
    final input =
        body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
    final to = (input['to_date'] as String?) ?? _shiftDate(todo['date'] as String, 1);
    _moveTodo(todo, to);
    todo['postpone_count'] = ((todo['postpone_count'] as int?) ?? 0) + 1;
    todo['status'] = 'pending';
    todo['completed_at'] = null;
    return MockResult(200, <String, dynamic>{'data': todo});
  }

  /// AI 초안 확정 저장. 서버와 같이 하나라도 실패하면 전부 만들지 않는다.
  MockResult _createBulk(Object? body) {
    final input =
        body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
    final raw = input['items'];
    if (raw is! List || raw.isEmpty) {
      return MockResult.error(
        400,
        'VALIDATION_ERROR',
        '입력값을 확인해 주세요.',
        details: <String, dynamic>{'items': '저장할 할 일을 하나 이상 넣으세요.'},
      );
    }
    final items = raw.whereType<Map>().map(Map<String, dynamic>.from).toList();
    for (final item in items) {
      if (((item['title'] as String?)?.trim() ?? '').isEmpty) {
        return MockResult.error(
          400,
          'VALIDATION_ERROR',
          '입력값을 확인해 주세요.',
          details: <String, dynamic>{'title': '할 일 이름을 입력하세요.'},
        );
      }
    }

    final source = (input['source'] as String?) ?? 'ai_suggested';
    final created = <Map<String, dynamic>>[];
    for (final item in items) {
      final date = (item['date'] as String?) ?? _today;
      final goalId = item['goal_id'] as int?;
      final todo = <String, dynamic>{
        'todo_id': _nextTodoId++,
        'goal_id': goalId,
        'goal_title': _goalTitle(goalId),
        'title': (item['title'] as String).trim(),
        'date': date,
        'status': 'pending',
        'estimated_minutes': item['estimated_minutes'] as int?,
        'actual_minutes': null,
        'completed_at': null,
        'order': (_todosByDate[date]?.length ?? 0) + 1,
        'is_declared': false,
        'source': source,
        'postpone_count': 0,
        'memo': item['memo'] as String?,
      };
      (_todosByDate[date] ??= <Map<String, dynamic>>[]).add(todo);
      created.add(todo);
    }
    return MockResult(201, <String, dynamic>{
      'data': <String, dynamic>{
        'items': created,
        'created_count': created.length,
      },
    });
  }

  MockResult _deleteTodo(Map<String, dynamic> todo) {
    if (todo['is_declared'] == true) return _declaredLocked();
    _todosByDate[todo['date'] as String]
        ?.removeWhere((e) => e['todo_id'] == todo['todo_id']);
    return const MockResult(204);
  }

  MockResult _completeTodo(Map<String, dynamic> todo, Object? body) {
    final input =
        body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
    todo['status'] = 'done';
    todo['actual_minutes'] =
        input['actual_minutes'] ?? todo['estimated_minutes'];
    final date = todo['date'] as String;
    todo['completed_at'] = '${date}T${_nowClock()}+09:00';

    return MockResult(200, <String, dynamic>{
      'data': <String, dynamic>{
        'todo': todo,
        'goal_progress': _goalProgress(todo['goal_id'] as int?),
        'personal_streak': _streak(),
      },
    });
  }

  MockResult _uncompleteTodo(Map<String, dynamic> todo) {
    todo['status'] = 'pending';
    todo['actual_minutes'] = null;
    todo['completed_at'] = null;
    _goalProgress(todo['goal_id'] as int?);
    return const MockResult(204);
  }

  // ----------------------------------------------------------------- goals

  MockResult _handleGoals(
    String method,
    List<String> segments,
    Map<String, dynamic> query,
    Object? body,
  ) {
    if (segments.length == 1) {
      if (method == 'GET') {
        final status = query['status'] as String?;
        final goals = status == null
            ? _goals
            : _goals.where((g) => g['status'] == status).toList();
        // 커서는 흉내내지 않는다. 첫 페이지에 전부 담아 준다.
        return MockResult(200, <String, dynamic>{
          'data': goals,
          'page': <String, dynamic>{'next_cursor': null, 'has_next': false},
        });
      }
      if (method == 'POST') return _createGoal(body);
      return _notFound();
    }

    final id = int.tryParse(segments[1]);
    if (id == null) return _notFound();
    final goal = _findGoal(id);
    if (goal == null) {
      return MockResult.error(404, 'GOAL_NOT_FOUND', '해당 목표를 찾을 수 없습니다.');
    }

    if (segments.length == 2) {
      if (method == 'GET') {
        return MockResult(200, <String, dynamic>{'data': goal});
      }
      if (method == 'PATCH') return _patchGoal(goal, body);
      if (method == 'DELETE') return _deleteGoal(id);
    }
    if (segments.length == 3 && segments[2] == 'archive' && method == 'POST') {
      goal['status'] = 'archived';
      return MockResult(200, <String, dynamic>{'data': goal});
    }
    return _notFound();
  }

  Map<String, dynamic>? _findGoal(int id) {
    for (final goal in _goals) {
      if (goal['goal_id'] == id) return goal;
    }
    return null;
  }

  /// 서버와 같이 연결된 투두는 지우지 않고 goal_id 만 끊는다.
  MockResult _deleteGoal(int id) {
    _goals.removeWhere((g) => g['goal_id'] == id);
    for (final items in _todosByDate.values) {
      for (final todo in items) {
        if (todo['goal_id'] == id) {
          todo['goal_id'] = null;
          todo['goal_title'] = null;
        }
      }
    }
    return const MockResult(204);
  }

  MockResult _createGoal(Object? body) {
    final input =
        body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
    final title = (input['title'] as String?)?.trim() ?? '';
    if (title.isEmpty) {
      return MockResult.error(
        400,
        'VALIDATION_ERROR',
        '입력값을 확인해 주세요.',
        details: <String, dynamic>{'title': '목표 이름을 입력하세요.'},
      );
    }

    final type = (input['type'] as String?) ?? 'single';
    final frequency = input['frequency'];
    if (type == 'recurring' && frequency is! Map) {
      return MockResult.error(
        400,
        'VALIDATION_ERROR',
        '입력값을 확인해 주세요.',
        details: <String, dynamic>{'frequency': '반복 목표는 빈도가 필요해요.'},
      );
    }

    final start = (input['start_date'] as String?) ?? _today;
    final weeks = input['duration_weeks'] as int?;
    final goal = <String, dynamic>{
      'goal_id': _nextGoalId++,
      'title': title,
      'type': type,
      'status': 'active',
      'color': input['color'] as String?,
      'frequency': type == 'recurring'
          ? Map<String, dynamic>.from(frequency! as Map)
          : null,
      'duration_weeks': type == 'recurring' ? weeks : null,
      'start_date': start,
      // 서버와 같은 계산: start + weeks*7 - 1
      'end_date': weeks == null ? null : _shiftDate(start, weeks * 7 - 1),
      'estimated_minutes': input['estimated_minutes'] as int?,
      'created_at': '${_today}T${_nowClock()}+09:00',
    };
    _goals.add(goal);
    goal['progress'] = _goalProgress(goal['goal_id'] as int);
    return MockResult(201, <String, dynamic>{'data': goal});
  }

  MockResult _patchGoal(Map<String, dynamic> goal, Object? body) {
    final input =
        body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
    if (input.containsKey('title')) {
      final title = (input['title'] as String?)?.trim() ?? '';
      if (title.isEmpty) {
        return MockResult.error(
          400,
          'VALIDATION_ERROR',
          '입력값을 확인해 주세요.',
          details: <String, dynamic>{'title': '목표 이름을 입력하세요.'},
        );
      }
      goal['title'] = title;
    }
    // type · frequency · start_date 는 서버가 받지 않는다. 여기서도 무시한다.
    if (input.containsKey('color')) goal['color'] = input['color'];
    if (input.containsKey('estimated_minutes')) {
      goal['estimated_minutes'] = input['estimated_minutes'];
    }
    if (input.containsKey('duration_weeks')) {
      final weeks = input['duration_weeks'] as int?;
      goal['duration_weeks'] = weeks;
      goal['end_date'] = weeks == null
          ? null
          : _shiftDate(goal['start_date'] as String, weeks * 7 - 1);
    }
    if (input.containsKey('status')) goal['status'] = input['status'];
    return MockResult(200, <String, dynamic>{'data': goal});
  }

  // -------------------------------------------------------------------- ai

  static const int _aiLimitPerDay = 30;

  /// 초안 분리 기준. 쉼표, 줄바꿈, "그리고".
  static final RegExp _draftSplitter = RegExp(r'[,\n]|그리고');

  /// 서버의 3단계 폴백을 흉내내지 않는다. LLM 이 없으니 늘 규칙 파서 수준이다.
  /// 문장을 쉼표·줄바꿈·"그리고" 로 잘라 초안을 만든다. 응답 형태만 서버와 같다.
  MockResult _handleAi(String method, List<String> segments, Object? body) {
    if (segments.length != 2) return _notFound();

    if (segments[1] == 'quota' && method == 'GET') {
      return MockResult(200, <String, dynamic>{'data': _quota()});
    }
    if (segments[1] != 'parse' || method != 'POST') return _notFound();

    final input =
        body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
    final text = (input['text'] as String?)?.trim() ?? '';
    if (text.isEmpty) {
      return MockResult.error(
        400,
        'VALIDATION_ERROR',
        '입력값을 확인해 주세요.',
        details: <String, dynamic>{'text': '무엇을 할지 말해 주세요.'},
      );
    }
    if (_aiUsedToday >= _aiLimitPerDay) {
      return MockResult.error(
        429,
        'AI_QUOTA_EXCEEDED',
        'AI 요청이 너무 잦아요. 잠시 후 다시 시도해 주세요.',
      );
    }
    _aiUsedToday++;

    final date = (input['reference_date'] as String?) ?? _today;
    final pieces = text
        .split(_draftSplitter)
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final drafts = <Map<String, dynamic>>[];
    for (var i = 0; i < pieces.length; i++) {
      drafts.add(<String, dynamic>{
        'draft_id': 'd${i + 1}',
        'title': pieces[i],
        'date': date,
        'time_hint': null,
        'goal_id': null,
        'goal_title': null,
        'estimated_minutes': null,
        'confidence': 0.5,
      });
    }

    return MockResult(200, <String, dynamic>{
      'data': <String, dynamic>{
        'parse_id': 'prs_mock${_aiUsedToday.toString().padLeft(2, '0')}',
        'parse_method': 'rules',
        'drafts': drafts,
        'warnings': const <String>[],
        'quota': _quota(),
      },
    });
  }

  Map<String, dynamic> _quota() => <String, dynamic>{
        'limit_per_day': _aiLimitPerDay,
        'used_today': _aiUsedToday,
        'remaining_today': _aiLimitPerDay - _aiUsedToday,
        'reset_at': '${_shiftDate(_today, 1)}T04:00:00+09:00',
      };

  // ------------------------------------------------------------------ 계산

  Map<String, dynamic>? _findTodo(int id) {
    for (final items in _todosByDate.values) {
      for (final todo in items) {
        if (todo['todo_id'] == id) return todo;
      }
    }
    return null;
  }

  String? _goalTitle(int? goalId) {
    if (goalId == null) return null;
    for (final goal in _goals) {
      if (goal['goal_id'] == goalId) return goal['title'] as String?;
    }
    return null;
  }

  /// 목표 진행률을 다시 계산하고 저장된 목표에도 반영한다.
  /// 투두 완료가 목표 목록 화면까지 이어지게 하기 위한 것이다.
  Map<String, dynamic> _goalProgress(int? goalId) {
    if (goalId == null) {
      return <String, dynamic>{'done_count': 0, 'current_week_done': 0};
    }

    final weekStart =
        FixtureLoader.parseDate(_today).subtract(const Duration(days: 6));
    var doneCount = 0;
    var weekDone = 0;

    for (final entry in _todosByDate.entries) {
      for (final todo in entry.value) {
        if (todo['goal_id'] != goalId || todo['status'] != 'done') continue;
        doneCount++;
        if (!FixtureLoader.parseDate(entry.key).isBefore(weekStart)) weekDone++;
      }
    }

    for (final goal in _goals) {
      if (goal['goal_id'] != goalId) continue;
      final progress = Map<String, dynamic>.from(goal['progress'] as Map);
      progress['done_count'] = doneCount;
      progress['current_week_done'] = weekDone;
      progress['achievement_rate'] =
          _rate(doneCount, (progress['target_count'] as int?) ?? 0);
      goal['progress'] = progress;
    }

    return <String, dynamic>{
      'done_count': doneCount,
      'current_week_done': weekDone,
    };
  }

  /// 오늘까지 이어진 연속 달성 일수.
  /// 오늘은 아직 진행 중이므로 미완료여도 연속을 끊지 않는다.
  int _streak() {
    var cursor = FixtureLoader.parseDate(_today);
    final todayItems = _todosByDate[_today];
    final todayCleared = todayItems != null &&
        todayItems.isNotEmpty &&
        todayItems.every((e) => e['status'] == 'done');
    if (!todayCleared) cursor = cursor.subtract(const Duration(days: 1));

    var streak = 0;
    for (var i = 0; i < 90; i++) {
      final items = _todosByDate[FixtureLoader.formatDate(cursor)];
      if (items == null || items.isEmpty) break;
      if (!items.every((e) => e['status'] == 'done')) break;
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  double _rate(int done, int total) {
    if (total == 0) return 0;
    return double.parse((done / total).toStringAsFixed(2));
  }

  String _nowClock() {
    final kst = DateTime.now().toUtc().add(const Duration(hours: 9));
    final hh = kst.hour.toString().padLeft(2, '0');
    final mm = kst.minute.toString().padLeft(2, '0');
    return '$hh:$mm:00';
  }

  MockResult _declaredLocked() => MockResult.error(
        422,
        'DECLARED_TODO_LOCKED',
        '그룹에 선언한 항목은 오늘 수정할 수 없어요.',
      );
}
