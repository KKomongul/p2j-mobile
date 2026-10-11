import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_illustrations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/status_chip.dart';
import '../data/stats_models.dart';
import 'stats_provider.dart';
import 'widgets/hour_heatmap.dart';
import 'widgets/overview_cards.dart';
import 'widgets/rate_line_chart.dart';
import 'widgets/stat_card.dart';
import 'widgets/weekday_bar_chart.dart';

/// 통계 탭.
///
/// 회색 바탕 위에 흰 카드를 쌓는다 (그룹 화면과 같은 결). 위에서 아래로
/// **한눈에 보기**(숫자 몇 개) → **기록 분석**(언제 · 어떻게 했는지) 순서다.
/// 가장 큰 숫자는 달성률 하나뿐이고, 차트는 카드마다 한 가지 질문에만 답한다.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(statsPeriodControllerProvider);
    final summary = ref.watch(statsSummaryProvider);

    return DefaultTabController(
      length: StatsPeriod.values.length,
      initialIndex: period.index,
      child: Scaffold(
        backgroundColor: AppColors.neutralFill,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          title: const Text('통계'),
          bottom: TabBar(
            onTap: (i) => ref
                .read(statsPeriodControllerProvider.notifier)
                .select(StatsPeriod.values[i]),
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: AppColors.ink,
            unselectedLabelColor: AppColors.disabled,
            labelStyle: AppTypography.bodyStrong,
            unselectedLabelStyle: AppTypography.body,
            indicatorColor: AppColors.ink,
            indicatorSize: TabBarIndicatorSize.label,
            dividerColor: AppColors.neutralLine,
            tabs: [for (final p in StatsPeriod.values) Tab(text: p.label)],
          ),
        ),
        body: summary.when(
          loading: () => const LoadingView(),
          error: (error, _) => ErrorView(
            error: error,
            onRetry: () => ref.invalidate(statsSummaryProvider),
          ),
          data: (data) => RefreshIndicator(
            color: AppColors.ink,
            onRefresh: () async => ref.invalidate(statsSummaryProvider),
            child: data.isEmpty ? const _EmptyBody() : _Body(summary: data),
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.summary});

  final StatsSummary summary;

  @override
  Widget build(BuildContext context) {
    final peak = summary.peakHour;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        0,
        AppSpacing.s16,
        AppSpacing.s40,
      ),
      children: [
        const StatSectionTitle('한눈에 보기'),
        SummaryTiles(summary: summary),
        const SizedBox(height: AppSpacing.s12),
        AchievementCard(summary: summary),
        const SizedBox(height: AppSpacing.s12),
        BestStreakCard(summary: summary),
        const StatSectionTitle('기록 분석'),
        if (summary.byHour.isNotEmpty) ...[
          StatCard(
            title: '끝낸 시간대',
            caption: peak == null || peak.completed == 0
                ? null
                : '${peak.hour}시쯤 가장 많이 끝냈어요.',
            child: HourHeatmap(hours: summary.byHour),
          ),
          const SizedBox(height: AppSpacing.s12),
        ],
        StatCard(
          title: '날짜별 달성률',
          caption: '하루하루 얼마나 끝냈는지의 흐름이에요.',
          child: RateLineChart(days: summary.byDay),
        ),
        const SizedBox(height: AppSpacing.s12),
        StatCard(
          title: '요일별 평균',
          caption: summary.period == StatsPeriod.week
              ? '30일로 보면 요일마다의 습관이 더 잘 보여요.'
              : '분홍 막대가 가장 약한 요일이에요.',
          child: WeekdayBarChart(days: summary.byDay),
        ),
        if (summary.mostDeferred.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s12),
          StatCard(
            title: '자주 미룬 것',
            caption: '미루는 건 실패가 아니에요. 다만 눈에는 보여야 해요.',
            child: _DeferredList(entries: summary.mostDeferred),
          ),
        ],
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
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0) const Divider(height: 20, color: AppColors.neutralLine),
          Row(
            children: [
              Expanded(
                child: Text(
                  entries[i].title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body,
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              StatusChip(
                label: '${entries[i].deferCount}번',
                tone: entries[i].deferCount >= 3
                    ? ChipTone.danger
                    : ChipTone.neutral,
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _EmptyBody extends StatelessWidget {
  const _EmptyBody();

  @override
  Widget build(BuildContext context) {
    // RefreshIndicator 가 당겨지려면 스크롤되는 자식이 있어야 한다.
    return ListView(
      padding: const EdgeInsets.only(top: AppSpacing.s40),
      children: const [
        EmptyView(
          imagePath: AppIllustrations.loadAdjust,
          title: '아직 쌓인 기록이 없어요',
          description: '할 일을 하나씩 끝내면\n여기에 모아서 보여 드릴게요.',
        ),
      ],
    );
  }
}
