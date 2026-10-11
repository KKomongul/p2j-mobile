import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// 앱 테마. 라이트 모드만 제공한다.
///
/// ColorScheme.fromSeed 를 쓰지 않는다. 시드 한 줄로 만들면 그레이 스케일까지
/// 브랜드 색에 물들어서 토스 계열의 중성 회색을 못 쓴다.
abstract final class AppTheme {
  static const ColorScheme _colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.ink,
    onPrimary: Colors.white,
    secondary: AppColors.purple,
    onSecondary: Colors.white,
    error: AppColors.coral,
    onError: Colors.white,
    surface: AppColors.surface,
    onSurface: AppColors.ink,
    surfaceContainerHighest: AppColors.fill,
    outline: AppColors.line,
    outlineVariant: AppColors.line,
    surfaceTint: Colors.transparent,
  );

  static ThemeData light() {
    final textTheme = const TextTheme(
      displaySmall: AppTypography.display,
      headlineMedium: AppTypography.titleXL,
      headlineSmall: AppTypography.numberM,
      titleLarge: AppTypography.titleL,
      titleMedium: AppTypography.titleM,
      bodyLarge: AppTypography.body,
      bodyMedium: AppTypography.body,
      bodySmall: AppTypography.caption,
      labelLarge: AppTypography.bodyStrong,
      labelMedium: AppTypography.label,
      labelSmall: AppTypography.label,
    ).apply(bodyColor: AppColors.ink, displayColor: AppColors.ink);

    return ThemeData(
      useMaterial3: true,
      colorScheme: _colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: AppTypography.fontFamily,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,

      appBarTheme: AppBarTheme(
        // 앱바는 흰 면, 본문은 회색 바탕. 위아래가 한 층으로 붙어 보이지 않게 한다.
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        // titleTextStyle 을 주면 foregroundColor 가 무시된다. 색을 직접 넣는다.
        titleTextStyle: AppTypography.titleL.copyWith(color: AppColors.ink),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.line,
        thickness: 1,
        space: 1,
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.ink,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.fill,
          disabledForegroundColor: AppColors.disabled,
          minimumSize: const Size.fromHeight(54),
          textStyle: AppTypography.bodyStrong,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.r8),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.inkSub,
          backgroundColor: AppColors.fill,
          minimumSize: const Size.fromHeight(54),
          textStyle: AppTypography.bodyStrong,
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.r8),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.muted,
          textStyle: AppTypography.caption,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.fill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: AppSpacing.s16,
        ),
        hintStyle: AppTypography.body.copyWith(color: AppColors.disabled),
        labelStyle: AppTypography.label.copyWith(color: AppColors.muted),
        errorStyle: AppTypography.caption.copyWith(color: AppColors.coral),
        border: _inputBorder(Colors.transparent),
        enabledBorder: _inputBorder(Colors.transparent),
        focusedBorder: _inputBorder(AppColors.ink, width: 1.5),
        errorBorder: _inputBorder(AppColors.coral),
        focusedErrorBorder: _inputBorder(AppColors.coral, width: 1.5),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: AppTypography.caption.copyWith(color: Colors.white),
        actionTextColor: AppColors.amber,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.r8),
        ),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: AppColors.line,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.r16),
          ),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        elevation: 0,
        height: 62,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppTypography.label.copyWith(color: AppColors.ink)
              : AppTypography.label.copyWith(color: AppColors.muted),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? AppColors.ink
                : AppColors.muted,
          ),
        ),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.purple,
        linearTrackColor: AppColors.fill,
        circularTrackColor: AppColors.fill,
      ),
    );
  }

  /// 어두운 면 위의 주요 버튼.
  ///
  /// 기본 주요 버튼은 네이비인데, 네이비 면 위에서는 그대로 묻힌다.
  /// 어두운 면에서는 앰버로 뒤집는다.
  static ButtonStyle filledOnNavy() => FilledButton.styleFrom(
        backgroundColor: AppColors.amber,
        foregroundColor: AppColors.onAmber,
        disabledBackgroundColor: AppColors.navyFill,
        disabledForegroundColor: AppColors.onNavyMuted,
        minimumSize: const Size.fromHeight(54),
        textStyle: AppTypography.bodyStrong,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.r8),
        ),
      );

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.r8),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
