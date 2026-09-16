import 'fixture_loader.dart';
import 'mock_store.dart';

/// 통계 · 계획량 안내 · 그룹 · 선언 · 피드 · 랭킹의 가짜 서버.
///
/// [MockStore] 가 800줄을 넘어 더 얹기 어려워 이 영역만 떼어 냈다.
/// 투두 원본(`todosByDate`)은 [MockStore] 것을 **그대로 참조**한다. 복사하면
/// 홈에서 완료를 눌러도 그룹 화면의 달성률이 따라오지 않는다.
///
/// 처음 열었을 때 화면이 비어 있지 않도록 그룹 하나와 동료 두 명, 어제치 선언과
/// 인증을 미리 깔아 둔다. 빈 상태만 보이면 레이아웃을 확인할 수 없다.
class MockSocial {
  MockSocial({
    required Map<String, List<Map<String, dynamic>>> todosByDate,
    required Map<String, dynamic> Function() currentUser,
    required String Function() today,
  })  : _todosByDate = todosByDate,
        _currentUser = currentUser,
        _today = today;

  final Map<String, List<Map<String, dynamic>>> _todosByDate;
  final Map<String, dynamic> Function() _currentUser;
  final String Function() _today;

  /// 60분 이상을 "무거운 일" 로 본다. 서버 `stats.HEAVY_TASK_MINUTES` 와 같다.
  static const int _heavyMinutes = 60;
  static const int _loadWindowDays = 14;
  static const int _minRecordDays = 7;

  final List<Map<String, dynamic>> _groups = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> _members = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> _declarations = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> _proofs = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> _comments = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> _reactions = <Map<String, dynamic>>[];
  final Map<String, Map<String, dynamic>> _loadChecks =
      <String, Map<String, dynamic>>{};

  /// 동료 계정. 실제 서버라면 다른 사용자의 행이다.
  static const Map<int, String> _peers = <int, String>{2: '지호', 3: '영준'};

  int _nextGroupId = 7;
  int _nextDeclarationId = 80;
  int _nextItemId = 400;
  int _nextPostId = 500;
  int _nextCommentId = 600;
  int _nextReactionId = 700;

  int get _myId => _currentUser()['user_id'] as int? ?? 1;

  String get _myNickname => _currentUser()['nickname'] as String? ?? '나';

  void reset() {
    _groups.clear();
    _members.clear();
    _declarations.clear();
    _proofs.clear();
    _comments.clear();
    _reactions.clear();
    _loadChecks.clear();
    _nextGroupId = 7;
    _nextDeclarationId = 80;
    _nextItemId = 400;
    _nextPostId = 500;
    _nextCommentId = 600;
    _nextReactionId = 700;
  }

  /// 데모 그룹 한 개. 어제는 셋 다 선언했고 동료 둘은 다 끝냈다.
  void seed() {
    if (_groups.isNotEmpty) return;

    final groupId = _nextGroupId++;
    _groups.add(<String, dynamic>{
      'group_id': groupId,
      'name': '3학년 개발조',
      'owner_id': _myId,
      'max_members': 6,
      'invite_code': 'P2J-K3M9',
      'group_streak': 2,
      'last_streak_date': _shift(_today(), -1),
      'created_at': _iso(_shift(_today(), -14)),
    });

    _addMember(groupId, _myId, _myNickname, 'owner');
    _peers.forEach((id, name) => _addMember(groupId, id, name, 'member'));

    // 어제치 기록. 동료 둘은 100%, 나는 절반만 끝낸 상태로 둔다.
    final yesterday = _shift(_today(), -1);
    _seedPeerDeclaration(groupId, 2, yesterday, ['알고리즘 2문제', '운동 30분'], 2);
    _seedPeerDeclaration(groupId, 3, yesterday, ['논문 읽기'], 1);
  }

  void _addMember(int groupId, int userId, String nickname, String role) {
    _members.add(<String, dynamic>{
      'group_id': groupId,
      'user_id': userId,
      'nickname': nickname,
      'profile_image_url': null,
      'role': role,
      'joined_at': _iso(_shift(_today(), -14)),
      'left_at': null,
      'last_read_at': null,
    });
  }

  /// 동료의 선언은 투두 원본이 없으므로 항목 상태를 직접 들고 있는다.
  void _seedPeerDeclaration(
    int groupId,
    int userId,
    String date,
    List<String> titles,
    int doneCount,
  ) {
    final items = <Map<String, dynamic>>[];
    for (var i = 0; i < titles.length; i++) {
      items.add(<String, dynamic>{
        'declaration_item_id': _nextItemId++,
        'todo_id': null,
        'title_snapshot': titles[i],
        'peer_status': i < doneCount ? 'done' : 'pending',
      });
    }
    _declarations.add(<String, dynamic>{
      'declaration_id': _nextDeclarationId++,
      'group_id': groupId,
      'user_id': userId,
      'date': date,
      'locked_at': '${date}T08:30:00+09:00',
      'items': items,
    });

    if (doneCount > 0) {
      _proofs.add(<String, dynamic>{
        'post_id': _nextPostId++,
        'declaration_item_id': items.first['declaration_item_id'],
        'group_id': groupId,
        'user_id': userId,
        'date': date,
        'file_key': 'proofs/demo/$userId.jpg',
        'caption': userId == 2 ? '헬스장 다녀왔어요' : '도서관에서 끝냄',
        'created_at': '${date}T21:10:00+09:00',
        'deleted_at': null,
      });
    }
  }

  // ------------------------------------------------------------------ 라우팅

  /// 처리하지 못하는 경로면 null 을 돌려준다. [MockStore] 가 404 로 마무리한다.
  MockResult? handle({
    required String method,
    required List<String> segments,
    required Map<String, dynamic> query,
    required Object? body,
  }) {
    seed();
    return switch (segments.first) {
      'stats' => _handleStats(segments, query),
      'groups' => _handleGroups(method, segments, query, body),
      'posts' => _handlePosts(method, segments, query, body),
      'comments' => _handleComments(method, segments),
      'uploads' => _handleUploads(segments),
      _ => null,
    };
  }

