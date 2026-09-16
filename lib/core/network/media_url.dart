import '../config/app_config.dart';

/// 서버가 준 이미지 주소를 `Image.network` 가 쓸 수 있는 절대 URL 로 바꾼다.
///
/// 서버는 스토리지 드라이버에 따라 두 가지를 준다.
///
/// - **절대 URL** — Firebase 같은 외부 스토리지. 그대로 쓴다.
/// - **상대 경로**(`/files/...`) — 서버가 직접 들고 있는 경우. 서버는 자기 공개 주소를
///   모른다(에뮬레이터는 10.0.2.2, 배포는 도메인). 대신 우리가 API base URL 을 안다.
///
/// base URL 에 `/v1` 이 이미 들어 있고 서버가 주는 경로에는 없다. 그래서 그냥 이어 붙인다.
String? absoluteMediaUrl(String? url) {
  if (url == null || url.isEmpty) return null;
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  final base = AppConfig.baseUrl;
  final path = url.startsWith('/') ? url : '/$url';
  return base.endsWith('/') ? '${base.substring(0, base.length - 1)}$path' : '$base$path';
}
