import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../config/app_config.dart';
import '../storage/token_storage.dart';
import 'api_exception.dart';
import 'auth_interceptor.dart';
import 'error_interceptor.dart';
import 'mock_interceptor.dart';

part 'dio_client.g.dart';

/// Repository 가 쓰는 유일한 HTTP 진입점.
///
/// DioException 을 [ApiException] 으로 바꿔서 내보내므로, 이 바깥에서는
/// dio 타입을 몰라도 된다.
class ApiClient {
  const ApiClient(this._dio);

  final Dio _dio;

  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) =>
      _guard(() => _dio.get<dynamic>(path, queryParameters: query));

  Future<Response<dynamic>> post(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
  }) =>
      _guard(
        () => _dio.post<dynamic>(path, data: data, queryParameters: query),
      );

  Future<Response<dynamic>> patch(String path, {Object? data}) =>
      _guard(() => _dio.patch<dynamic>(path, data: data));

  /// 서버에서 PUT 은 UPSERT 다. 리액션은 사용자당 1개라 다시 보내면 교체된다.
  Future<Response<dynamic>> put(String path, {Object? data}) =>
      _guard(() => _dio.put<dynamic>(path, data: data));

  Future<Response<dynamic>> delete(String path) =>
      _guard(() => _dio.delete<dynamic>(path));

  Future<Response<dynamic>> _guard(
    Future<Response<dynamic>> Function() send,
  ) async {
    try {
      return await send();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}

BaseOptions _baseOptions() => BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
      validateStatus: (status) =>
          status != null && status >= 200 && status < 300,
    );

/// Dio 인스턴스 하나를 조립한다.
///
/// 등록 순서가 중요하다.
/// - 요청 흐름: Mock 이 먼저 가로채 응답을 만들고 끝낸다.
/// - 에러 흐름: Auth 가 원본 401 을 먼저 보고 재발급을 판단한 뒤,
///   Error 가 ApiException 으로 바꾼다.
Dio buildDio({
  required TokenStorage tokenStorage,
  required void Function() onSessionExpired,
}) {
  final dio = Dio(_baseOptions());

  // 재발급 전용. AuthInterceptor 를 달지 않아 재귀 호출이 생기지 않는다.
  final refreshDio = Dio(_baseOptions());

  final authInterceptor = AuthInterceptor(
    tokenStorage: tokenStorage,
    refreshDio: refreshDio,
    onSessionExpired: onSessionExpired,
  )..retryDio = dio;

  if (AppConfig.useMock) {
    dio.interceptors.add(MockInterceptor(scenario: AppConfig.mockScenario));
    refreshDio.interceptors
        .add(MockInterceptor(scenario: AppConfig.mockScenario));
  }

  dio.interceptors.add(authInterceptor);
  dio.interceptors.add(ErrorInterceptor());
  refreshDio.interceptors.add(ErrorInterceptor());

  return dio;
}

@Riverpod(keepAlive: true)
TokenStorage tokenStorage(Ref ref) => TokenStorage();

/// 재발급까지 실패했을 때 울리는 신호.
///
/// AuthInterceptor 가 AuthController 를 직접 참조하면 순환이 생긴다.
/// 그래서 값 하나만 올리는 프로바이더를 중간에 둔다.
@Riverpod(keepAlive: true)
class SessionExpiredSignal extends _$SessionExpiredSignal {
  @override
  int build() => 0;

  void trigger() => state = state + 1;
}

@Riverpod(keepAlive: true)
ApiClient apiClient(Ref ref) {
  final dio = buildDio(
    tokenStorage: ref.watch(tokenStorageProvider),
    onSessionExpired: () =>
        ref.read(sessionExpiredSignalProvider.notifier).trigger(),
  );
  ref.onDispose(dio.close);
  return ApiClient(dio);
}
