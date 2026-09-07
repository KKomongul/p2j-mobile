import 'package:dio/dio.dart';

/// 서버가 내려주는 error.code 목록.
///
/// 서버 `app/core/errors.py` 의 카탈로그와 1:1 로 맞춘다.
/// 서버가 코드를 추가하면 모르는 값은 [unknown] 으로 떨어지므로 앱이 깨지지는 않는다.
/// 다만 화면에서 분기해야 하는 코드는 여기에 추가해야 한다.
enum ApiErrorCode {
  // --- 400 ---
  validationError('VALIDATION_ERROR'),
  weakPassword('WEAK_PASSWORD'),

  // --- 401 ---
  invalidCredentials('INVALID_CREDENTIALS'),
  tokenExpired('TOKEN_EXPIRED'),
  unauthorized('UNAUTHORIZED'),

  // --- 403 ---
  forbidden('FORBIDDEN'),
  notGroupMember('NOT_GROUP_MEMBER'),
  notGroupAdmin('NOT_GROUP_ADMIN'),

  // --- 404 ---
  notFound('NOT_FOUND'),
  todoNotFound('TODO_NOT_FOUND'),
  goalNotFound('GOAL_NOT_FOUND'),
  groupNotFound('GROUP_NOT_FOUND'),
  declarationNotFound('DECLARATION_NOT_FOUND'),
  userNotFound('USER_NOT_FOUND'),

  // --- 405 ---
  methodNotAllowed('METHOD_NOT_ALLOWED'),

  // --- 409 ---
  emailAlreadyExists('EMAIL_ALREADY_EXISTS'),
  alreadyMember('ALREADY_MEMBER'),
  declarationAlreadyExists('DECLARATION_ALREADY_EXISTS'),
  todoAlreadyDone('TODO_ALREADY_DONE'),
  todoNotDone('TODO_NOT_DONE'),

  // --- 413 · 415 ---
  fileTooLarge('FILE_TOO_LARGE'),
  unsupportedFileType('UNSUPPORTED_FILE_TYPE'),

  // --- 422 ---
  declaredTodoLocked('DECLARED_TODO_LOCKED'),
  declarationClosed('DECLARATION_CLOSED'),
  declarationEmpty('DECLARATION_EMPTY'),
  groupFull('GROUP_FULL'),
  invalidInviteCode('INVALID_INVITE_CODE'),
  inviteCodeExpired('INVITE_CODE_EXPIRED'),
  adminMustTransfer('ADMIN_MUST_TRANSFER'),
  cannotKickSelf('CANNOT_KICK_SELF'),

  // --- 429 ---
  aiQuotaExceeded('AI_QUOTA_EXCEEDED'),
  rateLimited('RATE_LIMITED'),

  // --- 500 · 503 ---
  internalError('INTERNAL_ERROR'),
  aiUnavailable('AI_UNAVAILABLE'),
  storageUnavailable('STORAGE_UNAVAILABLE'),
  healthCheckFailed('HEALTH_CHECK_FAILED'),

  /// 이하는 서버 코드가 아니라 클라이언트가 붙이는 값이다.
  network('__NETWORK__'),
  timeout('__TIMEOUT__'),
  server('__SERVER__'),
  cancelled('__CANCELLED__'),
  unknown('__UNKNOWN__');

  const ApiErrorCode(this.wire);

  final String wire;

  /// 저장된 세션이 더는 쓸 수 없다는 뜻. 재시도해도 소용없고 다시 로그인해야 한다.
  ///
  /// [invalidCredentials] 는 빠져 있다. 그건 방금 입력한 비밀번호가 틀렸다는 뜻이라
  /// 세션을 지울 이유가 없다. AuthInterceptor 도 같은 이유로 이 코드는 재발급하지 않는다.
  bool get isSessionExpired =>
      this == ApiErrorCode.unauthorized || this == ApiErrorCode.tokenExpired;

  static ApiErrorCode fromWire(String? code) {
    if (code == null) return unknown;
    for (final value in values) {
      if (value.wire == code) return value;
    }
    return unknown;
  }
}

