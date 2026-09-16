import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_illustrations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/form_controls.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/paper_card.dart';
import '../../../core/widgets/status_chip.dart';
import '../data/stats_models.dart';
import 'stats_provider.dart';
import 'widgets/day_bar_chart.dart';
import 'widgets/hour_rows.dart';

/// 통계 탭.
///
/// **숫자를 늘어놓지 않고 하나만 크게 둔다.** 달성률은 카드 한 장에 몰고,
/// 나머지(연속 기록 · 날짜별 · 시간대 · 자주 미룬 것)는 배경 면 위에 평면으로 쌓는다.
/// 카드 안에 카드를 겹치지 않는다.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(statsPeriodControllerProvider);
    final summary = ref.watch(statsSummaryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('통계')),
      body: summary.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(statsSummaryProvider),
        ),
        data: (data) => RefreshIndicator(
          color: AppColors.ink,
          onRefresh: () async => ref.invalidate(statsSummaryProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              AppSpacing.s16,
              AppSpacing.screenH,
              AppSpacing.s40,
            ),
            children: [
              _PeriodPicker(
                value: period,
                onChanged: (next) => ref
                    .read(statsPeriodControllerProvider.notifier)
                    .select(next),
              ),
              const SizedBox(height: AppSpacing.s16),
              if (data.isEmpty)
                const _EmptyBody()
              else ...[
                _SummaryCard(summary: data),
                const SizedBox(height: AppSpacing.s24),
                _StreakRow(summary: data),
                const SizedBox(height: AppSpacing.s24),
                _Section(
                  title: '날짜별 달성률',
                  child: DayBarChart(days: data.byDay),
                ),
                if (data.byHour.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.s24),
                  _Section(
                    title: '끝낸 시간대',
                    caption: _peakCaption(data),
                    child: HourRows(hours: data.byHour),
                  ),
                ],
                if (data.mostDeferred.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.s24),
                  _Section(
                    title: '자주 미룬 것',
                    caption: '미루는 건 실패가 아니에요. 다만 눈에는 보여야 해요.',
                    child: _DeferredList(entries: data.mostDeferred),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String? _peakCaption(StatsSummary summary) {
    final peak = summary.peakHour;
    if (peak == null || peak.completed == 0) return null;
    return '${peak.hour}시쯤 가장 많이 끝냈어요.';
  }
}

class _PeriodPicker extends StatelessWidget {
  const _PeriodPicker({required this.value, required this.onChanged});

  final StatsPeriod value;
  final ValueChanged<StatsPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedChoice<StatsPeriod>(
      value: value,
      onChanged: onChanged,
      options: const [
        SegmentOption(value: StatsPeriod.week, label: '최근 7일'),
        SegmentOption(value: StatsPeriod.month, label: '최근 30일'),
      ],
    );
  }
}

/// 달성률 한 장. 이 화면에서 가장 큰 숫자는 여기 하나뿐이다.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final StatsSummary summary;

  @override
  Widget build(BuildContext context) {
    final percent = (summary.achievementRate * 100).round();

    return PaperCard(
      padding: const EdgeInsets.all(AppSpacing.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('$percent', style: AppTypography.display),
              Text(
                '%',
                style: AppTypography.titleL.copyWith(color: AppColors.inkSub),
              ),
              const Spacer(),
              StatusChip(
                label: summary.range.fromDate == null
                    ? summary.period.label
                    : _rangeLabel(summary.range),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(
            '${summary.totalTodos}개 중 ${summary.completedTodos}개를 끝냈어요',
            style: AppTypography.body.copyWith(color: AppColors.inkSub),
          ),
          if (summary.totalActualMinutes > 0) ...[
            const SizedBox(height: AppSpacing.s4),
            Text(
              '들인 시간 ${formatMinutes(summary.totalActualMinutes)}',
              style: AppTypography.caption.copyWith(color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }

  static String _rangeLabel(StatsRange range) {
    String short(String? iso) {
      final parsed = iso == null ? null : DateTime.tryParse(iso);
      return parsed == null ? '' : '${parsed.month}.${parsed.day}';
    }

    return '${short(range.fromDate)} – ${short(range.toDate)}';
  }
}

/// 연속 기록. 지금과 최고를 나란히 둔다.
class _StreakRow extends StatelessWidget {
  const _StreakRow({required this.summary});

  final StatsSummary summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StreakTile(
            label: '지금 연속',
            days: summary.currentStreak,
            emphasized: true,
          ),
        ),
        const SizedBox(width: AppSpacing.s12),
        Expanded(
          child: _StreakTile(
            label: '가장 길었던 연속',
            days: summary.longestStreak,
            emphasized: false,
          ),
        ),
      ],
    );
  }
}

class _StreakTile extends StatelessWidget {
  const _StreakTile({
    required this.label,
    required this.days,
    required this.emphasized,
  });

  final String label;
  final int days;

  /// 지금 이어지는 기록만 강조한다. 둘 다 강조하면 둘 다 안 보인다.
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s12,
      ),
      decoration: BoxDecoration(
        color: emphasized ? AppColors.purpleSurface : AppColors.fill,
        borderRadius: BorderRadius.circular(AppRadius.r8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.label.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(
            days == 0 ? '없음' : '$days일',
            style: AppTypography.titleL.copyWith(
              color: emphasized ? AppColors.purple : AppColors.inkSub,
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.caption});

  final String title;
  final String? caption;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.titleM),
        if (caption != null) ...[
          const SizedBox(height: AppSpacing.s4),
          Text(
            caption!,
            style: AppTypography.caption.copyWith(color: AppColors.muted),
          ),
        ],
        const SizedBox(height: AppSpacing.s12),
        child,
      ],
    );
  }
}

class _DeferredList extends StatelessWidget {
  const _DeferredList({required this.entries});

  final List<DeferredEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body.copyWith(color: AppColors.inkSub),
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                StatusChip(
                  label: '${entry.deferCount}번',
                  tone: entry.deferCount >= 3 ? ChipTone.warn : ChipTone.neutral,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _EmptyBody extends StatelessWidget {
  const _EmptyBody();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: AppSpacing.s40),
      child: EmptyView(
        imagePath: AppIllustrations.loadAdjust,
        title: '아직 쌓인 기록이 없어요',
        description: '할 일을 하나씩 끝내면\n여기에 모아서 보여 드릴게요.',
      ),
    );
  }
}

/// 분을 "1시간 40분" 으로. 60분 미만이면 분만 적는다.
String formatMinutes(int minutes) {
  if (minutes < 60) return '$minutes분';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '$hours시간' : '$hours시간 $rest분';
}
