import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/form_controls.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../core/widgets/progress_bar.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../data/group_models.dart';
import '../group_detail_screen.dart';
import '../group_provider.dart';

/// 순위 탭.
///
/// 기간은 **달력 기준**이다 (이번 주 = 월~일). 통계 탭의 "최근 7일" 과 다른데,
/// 순위는 여럿이 같은 표를 보므로 경계가 사람마다 달라지면 대화가 어긋난다.
///
/// 선언하지 않은 사람도 0% 로 남는다. 빼 버리면 안 하는 쪽이 유리해진다.
class RankingTab extends ConsumerWidget {
  const RankingTab({required this.groupId, super.key});

  final int groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(rankingPeriodControllerProvider);
    final ranking = ref.watch(groupRankingProvider(groupId));
    final myId = ref.watch(authControllerProvider).value?.userId;

    return ListView(
      padding: kGroupTabPadding,
      children: [
        SegmentedChoice<RankingPeriod>(
          value: period,
          onChanged: (next) =>
              ref.read(rankingPeriodControllerProvider.notifier).select(next),
          options: const [
            SegmentOption(value: RankingPeriod.week, label: '이번 주'),
            SegmentOption(value: RankingPeriod.month, label: '이번 달'),
            SegmentOption(value: RankingPeriod.all, label: '전체'),
          ],
        ),
        const SizedBox(height: AppSpacing.s20),
        ranking.when(
          loading: () => const Padding(
            padding: EdgeInsets.only(top: AppSpacing.s40),
            child: LoadingView(),
          ),
          error: (error, _) => ErrorView(
            error: error,
            onRetry: () => ref.invalidate(groupRankingProvider(groupId)),
          ),
          data: (data) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (data.range.fromDate != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.s12),
                  child: Text(
                    _rangeLabel(data.range),
                    style:
                        AppTypography.caption.copyWith(color: AppColors.muted),
                  ),
                ),
              for (final entry in data.rankings)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.s16),
                  child: _RankRow(
                    entry: entry,
                    isMe: entry.userId == myId,
                  ),
                ),
              const SizedBox(height: AppSpacing.s8),
              Text(
                '달성률은 그룹에 선언한 항목만으로 셉니다. 선언하지 않은 날은 0이에요.',
                style: AppTypography.caption.copyWith(color: AppColors.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _rangeLabel(DateRange range) {
    String short(String? iso) {
      final parsed = iso == null ? null : DateTime.tryParse(iso);
      return parsed == null ? '' : '${parsed.month}.${parsed.day}';
    }

    return '${short(range.fromDate)} – ${short(range.toDate)}';
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({required this.entry, required this.isMe});

  final RankingEntry entry;

  /// 내 줄만 배경을 준다. 등수마다 색을 다르게 하면 순위가 아니라 색을 먼저 읽는다.
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final percent = (entry.achievementRate * 100).round();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s12,
        vertical: AppSpacing.s12,
      ),
      decoration: BoxDecoration(
        color: isMe ? AppColors.purpleSurface : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.r8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '${entry.rank}',
              style: AppTypography.titleM.copyWith(
                color: isMe ? AppColors.purple : AppColors.inkSub,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isMe ? '${entry.nickname} (나)' : entry.nickname,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyStrong,
                      ),
                    ),
                    Text('$percent%', style: AppTypography.numberM),
                  ],
                ),
                const SizedBox(height: AppSpacing.s8),
                ProgressBar(
                  value: entry.achievementRate,
                  fillColor: isMe ? AppColors.purple : AppColors.lavender,
                ),
                const SizedBox(height: AppSpacing.s4),
                Text(
                  _detail(entry),
                  style:
                      AppTypography.caption.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _detail(RankingEntry entry) {
    if (entry.declaredDays == 0) return '선언한 날이 없어요';
    final parts = <String>[
      '${entry.declaredDays}일 선언',
      '${entry.completedItems}/${entry.declaredItems}개 완료',
      if (entry.streak > 0) '연속 ${entry.streak}일',
    ];
    return parts.join('  ·  ');
  }
}
