import 'package:flutter/material.dart';

import '../network/api_exception.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// 에러 상태 화면.
///
/// 사과하지 않는다. 무엇이 잘못됐고 어떻게 하면 되는지만 말한다.
class ErrorView extends StatelessWidget {
  const ErrorView({
    required this.error,
    this.onRetry,
    this.onDark = false,
    super.key,
  });

  final Object error;
  final VoidCallback? onRetry;

  /// 어두운 면 위에 놓을 때. 글자와 버튼 색을 뒤집는다.
  final bool onDark;

  String get _message {
    final failure = error;
    if (failure is ApiException) return failure.message;
    return '요청을 처리하지 못했어요. 다시 시도하세요.';
  }

  IconData get _icon {
    final failure = error;
    if (failure is ApiException && failure.isNetworkProblem) {
      return Icons.wifi_off_rounded;
    }
    return Icons.error_outline_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppColors.coralSurface,
                shape: BoxShape.circle,
              ),
              child: Icon(_icon, color: AppColors.coral, size: 26),
            ),
            const SizedBox(height: AppSpacing.s20),
            Text(
              _message,
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(
                color: onDark ? AppColors.onNavy : AppColors.ink,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.s24),
              SizedBox(
                width: 140,
                child: OutlinedButton(
                  onPressed: onRetry,
                  style: onDark
                      ? OutlinedButton.styleFrom(
                          foregroundColor: AppColors.onNavy,
                          backgroundColor: AppColors.navyFill,
                        )
                      : null,
                  child: const Text('다시 시도'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