  /// `/ai/load-check` 두 개. AI 경로라 [MockStore] 가 따로 넘겨 준다.
  MockResult? handleLoadCheck({
    required String method,
    required List<String> segments,
    required Map<String, dynamic> query,
    required Object? body,
  }) {
    if (segments.length >= 2 && segments[1] == 'load-check') {
      if (method == 'GET' && segments.length == 2) {
        return MockResult(200, <String, dynamic>{
          'data': _loadCheck(query['date'] as String? ?? _today()),
        });
      }
      if (method == 'POST' && segments.length == 4 && segments[3] == 'response') {
        final check = _loadChecks.values
            .where((e) => e['check_id'] == segments[2])
            .firstOrNull;
        if (check == null) {
          return MockResult.error(404, 'LOAD_CHECK_NOT_FOUND', '안내 기록을 찾을 수 없어요.');
        }
        final map = _asMap(body);
        check['accepted'] = map['accepted'] ?? false;
        check['applied_todo_ids'] = map['applied_todo_ids'] ?? <int>[];
        check['responded_at'] = _iso(_today());
        return MockResult(200, <String, dynamic>{'data': check});
      }
    }
    return null;
  }

  // -------------------------------------------------------------------- 통계

  MockResult _handleStats(List<String> segments, Map<String, dynamic> query) {
    final period = query['period'] as String? ?? 'week';
    if (period != 'week' && period != 'month') {
      return MockResult.error(400, 'VALIDATION_ERROR', '입력값을 확인해 주세요.');
    }

    if (segments.length == 2 && segments[1] == 'summary') {
      return MockResult(200, <String, dynamic>{'data': _summary(period)});
    }
    if (segments.length == 3 && segments[1] == 'goals') {
      final goalId = int.tryParse(segments[2]);
      if (goalId == null) {
        return MockResult.error(404, 'GOAL_NOT_FOUND', '목표를 찾을 수 없어요.');
      }
      return MockResult(200, <String, dynamic>{'data': _goalStats(goalId, period)});
    }
    return MockResult.error(404, 'NOT_FOUND', '요청한 경로를 찾을 수 없어요.');
  }

  /// 서버와 같은 규칙: 주 = 오늘로 끝나는 최근 7일, 달 = 30일.
  Map<String, dynamic> _summary(String period) {
    final span = period == 'month' ? 30 : 7;
    final first = _shift(_today(), -(span - 1));

    var total = 0;
    var done = 0;
    var minutes = 0;
    final byDay = <Map<String, dynamic>>[];
    final byHour = <int, int>{};

    for (var i = 0; i < span; i++) {
      final date = _shift(first, i);
      final items = _todosByDate[date] ?? const <Map<String, dynamic>>[];
      final dayDone = items.where((e) => e['status'] == 'done').length;
      total += items.length;
      done += dayDone;
      for (final item in items.where((e) => e['status'] == 'done')) {
        minutes += (item['actual_minutes'] as int?) ??
            (item['estimated_minutes'] as int?) ??
            0;
        final at = DateTime.tryParse(item['completed_at'] as String? ?? '');
        if (at != null) {
          final hour = at.toUtc().add(const Duration(hours: 9)).hour;
          byHour[hour] = (byHour[hour] ?? 0) + 1;
        }
      }
      byDay.add(<String, dynamic>{
        'date': date,
        'achievement_rate': items.isEmpty ? 0.0 : _round(dayDone / items.length),
      });
    }

    final hours = byHour.keys.toList()..sort();
    return <String, dynamic>{
      'period': period,
      'range': <String, dynamic>{'from': first, 'to': _today()},
      'achievement_rate': total == 0 ? 0.0 : _round(done / total),
      'total_todos': total,
      'completed_todos': done,
      'total_actual_minutes': minutes,
      'current_streak': _currentStreak(),
      'longest_streak': _longestStreak(),
      'by_day': byDay,
      'by_hour': [
        for (final h in hours)
          <String, dynamic>{'hour': h, 'completed': byHour[h]},
      ],
      'most_deferred': _mostDeferred(first),
    };
  }

  /// 미룬 항목. 서버와 같이 **기간의 끝은 보지 않는다** — 미루면 날짜가 앞으로 가서
  /// 상한을 두면 정작 계속 미루는 항목이 빠져나간다.
  List<Map<String, dynamic>> _mostDeferred(String first) {
    final byGoal = <int, Map<String, dynamic>>{};
    final loose = <Map<String, dynamic>>[];

    for (final entry in _todosByDate.entries) {
      if (entry.key.compareTo(first) < 0) continue;
      for (final todo in entry.value) {
        final count = todo['postpone_count'] as int? ?? 0;
        if (count <= 0) continue;
        final goalId = todo['goal_id'] as int?;
        if (goalId == null) {
          loose.add(<String, dynamic>{
            'goal_id': null,
            'title': todo['title'],
            'defer_count': count,
          });
        } else {
          final bucket = byGoal.putIfAbsent(
            goalId,
            () => <String, dynamic>{
              'goal_id': goalId,
              'title': todo['goal_title'] ?? todo['title'],
              'defer_count': 0,
            },
          );
          bucket['defer_count'] = (bucket['defer_count'] as int) + count;
        }
      }
    }

    final merged = <Map<String, dynamic>>[...byGoal.values, ...loose]
      ..sort((a, b) =>
          (b['defer_count'] as int).compareTo(a['defer_count'] as int));
    return merged.take(5).toList();
  }

