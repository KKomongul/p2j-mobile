import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/data/auth_models.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/goal/presentation/goal_list_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/shell/presentation/main_shell.dart';
import '../../features/shell/presentation/placeholder_screen.dart';
import '../../features/shell/presentation/splash_screen.dart';
import '../../features/todo/presentation/home_screen.dart';
import '../theme/app_illustrations.dart';
import 'routes.dart';

part 'app_router.g.dart';

/// 앱 라우터.
///
/// 인증 게이트는 화면마다 두지 않고 redirect 한 곳에서만 판단한다.
@Riverpod(keepAlive: true)
GoRouter goRouter(Ref ref) {
  // GoRouter 는 Listenable 을 받으므로 인증 상태를 여기에 옮겨 담는다.
  final authState =
      ValueNotifier<AsyncValue<User?>>(const AsyncLoading<User?>());

  ref.listen<AsyncValue<User?>>(
    authControllerProvider,
    (_, next) => authState.value = next,
    fireImmediately: true,
  );

  final router = GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: authState,
    redirect: (context, state) {
      final auth = authState.value;
      final location = state.matchedLocation;

      // 판정 중에는 스플래시를 유지한다.
      if (auth.isLoading) {
        return location == Routes.splash ? null : Routes.splash;
      }

      // 자동 로그인이 실패했을 때도 스플래시에 머문다. 실패는 대개 오프라인이라,
      // 로그인 화면으로 보내면 로그아웃된 것처럼 보인다.
      if (auth.hasError) {
        return location == Routes.splash ? null : Routes.splash;
      }

      final loggedIn = auth.value != null;

      if (loggedIn) {
        if (location == Routes.splash || location == Routes.onboarding) {
          return Routes.home;
        }
        return null;
      }

      // 로그인하지 않았으면 언제나 대화 화면이다.
      // 가입도 로그인도 거기서 끝나므로 다른 인증 경로가 없다.
      return location == Routes.onboarding ? null : Routes.onboarding;
    },
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: Routes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.goals,
                builder: (context, state) => const GoalListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.group,
                builder: (context, state) => const PlaceholderScreen(
                  title: '그룹',
                  description: '아침에 선언하고 저녁에 인증하는 기능을\n준비하고 있어요.',
                  imagePath: AppIllustrations.groupShare,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.stats,
                builder: (context, state) => const PlaceholderScreen(
                  title: '통계',
                  description: '달성률이 어떻게 쌓이는지\n한눈에 보여 드릴게요.',
                  imagePath: AppIllustrations.loadAdjust,
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    authState.dispose();
  });

  return router;
}
