/// P2J 디자인 토큰 — 스페이싱. 4의 배수만 쓴다.
///
/// 이름이 곧 값이라 헷갈릴 여지가 없다.
abstract final class AppSpacing {
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double s40 = 40;

  /// 화면 좌우 기본 여백.
  static const double screenH = s20;
}

/// P2J 디자인 토큰 — 라운드.
///
/// 종이를 오려 붙인 느낌이라 모서리를 크게 굴리지 않는다.
/// 카드는 8dp 이하, pill 은 칩과 태그에만 쓴다.
abstract final class AppRadius {
  /// 체크박스, 작은 배지, 진행률 트랙.
  static const double r4 = 4;

  /// 기본값. 카드 · 입력칸 · 버튼.
  static const double r8 = 8;

  /// 바텀시트 상단처럼 화면을 덮는 면.
  static const double r16 = 16;

  /// 알약. **상태 칩과 태그 전용.**
  static const double pill = 999;
}
