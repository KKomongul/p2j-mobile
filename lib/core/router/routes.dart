/// 라우트 경로 상수. 화면 코드에서 문자열을 직접 쓰지 않는다.
abstract final class Routes {
  static const String splash = '/';
  /// 가입과 로그인을 모두 여기서 한다. 별도 로그인 경로를 두지 않는다.
  static const String onboarding = '/onboarding';

  static const String home = '/home';
  static const String goals = '/goals';
  static const String group = '/group';
  static const String stats = '/stats';
}
