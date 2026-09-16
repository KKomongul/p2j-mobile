/// 서버가 주는 이미지 주소를 절대 URL 로 바꾸는 규칙.
///
/// 스토리지 드라이버마다 모양이 다르다. 여기서 갈라지면 사진이 안 뜨는데
/// 화면에서는 "그냥 자리표시자" 로 보여서 원인을 찾기 어렵다.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:p2j_mobile/core/config/app_config.dart';
import 'package:p2j_mobile/core/network/media_url.dart';

void main() {
  test('null 과 빈 문자열은 그대로 null', () {
    expect(absoluteMediaUrl(null), isNull);
    expect(absoluteMediaUrl(''), isNull);
  });

  test('절대 URL 은 손대지 않는다 (Firebase 드라이버)', () {
    const url =
        'https://firebasestorage.googleapis.com/v0/b/p2j.appspot.com/o/a.jpg?alt=media';
    expect(absoluteMediaUrl(url), url);
    expect(absoluteMediaUrl('http://cdn.example.com/a.jpg'),
        'http://cdn.example.com/a.jpg');
  });

  test('상대 경로는 API base URL 에 이어 붙인다 (local 드라이버)', () {
    // base URL 에 이미 /v1 이 들어 있고 서버가 주는 경로에는 없다.
    final resolved = absoluteMediaUrl('/files/proofs/2026/09/16/abc.jpg');
    expect(resolved, '${AppConfig.baseUrl}/files/proofs/2026/09/16/abc.jpg');
    expect(resolved, startsWith('http'));
    // 슬래시가 겹치지 않는다.
    expect(resolved!.contains('//files'), isFalse);
  });

  test('앞 슬래시가 없어도 붙여 준다', () {
    expect(
      absoluteMediaUrl('files/a.jpg'),
      '${AppConfig.baseUrl}/files/a.jpg',
    );
  });
}
