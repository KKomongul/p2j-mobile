import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 스낵바 표시 헬퍼. 낙관적 업데이트가 실패했을 때 되돌린 사실을 알린다.
abstract final class AppSnackBar {
  static void show(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  static void error(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.coral,
        ),
      );
  }
}