  Map<String, dynamic> _goalStats(int goalId, String period) {
    final span = period == 'month' ? 30 : 7;
    final first = _shift(_today(), -(span - 1));

    final byDay = <Map<String, dynamic>>[];
    var totalAll = 0;
    var doneAll = 0;
    var minutes = 0;
    String title = '';

    for (final entry in _todosByDate.entries) {
      for (final todo in entry.value.where((e) => e['goal_id'] == goalId)) {
        title = (todo['goal_title'] as String?) ?? title;
        totalAll++;
        if (todo['status'] == 'done') {
          doneAll++;
          minutes += (todo['actual_minutes'] as int?) ?? 0;
        }
      }
    }

    for (var i = 0; i < span; i++) {
      final date = _shift(first, i);
      final items = (_todosByDate[date] ?? const <Map<String, dynamic>>[])
          .where((e) => e['goal_id'] == goalId)
          .toList();
      final dayDone = items.where((e) => e['status'] == 'done').length;
      byDay.add(<String, dynamic>{
        'date': date,
        'total': items.length,
        'done': dayDone,
        'achievement_rate': items.isEmpty ? 0.0 : _round(dayDone / items.length),
      });
    }

    return <String, dynamic>{
      'goal_id': goalId,
      'title': title,
      'color': null,
      'status': 'active',
      'period': period,
      'range': <String, dynamic>{'from': first, 'to': _today()},
      'total_todos': totalAll,
      'completed_todos': doneAll,
      'achievement_rate': totalAll == 0 ? 0.0 : _round(doneAll / totalAll),
      'total_actual_minutes': minutes,
      'current_week_done': doneAll,
      'by_day': byDay,
    };
  }

