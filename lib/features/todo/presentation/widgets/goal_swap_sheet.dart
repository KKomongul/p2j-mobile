import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../../../core/theme/app_illustrations.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../goal/data/goal_models.dart';
import '../../../goal/presentation/goal_provider.dart';

/// 할 일 하나의 목표를 갈아끼우는 시트.
///
/// 만들 때 정하는 게 아니라 **나중에 바꾸는 쪽**이 실제 동선이다. 일단 적어 두고
/// 나중에 "이건 그 목표에 넣자" 가 되는 경우가 대부분이라, 목록에서 바로 열린다.
///
/// 목표를 떼는 것도 고를 수 있는 한 줄로 둔다. 해제를 따로 숨겨 두면 잘못 붙였을 때
/// 되돌릴 길이 안 보인다.
class GoalSwapSheet extends ConsumerWidget {
  const GoalSwapSheet({required this.currentGoalId, super.key});

  final int? currentGoalId;

  /// 고른 목표 id 를 돌려준다. 해제는 [GoalSwapResult.none], 취소는 null.
  static Future<GoalSwapResult?> show(
    BuildContext context, {
    required int? currentGoalId,
  }) {
    return showModalBottomSheet<GoalSwapResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => GoalSwapSheet(currentGoalId: currentGoalId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(activeGoalsProvider);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.s20,
                AppSpacing.screenH,
                AppSpacing.s8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('어느 목표에 넣을까요', style: AppTypography.titleL),
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    '목표에 넣으면 그 목표의 진행률에 함께 쌓여요.',
                    style:
                        AppTypography.caption.copyWith(color: AppColors.muted),
                  ),
                ],
              ),
            ),
            Flexible(
              child: goals.when(
                loading: () => const LoadingView(),
                error: (error, _) => Padding(
                  padding: const EdgeInsets.all(AppSpacing.s24),
                  child: Text(
                    '목표를 불러오지 못했어요.',
                    style: AppTypography.body.copyWith(color: AppColors.inkSub),
                  ),
                ),
                data: (items) => ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: AppSpacing.s16),
                  children: [
                    _Row(
                      label: '목표 없음',
                      caption: '이 할 일만 따로 둬요',
                      selected: currentGoalId == null,
                      onTap: () =>
                          Navigator.of(context).pop(const GoalSwapResult.none()),
                    ),
                    if (items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.s16),
                        child: EmptyView(
                          imagePath: AppIllustrations.goalAdd,
                          title: '아직 목표가 없어요',
                          description: '목표 탭에서 먼저 하나 만들어 주세요.',
                        ),
                      )
                    else
                      for (final goal in items)
                        _Row(
                          label: goal.title,
                          caption: _progressLabel(goal),
                          color: parseGoalColor(goal.color),
                          selected: currentGoalId == goal.goalId,
                          onTap: () => Navigator.of(context)
                              .pop(GoalSwapResult.pick(goal.goalId)),
                        ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _progressLabel(Goal goal) {
    final progress = goal.progress;
    if (progress.targetCount <= 0) return '';
    return '${progress.doneCount}/${progress.targetCount}회';
  }
}

/// 시트가 돌려주는 선택. "고르지 않음(취소)" 과 "목표 없음" 을 구분하려고 둔다.
class GoalSwapResult {
  const GoalSwapResult.none() : goalId = null;

  const GoalSwapResult.pick(int this.goalId);

  /// null 이면 목표를 뗀다.
  final int? goalId;
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.selected,
    required this.onTap,
    this.caption = '',
    this.color,
  });

  final String label;
  final String caption;
  final Color? color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenH,
          // 48dp 터치 영역.
          vertical: AppSpacing.s16,
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color ?? AppColors.line,
                shape: BoxShape.circle,
                border: color == null
                    ? Border.all(color: AppColors.disabled)
                    : null,
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body.copyWith(
                      color: selected ? AppColors.purple : AppColors.ink,
                    ),
                  ),
                  if (caption.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      caption,
                      style: AppTypography.caption
                          .copyWith(color: AppColors.muted),
                    ),
                  ],
                ],
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_rounded,
                size: 20,
                color: AppColors.purple,
              ),
          ],
        ),
      ),
    );
  }
}

/// `#RRGGBB` → Color. 서버가 형식을 검증하지만 값이 비어 올 수 있다.
Color? parseGoalColor(String? hex) {
  if (hex == null || hex.length != 7 || !hex.startsWith('#')) return null;
  final value = int.tryParse(hex.substring(1), radix: 16);
  return value == null ? null : Color(0xFF000000 | value);
}
