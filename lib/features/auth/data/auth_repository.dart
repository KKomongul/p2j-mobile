import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/storage/token_storage.dart';
import 'auth_api.dart';
import 'auth_models.dart';

part 'auth_repository.g.dart';

/// 인증 저장소.
///
/// 나중에 테스트에서 가짜 구현으로 갈아끼울 수 있도록 인터페이스를 분리한다.
abstract interface class AuthRepository {
  Future<AuthSession> signup({
    required String email,
    required String password,
    required String nickname,
  });

  Future<AuthSession> login({
    required String email,
    required String password,
  });

  Future<User> fetchMe();

  Future<void> logout();

  Future<bool> hasStoredSession();

  /// 서버를 부르지 않고 로컬 토큰만 지운다.
  ///
  /// 이미 401 을 받아 세션이 죽은 게 확인된 상황에서 쓴다.
  /// logout() 은 서버에 refresh 무효화를 요청하는데, 그 토큰이 이미 거절당한 뒤라 의미가 없다.
  Future<void> clearSession();
}

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl({
    required AuthApi api,
    required TokenStorage tokenStorage,
  })  : _api = api,
        _tokenStorage = tokenStorage;

  final AuthApi _api;
  final TokenStorage _tokenStorage;

  @override
  Future<AuthSession> signup({
    required String email,
    required String password,
    required String nickname,
  }) async {
    final session = await _api.signup(
      email: email,
      password: password,
      nickname: nickname,
    );
    await _store(session);
    return session;
  }

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final session = await _api.login(email: email, password: password);
    await _store(session);
    return session;
  }

  @override
  Future<User> fetchMe() => _api.fetchMe();

  @override
  Future<void> logout() async {
    // 서버 호출이 실패해도 로컬 토큰은 반드시 지운다.
    try {
      await _api.logout();
    } finally {
      await _tokenStorage.clear();
    }
  }

  @override
  Future<bool> hasStoredSession() => _tokenStorage.hasSession();

  @override
  Future<void> clearSession() => _tokenStorage.clear();

  Future<void> _store(AuthSession session) => _tokenStorage.save(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
      );
}

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) => AuthRepositoryImpl(
      api: AuthApi(ref.watch(apiClientProvider)),
      tokenStorage: ref.watch(tokenStorageProvider),
    );