  /// 오늘까지 이어진 연속 달성 일수. 오늘은 진행 중이라 미완료여도 끊지 않는다.
  int _currentStreak() {
    var cursor = FixtureLoader.parseDate(_today());
    if (!_cleared(_today())) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    var streak = 0;
    for (var i = 0; i < 90; i++) {
      if (!_cleared(FixtureLoader.formatDate(cursor))) break;
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  int _longestStreak() {
    final days = _todosByDate.keys.where(_cleared).toList()..sort();
    var best = 0;
    var run = 0;
    DateTime? previous;
    for (final day in days) {
      final parsed = FixtureLoader.parseDate(day);
      run = previous != null && parsed.difference(previous).inDays == 1 ? run + 1 : 1;
      best = run > best ? run : best;
      previous = parsed;
    }
    return best;
  }

  bool _cleared(String date) {
    final items = _todosByDate[date];
    if (items == null || items.isEmpty) return false;
    return items.every((e) => e['status'] == 'done');
  }

  // ----------------------------------------------------------- 계획량 안내

  /// 하루 한 번만 계산하고 이후에는 저장된 결과를 그대로 준다 (서버와 같다).
  Map<String, dynamic> _loadCheck(String date) {
    final cached = _loadChecks[date];
    if (cached != null) return cached;

    var recordDays = 0;
    var heavyDays = 0;
    var actualTotal = 0;
    for (var i = 1; i <= _loadWindowDays; i++) {
      final items = _todosByDate[_shift(date, -i)];
      if (items == null) continue;
      final done = items.where((e) => e['status'] == 'done').toList();
      if (done.isEmpty) continue;
      recordDays++;
      actualTotal += done.fold<int>(
        0,
        (sum, e) => sum + ((e['actual_minutes'] as int?) ?? 0),
      );
      final heavy = done
          .where((e) => ((e['estimated_minutes'] as int?) ?? 0) >= _heavyMinutes)
          .length;
      if (heavy >= 3) heavyDays++;
    }

    final todayItems = _todosByDate[date] ?? const <Map<String, dynamic>>[];
    final planned = todayItems.fold<int>(
      0,
      (sum, e) => sum + ((e['estimated_minutes'] as int?) ?? 0),
    );
    final todayHeavy = todayItems
        .where((e) => ((e['estimated_minutes'] as int?) ?? 0) >= _heavyMinutes)
        .length;
    final average = recordDays == 0 ? 0 : (actualTotal / recordDays).round();

    var level = 'ok';
    String? message;
    if (recordDays >= _minRecordDays) {
      if (todayHeavy >= 3 && heavyDays < 3) {
        level = 'warning';
        message = '지난 $_loadWindowDays일간 한 시간 이상 걸리는 일을 두 개 넘게 끝낸 날은 '
            '${heavyDays == 0 ? "하루도 없었어요" : "$heavyDays일뿐이었어요"}. '
            '오늘 $todayHeavy 개는 부담일 수 있어요.';
      } else if (average > 0 && planned > average * 1.5) {
        level = 'warning';
        message = '평소에는 하루 $average분쯤 끝냈는데 오늘 계획은 $planned분이에요. '
            '몇 개는 내일로 미뤄도 괜찮아요.';
      }
    }

    final suggestions = <Map<String, dynamic>>[];
    if (level == 'warning' && average > 0) {
      var remaining = planned;
      final candidates = todayItems
          .where((e) => e['status'] == 'pending' && e['is_declared'] != true)
          .toList()
          .reversed;
      for (final todo in candidates) {
        if (remaining <= average || suggestions.length >= 3) break;
        suggestions.add(<String, dynamic>{
          'todo_id': todo['todo_id'],
          'action': 'defer',
          'to_date': _shift(date, 1),
          'reason': '가장 늦게 추가된 항목',
        });
        remaining -= (todo['estimated_minutes'] as int?) ?? 0;
      }
    }

    final result = <String, dynamic>{
      'check_id': 'chk_${date.replaceAll('-', '').substring(2)}',
      'date': date,
      'level': level,
      'message': message,
      'evidence': <String, dynamic>{
        'window_days': _loadWindowDays,
        'heavy_task_threshold_minutes': _heavyMinutes,
        'days_with_3plus_heavy': heavyDays,
        'avg_completed_minutes_per_day': average,
        'today_planned_minutes': planned,
        'record_days': recordDays,
        'today_heavy_count': todayHeavy,
        'today_planned_count': todayItems.length,
      },
      'suggestions': suggestions,
      'accepted': null,
      'applied_todo_ids': <int>[],
      'responded_at': null,
    };
    _loadChecks[date] = result;
    return result;
  }

  // -------------------------------------------------------------------- 그룹

  MockResult _handleGroups(
    String method,
    List<String> segments,
    Map<String, dynamic> query,
    Object? body,
  ) {
    if (segments.length == 1) {
      if (method == 'GET') {
        return MockResult(200, <String, dynamic>{
          'data': [
            for (final g in _myGroups()) _groupJson(g, withActivity: true),
          ],
        });
      }
      if (method == 'POST') return _createGroup(body);
    }

    if (segments.length == 2 && segments[1] == 'join' && method == 'POST') {
      return _joinGroup(body);
    }

    final groupId = int.tryParse(segments.length > 1 ? segments[1] : '');
    final group = _groups.where((g) => g['group_id'] == groupId).firstOrNull;
    if (group == null) {
      return MockResult.error(404, 'GROUP_NOT_FOUND', '그룹을 찾을 수 없어요.');
    }
    if (_memberOf(groupId!, _myId) == null) {
      return MockResult.error(403, 'NOT_GROUP_MEMBER', '그룹 구성원만 볼 수 있어요.');
    }

    if (segments.length == 2 && method == 'GET') {
      return MockResult(200, <String, dynamic>{
        'data': _groupJson(group, withActivity: true),
      });
    }

    final tail = segments.length > 2 ? segments[2] : '';
    return switch ((method, tail)) {
      ('POST', 'invite') => _issueInvite(group),
      ('GET', 'members') => MockResult(200, <String, dynamic>{
          'data': _memberList(groupId),
        }),
      ('DELETE', 'members') => _leaveGroup(group),
      ('POST', 'owner') => _transferOwner(group, body),
      ('POST', 'declarations') => _declare(group, body),
      ('GET', 'declarations') => MockResult(200, <String, dynamic>{
          'data': _declarationRows(groupId, query['date'] as String? ?? _today()),
        }),
      ('POST', 'proofs') => _createProof(group, body),
      ('GET', 'feed') => _feed(groupId),
      ('GET', 'ranking') => MockResult(200, <String, dynamic>{
          'data': _ranking(groupId, query['period'] as String? ?? 'week'),
        }),
      ('GET', 'streak') => MockResult(200, <String, dynamic>{
          'data': _streak(group),
        }),
      _ => MockResult.error(404, 'NOT_FOUND', '요청한 경로를 찾을 수 없어요.'),
    };
  }

  List<Map<String, dynamic>> _myGroups() => _groups
      .where((g) => _memberOf(g['group_id'] as int, _myId) != null)
      .toList();

  Map<String, dynamic>? _memberOf(int groupId, int userId) => _members
      .where((m) =>
          m['group_id'] == groupId &&
          m['user_id'] == userId &&
          m['left_at'] == null)
      .firstOrNull;

  List<Map<String, dynamic>> _activeMembers(int groupId) => _members
      .where((m) => m['group_id'] == groupId && m['left_at'] == null)
      .toList();

  Map<String, dynamic> _groupJson(
    Map<String, dynamic> group, {
    bool withActivity = false,
  }) {
    final groupId = group['group_id'] as int;
    final me = _memberOf(groupId, _myId);
    final json = <String, dynamic>{
      ...group,
      'member_count': _activeMembers(groupId).length,
      'my_role': me?['role'],
    };
    if (withActivity) {
      final posts = _proofs
          .where((p) =>
              p['group_id'] == groupId &&
              p['deleted_at'] == null &&
              p['user_id'] != _myId)
          .toList();
      final lastRead = me?['last_read_at'] as String?;
      json['unread_count'] = lastRead == null
          ? posts.length
          : posts
              .where((p) => (p['created_at'] as String).compareTo(lastRead) > 0)
              .length;
      json['last_activity_at'] = posts.isEmpty
          ? null
          : posts
              .map((p) => p['created_at'] as String)
              .reduce((a, b) => a.compareTo(b) > 0 ? a : b);
    }
    return json;
  }

  MockResult _createGroup(Object? body) {
    final map = _asMap(body);
    final name = (map['name'] as String? ?? '').trim();
    final maxMembers = map['max_members'] as int? ?? 6;
    if (name.isEmpty) {
      return MockResult.error(400, 'VALIDATION_ERROR', '입력값을 확인해 주세요.',
          details: <String, dynamic>{'name': '필수 항목이에요.'});
    }
    if (maxMembers < 3 || maxMembers > 6) {
      return MockResult.error(400, 'VALIDATION_ERROR', '입력값을 확인해 주세요.',
          details: <String, dynamic>{'max_members': '3 이상 6 이하여야 해요.'});
    }

    final groupId = _nextGroupId++;
    final group = <String, dynamic>{
      'group_id': groupId,
      'name': name,
      'owner_id': _myId,
      'max_members': maxMembers,
      'invite_code': 'P2J-${_code(groupId)}',
      'group_streak': 0,
      'last_streak_date': null,
      'created_at': _iso(_today()),
    };
    _groups.add(group);
    _addMember(groupId, _myId, _myNickname, 'owner');
    return MockResult(201, <String, dynamic>{'data': _groupJson(group)});
  }

  MockResult _joinGroup(Object? body) {
    final code = (_asMap(body)['invite_code'] as String? ?? '').toUpperCase();
    final group = _groups.where((g) => g['invite_code'] == code).firstOrNull;
    if (group == null) {
      return MockResult.error(422, 'INVALID_INVITE_CODE', '초대 코드를 다시 확인해 주세요.');
    }
    final groupId = group['group_id'] as int;
    if (_memberOf(groupId, _myId) != null) {
      return MockResult.error(409, 'ALREADY_MEMBER', '이미 참여한 그룹이에요.');
    }
    if (_activeMembers(groupId).length >= (group['max_members'] as int)) {
      return MockResult.error(422, 'GROUP_FULL', '그룹 정원이 가득 찼어요.');
    }
    _addMember(groupId, _myId, _myNickname, 'member');
    return MockResult(200, <String, dynamic>{
      'data': _groupJson(group, withActivity: true),
    });
  }

  MockResult _issueInvite(Map<String, dynamic> group) {
    final code = 'P2J-${_code(DateTime.now().millisecondsSinceEpoch)}';
    group['invite_code'] = code;
    return MockResult(200, <String, dynamic>{
      'data': <String, dynamic>{
        'invite_code': code,
        'expires_at': _iso(_shift(_today(), 7)),
      },
    });
  }

  MockResult _leaveGroup(Map<String, dynamic> group) {
    final groupId = group['group_id'] as int;
    final me = _memberOf(groupId, _myId)!;
    if (me['role'] == 'owner' && _activeMembers(groupId).length > 1) {
      return MockResult.error(
          422, 'ADMIN_MUST_TRANSFER', '관리자를 다른 구성원에게 넘긴 뒤 나갈 수 있어요.');
    }
    me['left_at'] = _iso(_today());
    if (_activeMembers(groupId).isEmpty) _groups.remove(group);
    return const MockResult(204);
  }

  MockResult _transferOwner(Map<String, dynamic> group, Object? body) {
    final groupId = group['group_id'] as int;
    final me = _memberOf(groupId, _myId)!;
    if (me['role'] != 'owner') {
      return MockResult.error(403, 'NOT_GROUP_ADMIN', '그룹 관리자만 할 수 있어요.');
    }
    final target = _memberOf(groupId, _asMap(body)['user_id'] as int? ?? -1);
    if (target == null) {
      return MockResult.error(404, 'USER_NOT_FOUND', '그룹에 없는 사용자예요.');
    }
    me['role'] = 'member';
    target['role'] = 'owner';
    group['owner_id'] = target['user_id'];
    return MockResult(200, <String, dynamic>{'data': _groupJson(group)});
  }

  List<Map<String, dynamic>> _memberList(int groupId) {
    final today = _today();
    return [
      for (final member in _activeMembers(groupId))
        <String, dynamic>{
          'user_id': member['user_id'],
          'nickname': member['nickname'],
          'profile_image_url': null,
          'role': member['role'],
          'joined_at': member['joined_at'],
          'today_declared': _declarationOf(groupId, member['user_id'] as int, today) != null,
          'today_achievement_rate':
              _rateOf(groupId, member['user_id'] as int, today),
          'streak': member['user_id'] == _myId ? _currentStreak() : 3,
        },
    ];
  }

  // -------------------------------------------------------------------- 선언

  Map<String, dynamic>? _declarationOf(int groupId, int userId, String date) =>
      _declarations
          .where((d) =>
              d['group_id'] == groupId &&
              d['user_id'] == userId &&
              d['date'] == date)
          .firstOrNull;

  /// 항목 상태. 내 선언은 투두 원본을 보고, 동료는 미리 박아 둔 값을 쓴다.
  String _itemStatus(Map<String, dynamic> item, String date) {
    final peer = item['peer_status'] as String?;
    if (peer != null) return peer;

    final todoId = item['todo_id'] as int?;
    if (todoId == null) return 'skipped';
    for (final entry in _todosByDate.entries) {
      for (final todo in entry.value) {
        if (todo['todo_id'] != todoId) continue;
        if (entry.key != date) return 'deferred';
        return todo['status'] as String? ?? 'pending';
      }
    }
    return 'skipped';
  }

  double _rateOf(int groupId, int userId, String date) {
    final declaration = _declarationOf(groupId, userId, date);
    if (declaration == null) return 0;
    final items = declaration['items'] as List<dynamic>;
    if (items.isEmpty) return 0;
    final done = items
        .where((e) =>
            _itemStatus(Map<String, dynamic>.from(e as Map), date) == 'done')
        .length;
    return _round(done / items.length);
  }

  MockResult _declare(Map<String, dynamic> group, Object? body) {
    final groupId = group['group_id'] as int;
    final today = _today();
    final map = _asMap(body);
    final date = map['date'] as String? ?? today;

    if (date.compareTo(today) < 0) {
      return MockResult.error(422, 'DECLARATION_CLOSED', '지난 날짜는 선언할 수 없어요.');
    }
    if (_declarationOf(groupId, _myId, date) != null) {
      return MockResult.error(409, 'DECLARATION_ALREADY_EXISTS', '오늘은 이미 선언했어요.');
    }

    final ids = (map['todo_ids'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<int>()
        .toSet()
        .toList();
    if (ids.isEmpty) {
      return MockResult.error(422, 'DECLARATION_EMPTY', '선언할 할 일을 하나 이상 골라 주세요.');
    }

    final items = <Map<String, dynamic>>[];
    for (var i = 0; i < ids.length; i++) {
      final todo = (_todosByDate[date] ?? const <Map<String, dynamic>>[])
          .where((e) => e['todo_id'] == ids[i])
          .firstOrNull;
      if (todo == null) {
        return MockResult.error(400, 'VALIDATION_ERROR', '입력값을 확인해 주세요.',
            details: <String, dynamic>{'todo_ids[$i]': '그날 할 일만 선언할 수 있어요.'});
      }
      // 선언한 항목은 제목·날짜·삭제가 잠긴다.
      todo['is_declared'] = true;
      items.add(<String, dynamic>{
        'declaration_item_id': _nextItemId++,
        'todo_id': todo['todo_id'],
        'title_snapshot': todo['title'],
      });
    }

    final declaration = <String, dynamic>{
      'declaration_id': _nextDeclarationId++,
      'group_id': groupId,
      'user_id': _myId,
      'date': date,
      'locked_at': _iso(date),
      'items': items,
    };
    _declarations.add(declaration);
    return MockResult(201, <String, dynamic>{
      'data': _declarationJson(declaration),
    });
  }

  Map<String, dynamic> _declarationJson(Map<String, dynamic> declaration) {
    final date = declaration['date'] as String;
    final items = (declaration['items'] as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final json = [
      for (final item in items) _itemJson(item, date),
    ];
    final done = json.where((e) => e['status'] == 'done').length;
    return <String, dynamic>{
      'declaration_id': declaration['declaration_id'],
      'group_id': declaration['group_id'],
      'user_id': declaration['user_id'],
      'date': date,
      'locked_at': declaration['locked_at'],
      'items': json,
      'achievement_rate': json.isEmpty ? 0.0 : _round(done / json.length),
    };
  }

  Map<String, dynamic> _itemJson(Map<String, dynamic> item, String date) {
    final proof = _proofs
        .where((p) =>
            p['declaration_item_id'] == item['declaration_item_id'] &&
            p['deleted_at'] == null)
        .firstOrNull;
    return <String, dynamic>{
      'declaration_item_id': item['declaration_item_id'],
      'todo_id': item['todo_id'],
      'title': item['title_snapshot'],
      'status': _itemStatus(item, date),
      'proof': proof == null ? null : _proofJson(proof),
    };
  }

  /// 미선언 구성원도 함께 내려준다. 빼면 압력 장치가 사라진다.
  List<Map<String, dynamic>> _declarationRows(int groupId, String date) {
    return [
      for (final member in _activeMembers(groupId))
        () {
          final declaration =
              _declarationOf(groupId, member['user_id'] as int, date);
          final items = declaration == null
              ? const <Map<String, dynamic>>[]
              : [
                  for (final e in declaration['items'] as List<dynamic>)
                    _itemJson(Map<String, dynamic>.from(e as Map), date),
                ];
          final done = items.where((e) => e['status'] == 'done').length;
          return <String, dynamic>{
            'user': <String, dynamic>{
              'user_id': member['user_id'],
              'nickname': member['nickname'],
              'profile_image_url': null,
            },
            'declaration_id': declaration?['declaration_id'],
            'date': date,
            'locked_at': declaration?['locked_at'],
            'items': items,
            'achievement_rate':
                items.isEmpty ? 0.0 : _round(done / items.length),
          };
        }(),
    ];
  }

  // --------------------------------------------------------------- 인증·피드

  MockResult _createProof(Map<String, dynamic> group, Object? body) {
    final map = _asMap(body);
    final itemId = map['declaration_item_id'] as int?;
    final declaration = _declarations
        .where((d) => (d['items'] as List<dynamic>).any((e) =>
            (e as Map)['declaration_item_id'] == itemId))
        .firstOrNull;
    if (declaration == null) {
      return MockResult.error(404, 'DECLARATION_NOT_FOUND', '선언 항목을 찾을 수 없어요.');
    }
    if (declaration['user_id'] != _myId) {
      return MockResult.error(403, 'FORBIDDEN', '접근 권한이 없어요.');
    }

    final item = (declaration['items'] as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .firstWhere((e) => e['declaration_item_id'] == itemId);
    if (_itemStatus(item, declaration['date'] as String) != 'done') {
      return MockResult.error(409, 'TODO_NOT_DONE', '완료한 할 일에만 사진을 올릴 수 있어요.');
    }
    final exists = _proofs.any(
      (p) => p['declaration_item_id'] == itemId && p['deleted_at'] == null,
    );
    if (exists) {
      return MockResult.error(422, 'PROOF_ALREADY_EXISTS', '이미 인증한 항목이에요.');
    }

    final proof = <String, dynamic>{
      'post_id': _nextPostId++,
      'declaration_item_id': itemId,
      'group_id': group['group_id'],
      'user_id': _myId,
      'date': declaration['date'],
      'file_key': map['file_key'],
      'caption': map['caption'],
      'created_at': _iso(_today()),
      'deleted_at': null,
    };
    _proofs.add(proof);
    return MockResult(201, <String, dynamic>{'data': _proofJson(proof)});
  }

  Map<String, dynamic> _proofJson(Map<String, dynamic> proof) {
    final postId = proof['post_id'] as int;
    final reactions = <String, int>{};
    String? mine;
    for (final r in _reactions.where((r) => r['post_id'] == postId)) {
      final type = r['type'] as String;
      reactions[type] = (reactions[type] ?? 0) + 1;
      if (r['user_id'] == _myId) mine = type;
    }
    final author = _members
        .where((m) => m['user_id'] == proof['user_id'])
        .firstOrNull;

    return <String, dynamic>{
      'post_id': postId,
      'declaration_item_id': proof['declaration_item_id'],
      'group_id': proof['group_id'],
      'user_id': proof['user_id'],
      'date': proof['date'],
      'file_key': proof['file_key'],
      // 버킷이 없는 상태를 그대로 흉내 낸다. 화면이 자리표시자를 그리는지 확인할 수 있다.
      'image_url': null,
      'caption': proof['caption'],
      'created_at': proof['created_at'],
      'comment_count': _comments
          .where((c) => c['post_id'] == postId && c['deleted_at'] == null)
          .length,
      'reactions': reactions,
      'my_reaction': mine,
      if (author != null)
        'user': <String, dynamic>{
          'user_id': author['user_id'],
          'nickname': author['nickname'],
          'profile_image_url': null,
        },
    };
  }

  /// 날짜 내림차순, 같은 날은 가입 순. 첫 페이지를 부르면 미확인 배지가 내려간다.
  MockResult _feed(int groupId) {
    final rows = _declarations.where((d) => d['group_id'] == groupId).toList()
      ..sort((a, b) {
        final byDate = (b['date'] as String).compareTo(a['date'] as String);
        return byDate != 0
            ? byDate
            : (a['user_id'] as int).compareTo(b['user_id'] as int);
      });

    final entries = <Map<String, dynamic>>[];
    for (final declaration in rows) {
      final date = declaration['date'] as String;
      final items = [
        for (final e in declaration['items'] as List<dynamic>)
          _itemJson(Map<String, dynamic>.from(e as Map), date),
      ];
      final member = _members
          .where((m) => m['user_id'] == declaration['user_id'])
          .firstOrNull;
      final done = items.where((e) => e['status'] == 'done').length;

      entries.add(<String, dynamic>{
        'user': <String, dynamic>{
          'user_id': declaration['user_id'],
          'nickname': member?['nickname'] ?? '',
          'profile_image_url': null,
        },
        'date': date,
        'declaration_id': declaration['declaration_id'],
        'declared_count': items.length,
        'done_count': done,
        'achievement_rate': items.isEmpty ? 0.0 : _round(done / items.length),
        'posts': [
          for (final item in items)
            if (item['proof'] != null) item['proof'] as Map<String, dynamic>,
        ],
        // 못 한 것을 반드시 함께 내려준다.
        'missed_items': [
          for (final item in items)
            if (item['status'] != 'done')
              <String, dynamic>{
                'title': item['title'],
                'status': item['status'],
              },
        ],
      });
    }

    _memberOf(groupId, _myId)?['last_read_at'] = _iso(_today());
    return MockResult(200, <String, dynamic>{
      'data': entries,
      'page': <String, dynamic>{'next_cursor': null, 'has_next': false},
    });
  }

  // --------------------------------------------------------------- 랭킹·스트릭

  Map<String, dynamic> _ranking(int groupId, String period) {
    final today = FixtureLoader.parseDate(_today());
    final (first, last) = switch (period) {
      'month' => (
          DateTime(today.year, today.month, 1),
          DateTime(today.year, today.month + 1, 0),
        ),
      'all' => (today.subtract(const Duration(days: 90)), today),
      // 이번 주 월~일. 통계 탭의 "최근 7일" 과 다른 규칙이다.
      _ => (
          today.subtract(Duration(days: today.weekday - 1)),
          today.add(Duration(days: 7 - today.weekday)),
        ),
    };

    final entries = <Map<String, dynamic>>[];
    for (final member in _activeMembers(groupId)) {
      final userId = member['user_id'] as int;
      final days = <String>{};
      var total = 0;
      var done = 0;
      for (final declaration in _declarations.where(
        (d) => d['group_id'] == groupId && d['user_id'] == userId,
      )) {
        final date = declaration['date'] as String;
        final parsed = FixtureLoader.parseDate(date);
        if (parsed.isBefore(first) || parsed.isAfter(last)) continue;
        days.add(date);
        for (final e in declaration['items'] as List<dynamic>) {
          total++;
          if (_itemStatus(Map<String, dynamic>.from(e as Map), date) == 'done') {
            done++;
          }
        }
      }
      entries.add(<String, dynamic>{
        'user_id': userId,
        'nickname': member['nickname'],
        'profile_image_url': null,
        'achievement_rate': total == 0 ? 0.0 : _round(done / total),
        'declared_days': days.length,
        'declared_items': total,
        'completed_items': done,
        'streak': userId == _myId ? _currentStreak() : 3,
      });
    }

    entries.sort((a, b) {
      final byRate = (b['achievement_rate'] as double)
          .compareTo(a['achievement_rate'] as double);
      if (byRate != 0) return byRate;
      final byDays =
          (b['declared_days'] as int).compareTo(a['declared_days'] as int);
      return byDays != 0 ? byDays : (a['user_id'] as int).compareTo(b['user_id'] as int);
    });

    final rankings = <Map<String, dynamic>>[];
    List<Object?>? previous;
    var rank = 0;
    for (var i = 0; i < entries.length; i++) {
      final key = <Object?>[
        entries[i]['achievement_rate'],
        entries[i]['declared_days'],
      ];
      if (previous == null || key[0] != previous[0] || key[1] != previous[1]) {
        rank = i + 1;
        previous = key;
      }
      rankings.add(<String, dynamic>{'rank': rank, ...entries[i]});
    }

    return <String, dynamic>{
      'period': period,
      'range': <String, dynamic>{
        'from': FixtureLoader.formatDate(first),
        'to': FixtureLoader.formatDate(last),
      },
      'rankings': rankings,
      'my_rank': rankings
          .where((e) => e['user_id'] == _myId)
          .map((e) => e['rank'])
          .firstOrNull,
    };
  }

  Map<String, dynamic> _streak(Map<String, dynamic> group) {
    final groupId = group['group_id'] as int;
    final today = _today();
    final declarations = _declarations
        .where((d) => d['group_id'] == groupId && d['date'] == today)
        .toList();

    var completed = 0;
    var unrecoverable = false;
    for (final declaration in declarations) {
      final statuses = [
        for (final e in declaration['items'] as List<dynamic>)
          _itemStatus(Map<String, dynamic>.from(e as Map), today),
      ];
      if (statuses.isNotEmpty && statuses.every((s) => s == 'done')) completed++;
      if (statuses.any((s) => s == 'deferred' || s == 'skipped')) {
        unrecoverable = true;
      }
    }

    final success = declarations.isNotEmpty && completed == declarations.length;
    return <String, dynamic>{
      'group_streak': group['group_streak'],
      'last_success_date': group['last_streak_date'],
      'today_status': success
          ? 'success'
          : unrecoverable
              ? 'broken'
              : 'in_progress',
      'declared_members_today': declarations.length,
      'members_completed_today': completed,
      'members_total': _activeMembers(groupId).length,
    };
  }

  // -------------------------------------------------------------- 댓글·리액션

  MockResult _handlePosts(
    String method,
    List<String> segments,
    Map<String, dynamic> query,
    Object? body,
  ) {
    final postId = int.tryParse(segments.length > 1 ? segments[1] : '');
    final proof = _proofs
        .where((p) => p['post_id'] == postId && p['deleted_at'] == null)
        .firstOrNull;
    if (proof == null) {
      return MockResult.error(404, 'POST_NOT_FOUND', '게시물을 찾을 수 없어요.');
    }

    final tail = segments.length > 2 ? segments[2] : '';
    return switch ((method, tail)) {
      ('GET', '') => MockResult(200, <String, dynamic>{'data': _proofJson(proof)}),
      ('DELETE', '') => _deletePost(proof),
      ('GET', 'comments') => MockResult(200, <String, dynamic>{
          'data': [
            for (final c in _comments.where(
              (c) => c['post_id'] == postId && c['deleted_at'] == null,
            ))
              _commentJson(c),
          ],
          'page': <String, dynamic>{'next_cursor': null, 'has_next': false},
        }),
      ('POST', 'comments') => _addComment(postId!, body),
      ('PUT', 'reactions') => _setReaction(postId!, body),
      ('DELETE', 'reactions') => _clearReaction(postId!),
      _ => MockResult.error(404, 'NOT_FOUND', '요청한 경로를 찾을 수 없어요.'),
    };
  }

  MockResult _deletePost(Map<String, dynamic> proof) {
    if (proof['user_id'] != _myId) {
      return MockResult.error(403, 'FORBIDDEN', '접근 권한이 없어요.');
    }
    proof['deleted_at'] = _iso(_today());
    return const MockResult(204);
  }

  MockResult _addComment(int postId, Object? body) {
    final content = (_asMap(body)['content'] as String? ?? '').trim();
    if (content.isEmpty) {
      return MockResult.error(400, 'VALIDATION_ERROR', '입력값을 확인해 주세요.',
          details: <String, dynamic>{'content': '필수 항목이에요.'});
    }
    final comment = <String, dynamic>{
      'comment_id': _nextCommentId++,
      'post_id': postId,
      'user_id': _myId,
      'content': content,
      'created_at': _iso(_today()),
      'deleted_at': null,
    };
    _comments.add(comment);
    return MockResult(201, <String, dynamic>{'data': _commentJson(comment)});
  }

  Map<String, dynamic> _commentJson(Map<String, dynamic> comment) {
    final author = _members
        .where((m) => m['user_id'] == comment['user_id'])
        .firstOrNull;
    return <String, dynamic>{
      'comment_id': comment['comment_id'],
      'post_id': comment['post_id'],
      'user': <String, dynamic>{
        'user_id': comment['user_id'],
        'nickname': author?['nickname'] ?? _myNickname,
        'profile_image_url': null,
      },
      'content': comment['content'],
      'created_at': comment['created_at'],
    };
  }

  MockResult _handleComments(String method, List<String> segments) {
    if (method != 'DELETE' || segments.length != 2) {
      return MockResult.error(404, 'NOT_FOUND', '요청한 경로를 찾을 수 없어요.');
    }
    final id = int.tryParse(segments[1]);
    final comment = _comments
        .where((c) => c['comment_id'] == id && c['deleted_at'] == null)
        .firstOrNull;
    if (comment == null) {
      return MockResult.error(404, 'COMMENT_NOT_FOUND', '댓글을 찾을 수 없어요.');
    }
    if (comment['user_id'] != _myId) {
      return MockResult.error(403, 'FORBIDDEN', '접근 권한이 없어요.');
    }
    comment['deleted_at'] = _iso(_today());
    return const MockResult(204);
  }

  /// 사용자당 1개. 다른 종류를 보내면 교체된다.
  MockResult _setReaction(int postId, Object? body) {
    const allowed = <String>{'fire', 'clap', 'heart', 'muscle'};
    final type = _asMap(body)['type'] as String? ?? '';
    if (!allowed.contains(type)) {
      return MockResult.error(400, 'VALIDATION_ERROR', '입력값을 확인해 주세요.',
          details: <String, dynamic>{'type': '선택할 수 없는 값이에요.'});
    }
    final existing = _reactions
        .where((r) => r['post_id'] == postId && r['user_id'] == _myId)
        .firstOrNull;
    if (existing == null) {
      _reactions.add(<String, dynamic>{
        'reaction_id': _nextReactionId++,
        'post_id': postId,
        'user_id': _myId,
        'type': type,
      });
    } else {
      existing['type'] = type;
    }
    return MockResult(200, <String, dynamic>{'data': _tally(postId)});
  }

  MockResult _clearReaction(int postId) {
    _reactions.removeWhere(
      (r) => r['post_id'] == postId && r['user_id'] == _myId,
    );
    return const MockResult(204);
  }

  Map<String, dynamic> _tally(int postId) {
    final counts = <String, int>{};
    String? mine;
    for (final r in _reactions.where((r) => r['post_id'] == postId)) {
      final type = r['type'] as String;
      counts[type] = (counts[type] ?? 0) + 1;
      if (r['user_id'] == _myId) mine = type;
    }
    return <String, dynamic>{
      'post_id': postId,
      'reactions': counts,
      'my_reaction': mine,
    };
  }

  // ------------------------------------------------------------------ 업로드

  /// 실서버와 같이 스토리지 자격증명이 없는 상태를 흉내 낸다.
  /// 인증샷 기능 자체는 file_key 만 있으면 도므로 화면은 끝까지 확인할 수 있다.
  MockResult _handleUploads(List<String> segments) {
    if (segments.length == 2 && segments[1] == 'presign') {
      return MockResult.error(
          503, 'STORAGE_UNAVAILABLE', '사진 업로드가 아직 설정되지 않았어요.');
    }
    return MockResult.error(404, 'NOT_FOUND', '요청한 경로를 찾을 수 없어요.');
  }

  // -------------------------------------------------------------------- 도구

  static Map<String, dynamic> _asMap(Object? body) =>
      body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};

  static double _round(double value) =>
      double.parse(value.toStringAsFixed(2));

  static String _shift(String date, int days) => FixtureLoader.formatDate(
        FixtureLoader.parseDate(date).add(Duration(days: days)),
      );

  static String _iso(String date) => '${date}T09:00:00+09:00';

  static String _code(int seed) {
    const alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    var value = seed.abs();
    final buffer = StringBuffer();
    for (var i = 0; i < 4; i++) {
      buffer.write(alphabet[value % alphabet.length]);
      value = value ~/ alphabet.length + 7;
    }
    return buffer.toString();
  }
}
