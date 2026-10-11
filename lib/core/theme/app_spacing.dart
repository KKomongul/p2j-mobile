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
/// 화면 단위 카드(회색 바탕 위 흰 면)는 16dp, 그 안의 작은 요소(버튼 · 입력칸 · 타일)는
/// 8dp 로 한 단계 작게 굴린다. pill 은 칩과 태그에만 쓴다.
abstract final class AppRadius {
  /// 체크박스, 작은 배지, 진행률 트랙.
  static const double r4 = 4;

  /// 기본값. 입력칸 · 버튼 · 카드 안의 타일.
  static const double r8 = 8;

  /// 화면 단위 카드, 바텀시트 상단처럼 화면을 덮는 면.
  static const double r16 = 16;

  /// 알약. **상태 칩과 태그 전용.**
  static const double pill = 999;
}
