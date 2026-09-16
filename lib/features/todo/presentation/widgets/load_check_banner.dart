import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../ai/data/load_check_models.dart';
import '../../../ai/presentation/load_check_provider.dart';
import '../todo_provider.dart';

/// 오늘 계획이 평소보다 많을 때만 뜨는 안내.
///
/// **평소에는 아무것도 보이지 않는다.** 근거가 얇거나(실행 기록 7일 미만) 계획이
/// 평소 수준이면 서버가 조용히 넘어가고, 이 위젯은 자리를 차지하지 않는다.
///
/// 톤은 경고가 아니라 제안이다. 빨강이 아니라 앰버를 쓰고, 문구도 "못 한다" 가 아니라
/// "부담일 수 있다" 로 말한다. 그냥 하겠다는 선택지를 같은 크기로 둔다.
class LoadCheckBanner extends ConsumerWidget {
  const LoadCheckBanner({super.key});

  Future<void> _accept(BuildContext context, WidgetRef ref) async {
    final moved =
        await ref.read(todayLoadCheckProvider.notifier).acceptSuggestions();
    if (!context.mounted) return;

    ref.invalidate(dayTodosControllerProvider);
    AppSnackBar.show(
      context,
      moved == 0 ? '옮길 수 있는 항목이 없었어요.' : '$moved개를 내일로 옮겼어요.',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final check = ref.watch(todayLoadCheckProvider).value;
    if (check == null || !check.shouldShow) return const SizedBox.shrink();

    final canDefer = check.suggestions.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.s16),
        decoration: BoxDecoration(
          color: AppColors.amberSurface,
          borderRadius: BorderRadius.circular(AppRadius.r8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: AppColors.amberInk,
                ),
                const SizedBox(width: AppSpacing.s8),
                Text(
                  '오늘 계획, 조금 많아요',
                  style: AppTypography.bodyStrong
                      .copyWith(color: AppColors.amberInk),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              check.message!,
              style: AppTypography.body.copyWith(color: AppColors.inkSub),
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              _evidenceLine(check.evidence),
              style: AppTypography.caption.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: AppSpacing.s12),
            Row(
              children: [
                if (canDefer)
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _accept(context, ref),
                      child: Text('${check.suggestions.length}개 내일로'),
                    ),
                  ),
                if (canDefer) const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        ref.read(todayLoadCheckProvider.notifier).dismiss(),
                    child: const Text('그냥 할게요'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 판정 근거를 한 줄로. 어디서 나온 말인지 보이지 않으면 잔소리가 된다.
  static String _evidenceLine(LoadEvidence evidence) {
    final average = evidence.avgCompletedMinutesPerDay;
    final planned = evidence.todayPlannedMinutes;
    if (average <= 0) return '최근 ${evidence.windowDays}일 기록을 봤어요.';
    return '평소 하루 $average분 · 오늘 계획 $planned분';
  }
}
