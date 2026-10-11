import 'package:flutter/material.dart';

/// P2J 디자인 토큰 — 컬러.
///
/// 팔레트는 마스코트 플랜펭에서 뽑았다. 네이비 몸통, 라벤더 소품, 앰버 발,
/// 크림색 종이. 그래서 일러스트가 화면에 얹혔을 때 겉돌지 않는다.
///
/// 분위기는 **정돈된 회색 바탕 + 흰 카드**다. 회색 배경([background]) 위에 흰 카드
/// ([paper] = [surface])를 쌓고, 층은 그림자가 아니라 색으로 나눈다. 따뜻한 색(앰버 ·
/// 민트 · 라벤더)은 면을 칠하지 않고 **상태와 보상**에만 쓴다. 인트로 · 스플래시처럼
/// 네이비가 화면 전체인 곳은 그대로다.
///
/// 처음에는 크림색 종이 질감이었다. 그룹 · 통계를 여러 사람의 현황을 훑는 화면으로
/// 다시 그리면서 앱 전체를 같은 톤으로 맞췄다.
///
/// 파스텔은 **면(fill)** 으로 쓰고, 글자·아이콘·얇은 선에는 같은 계열의
/// 짙은 짝(`~Ink`)을 쓴다. 파스텔을 그대로 텍스트에 쓰면 대비가 안 나온다.
/// 아래 대비 수치는 모두 [background] 위 기준이다.
abstract final class AppColors {
  // ---------------------------------------------------------------- 종이

  /// 앱 배경. 옅은 중성 회색. 순백이 아니라서 흰 카드가 뜬다.
  static const Color background = Color(0xFFF3F3F6);

  /// 카드 면. 회색 배경 위의 흰 카드. ([PaperCard] 의 기본색)
  static const Color paper = Color(0xFFFFFFFF);

  /// 장식 없는 평면. 목록, 바텀시트처럼 빠르게 읽어야 하는 곳.
  static const Color surface = Color(0xFFFFFFFF);

  /// 입력칸, 진행률 트랙, 중립 칩 같은 옅은 채움. 흰 면 위에서 쓴다.
  static const Color fill = Color(0xFFF0F0F4);

  /// 구분선. 흰 카드 안에서 튀지 않을 만큼만.
  static const Color line = Color(0xFFE6E6EC);

  // ---------------------------------------------------------------- 잉크

  /// 본문, 큰 숫자, 제목. 그리고 네이비 면 자체. 대비 12.3:1.
  static const Color ink = Color(0xFF292E50);

  /// 보조 네이비. 부제, 두 번째 줄. 대비 10.6:1.
  static const Color inkSub = Color(0xFF3C4064);

  /// 보조 텍스트, 라벨. 대비 4.7:1.
  static const Color muted = Color(0xFF6B6E88);

  /// 비활성 텍스트, placeholder. 비활성 요소라 대비 기준 밖.
  static const Color disabled = Color(0xFFA8AABB);

  // ------------------------------------------------------- 네이비 면 위

  /// 인트로·스플래시처럼 화면 전체가 네이비인 곳의 바탕.
  static const Color navy = ink;

  /// 네이비 면 위 본문. 대비 12.3:1.
  static const Color onNavy = Color(0xFFFAF7F4);

  /// 네이비 면 위 보조 텍스트. 대비 5.9:1.
  static const Color onNavyMuted = Color(0xFFB9BCCE);

  /// 네이비 면 위 옅은 채움. 선택지 버튼, 트랙.
  static const Color navyFill = Color(0xFF3C4064);

  // ------------------------------------------------------------ 포인트

  /// 주요 포인트. 링크, 선택 상태, 진행 중 표시. 대비 4.8:1 이라 글자에 써도 된다.
  static const Color purple = Color(0xFF7B658F);

  /// 밝은 라벤더. **면으로만** 쓴다. 글자에 쓰지 않는다.
  static const Color lavender = Color(0xFFC8AFD2);

  /// 포인트 계열 옅은 면. 칩 배경, 선택된 행.
  static const Color purpleSurface = Color(0xFFF0EAF3);

  // ------------------------------------------------------ 강조 · 보상

  /// 앰버. 달성·보상·연속 기록. **면으로 쓴다.** 배경 위 대비 1.9:1 이라
  /// 얇은 선이나 아이콘으로 쓰면 안 보인다.
  static const Color amber = Color(0xFFEDA85E);

  /// 앰버 면의 그림자 쪽. 종이 층을 나눌 때.
  static const Color amberShade = Color(0xFFE6974D);

  /// 앰버 면의 밝은 쪽. 빛이 닿는 위쪽.
  static const Color amberLight = Color(0xFFF4C48A);

  /// 앰버 계열 옅은 면. 배지, 트랙.
  static const Color amberSurface = Color(0xFFFBEEDD);

  /// 앰버 계열 글자·아이콘용. 배경 위 대비 5.1:1.
  static const Color amberInk = Color(0xFF9A5A1B);

  /// 앰버 면 **위** 본문. 대비 6.5:1.
  static const Color onAmber = ink;

  /// 앰버 면 위 보조 텍스트. 대비 4.9:1.
  static const Color onAmberMuted = inkSub;

  // ------------------------------------------------------------ 상태

  /// 완료·성공. **면으로 쓴다.** 배경 위 대비 2.3:1.
  static const Color mint = Color(0xFF92AC91);

  /// 완료 계열 옅은 면. 완료 칩 배경.
  static const Color mintSurface = Color(0xFFE9F0E9);

  /// 완료 계열 글자·아이콘용. 배경 위 대비 5.5:1.
  static const Color mintInk = Color(0xFF4F6B4E);

  /// 오류, 녹음 중, 파괴적 액션. 절제된 코랄. 대비 5.1:1.
  static const Color coral = Color(0xFFAD4C39);

  /// 오류 배너 배경.
  static const Color coralSurface = Color(0xFFF9EDEA);

  // ------------------------------------------------------- 정돈된 면

  /// 흰 화면([surface]) 위의 옅은 회색 면. 타일 · 하단 툴바 · 통계 패널.
  /// 배경([background])과 같은 값이다 — 흰 면 안에 "바탕이 비쳐 보이는" 칸.
  static const Color neutralFill = background;

  /// 흰 화면 위 구분선 · 타일 테두리. [line] 과 같다.
  static const Color neutralLine = line;

  /// 차트의 "약한 쪽" 막대 · 남은 몫. **면으로만** 쓴다. 보라(잘한 쪽)와 짝을 이룬다.
  static const Color rose = Color(0xFFF0A6B6);

  /// [rose] 계열 글자 · 아이콘용. 흰 면 위 대비 4.6:1.
  static const Color roseInk = Color(0xFFB4485F);

  // ------------------------------------------------------------ 그림자

  /// 종이가 살짝 떠 보이는 그림자. 좌측 상단 조명이라 오른쪽 아래로 진다.
  /// 층을 구분할 때만 쓰고, 카드마다 두르지 않는다.
  static const Color paperShadow = Color(0x14292E50);
}
