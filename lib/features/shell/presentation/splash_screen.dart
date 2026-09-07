import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_illustrations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/error_view.dart';
import '../../auth/presentation/auth_controller.dart';

/// 저장된 토큰으로 자동 로그인을 판정하는 동안 보이는 화면.
///
/// 판정이 실패하면(대개 오프라인) 여기서 에러와 재시도를 보여준다.
/// 로그인 화면으로 보내면 사용자는 로그아웃된 줄 안다.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.navy,
        body: SafeArea(
          child: auth.hasError ? _error(ref, auth.error!) : const _Loading(),
        ),
      ),
    );
  }

  Widget _error(WidgetRef ref, Object error) {
    return Column(
      children: [
        Expanded(
          child: ErrorView(
            error: error,
            onDark: true,
            onRetry: () => ref.invalidate(authControllerProvider),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.s24),
          child: TextButton(
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            child: Text(
              '다른 계정으로 로그인',
              style: AppTypography.caption.copyWith(
                color: AppColors.onNavyMuted,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 마스코트가 천천히 오르내린다. 멈춘 화면이 아니라 기다리는 중이라는 신호다.
class _Loading extends StatefulWidget {
  const _Loading();

  @override
  State<_Loading> createState() => _LoadingState();
}

class _LoadingState extends State<_Loading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bob;

  @override
  void initState() {
    super.initState();
    _bob = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _bob,
            builder: (context, child) => Transform.translate(
              offset: Offset(0, -10 * Curves.easeInOut.transform(_bob.value)),
              child: child,
            ),
            child: Image.asset(
              AppIllustrations.mascot,
              height: 220,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          Text(
            '오늘 할 일을 불러오는 중',
            style: AppTypography.body.copyWith(
              color: AppColors.onNavyMuted,
            ),
          ),
        ],
      ),
    );
  }
}
