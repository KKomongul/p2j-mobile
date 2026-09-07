import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../data/auth_models.dart';
import '../data/auth_repository.dart';

part 'auth_controller.g.dart';

/// 앱 전역 인증 상태이자 로그인한 사용자 정보.
///
/// 상태가 null 이면 비로그인이다. AsyncLoading 이면 자동 로그인 판정 중이라
/// 스플래시를 보여준다. 라우터가 이 값 하나만 보고 리다이렉트한다.
///
/// 로그인/회원가입 응답에 사용자 정보가 함께 오므로 그때는 /auth/me 를 부르지
/// 않는다. 저장된 토큰으로 앱을 다시 켰을 때만 한 번 부른다.
@Riverpod(keepAlive: true)
class AuthController extends _$AuthController {
  @override
  Future<User?> build() async {
    // 재발급까지 실패해 세션이 끊기면 로그인 화면으로 되돌린다.
    ref.listen<int>(sessionExpiredSignalProvider, (previous, next) {
      if (previous == null || previous == next) return;
      state = const AsyncData(null);
    });

    final repository = ref.watch(authRepositoryProvider);
    if (!await repository.hasStoredSession()) return null;

    try {
      return await repository.fetchMe();
    } on ApiException catch (error) {
      // 세션이 죽었으면 재시도해도 결과가 같다. 토큰을 지우고 인트로로 보낸다.
      // 스플래시의 '다시 시도'가 영원히 실패하는 막다른 길이 되지 않게 한다.
      if (!error.isSessionExpired) rethrow;
      await repository.clearSession();
      return null;
    }
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    final session = await ref.read(authRepositoryProvider).login(
          email: email,
          password: password,
        );
    state = AsyncData(session.user);
  }

  Future<void> signup({
    required String email,
    required String password,
    required String nickname,
  }) async {
    final session = await ref.read(authRepositoryProvider).signup(
          email: email,
          password: password,
          nickname: nickname,
        );
    state = AsyncData(session.user);
  }

  Future<void> logout() async {
    // 서버 호출이 실패해도 로컬 세션은 반드시 끊는다.
    // 오프라인에서 '다른 계정으로 로그인'을 눌렀는데 아무 일도 안 일어나면 안 된다.
    try {
      await ref.read(authRepositoryProvider).logout();
    } on ApiException {
      // Repository 가 finally 로 토큰을 이미 지웠다.
    }
    state = const AsyncData(null);
  }

  /// 백그라운드에서 복귀했을 때 오늘 날짜가 넘어갔는지 다시 확인한다.
  /// 실패하면 기존 정보를 유지한다. 화면을 흔들 이유가 없다.
  Future<void> refreshToday() async {
    if (state.value == null) return;
    try {
      state = AsyncData(await ref.read(authRepositoryProvider).fetchMe());
    } on ApiException {
      return;
    }
  }
}

/// 서버가 준 오늘 날짜(YYYY-MM-DD). 날짜 기반 조회는 전부 이 값을 쓴다.
@Riverpod(keepAlive: true)
String? serverToday(Ref ref) =>
    ref.watch(authControllerProvider).value?.today;