/// 화면이 다루는 유일한 네트워크 예외 타입.
///
/// DioException 은 ApiClient 바깥으로 나가지 않는다.
class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    this.statusCode,
    this.details = const <String, dynamic>{},
    this.rawCode,
  });

  final ApiErrorCode code;

  /// 사용자에게 그대로 보여줄 수 있는 한국어 문구.
  final String message;
  final int? statusCode;

  /// VALIDATION_ERROR 의 필드별 메시지 등.
  final Map<String, dynamic> details;

  /// 서버가 보낸 원본 코드. unknown 으로 떨어졌을 때 로그로 확인한다.
  final String? rawCode;

  bool get isNetworkProblem =>
      code == ApiErrorCode.network || code == ApiErrorCode.timeout;

  /// 저장된 세션이 더는 유효하지 않다. 재시도해도 결과가 같으니 다시 로그인해야 한다.
  ///
  /// 서버가 새 401 코드를 쓰기 시작해도 놓치지 않도록 상태 코드로도 한 번 더 본다.
  /// invalidCredentials 는 방금 입력한 비밀번호가 틀렸다는 뜻이라 제외한다.
  bool get isSessionExpired =>
      code.isSessionExpired ||
      (statusCode == 401 && code != ApiErrorCode.invalidCredentials);

  /// 특정 입력 필드에 붙일 메시지. 없으면 null.
  String? fieldMessage(String field) {
    final value = details[field];
    if (value is String) return value;
    if (value is List && value.isNotEmpty) return '${value.first}';
    return null;
  }

  /// DioException 을 ApiException 으로 바꾼다. 이미 변환됐으면 그대로 돌려준다.
  factory ApiException.fromDio(DioException error) {
    final attached = error.error;
    if (attached is ApiException) return attached;

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const ApiException(
          code: ApiErrorCode.timeout,
          message: '응답이 너무 오래 걸려요. 잠시 후 다시 시도하세요.',
        );
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        return const ApiException(
          code: ApiErrorCode.network,
          message: '네트워크에 연결할 수 없어요. 연결 상태를 확인하고 다시 시도하세요.',
        );
      case DioExceptionType.cancel:
        return const ApiException(
          code: ApiErrorCode.cancelled,
          message: '요청이 취소됐어요.',
        );
      case DioExceptionType.badCertificate:
        return const ApiException(
          code: ApiErrorCode.network,
          message: '보안 연결에 실패했어요. 네트워크를 바꿔서 다시 시도하세요.',
        );
      case DioExceptionType.badResponse:
        return ApiException.fromResponse(error.response);
    }
  }

  /// { "error": { "code": ..., "message": ..., "details": {} } } 를 해석한다.
  factory ApiException.fromResponse(Response<dynamic>? response) {
    final status = response?.statusCode;
    final body = response?.data;

    Map<String, dynamic>? errorBody;
    if (body is Map<String, dynamic> && body['error'] is Map) {
      errorBody = Map<String, dynamic>.from(body['error'] as Map);
    }

    final rawCode = errorBody?['code'] as String?;
    final code = ApiErrorCode.fromWire(rawCode);
    final serverMessage = errorBody?['message'] as String?;
    final details = errorBody?['details'] is Map
        ? Map<String, dynamic>.from(errorBody!['details'] as Map)
        : const <String, dynamic>{};

    return ApiException(
      code: code == ApiErrorCode.unknown ? _fallbackCode(status) : code,
      message: serverMessage ?? _fallbackMessage(status),
      statusCode: status,
      details: details,
      rawCode: rawCode,
    );
  }

  static ApiErrorCode _fallbackCode(int? status) {
    if (status != null && status >= 500) return ApiErrorCode.server;
    return ApiErrorCode.unknown;
  }

  static String _fallbackMessage(int? status) {
    if (status != null && status >= 500) {
      return '서버에 문제가 생겼어요. 잠시 후 다시 시도하세요.';
    }
    return '요청을 처리하지 못했어요. 다시 시도하세요.';
  }

  @override
  String toString() =>
      'ApiException(${rawCode ?? code.wire}, status: $statusCode, $message)';
}
