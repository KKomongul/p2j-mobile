import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_illustrations.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../core/widgets/paper_card.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../data/group_models.dart';
import '../group_detail_screen.dart';
import '../group_provider.dart';
import 'proof_sheet.dart';

/// 피드 탭 — 사용자별·날짜별로 묶인 하루.
///
/// **못 한 것을 같이 보여 준다.** 해낸 인증샷만 늘어놓으면 SNS 와 다를 게 없고,
/// 이 앱이 하려는 "있는 그대로 드러내기" 가 사라진다.
class FeedTab extends ConsumerWidget {
  const FeedTab({required this.groupId, super.key});

  final int groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(groupFeedProvider(groupId));

    return feed.when(
      loading: () => const LoadingView(),
      error: (error, _) => ErrorView(
        error: error,
        onRetry: () => ref.invalidate(groupFeedProvider(groupId)),
      ),
      data: (entries) {
        if (entries.isEmpty) {
          return ListView(
            padding: kGroupTabPadding,
            children: const [
              SizedBox(height: AppSpacing.s24),
              EmptyView(
                imagePath: AppIllustrations.groupShare,
                title: '아직 올라온 게 없어요',
                description: '아침에 선언하고 저녁에 해낸 걸 올리면\n여기에 쌓여요.',
              ),
            ],
          );
        }

        return RefreshIndicator(
          color: AppColors.ink,
          onRefresh: () async => ref.invalidate(groupFeedProvider(groupId)),
          child: ListView.separated(
            padding: kGroupTabPadding,
            itemCount: entries.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: AppSpacing.s16),
            itemBuilder: (context, index) => _FeedEntryCard(
              entry: entries[index],
              groupId: groupId,
            ),
          ),
        );
      },
    );
  }
}

class _FeedEntryCard extends ConsumerWidget {
  const _FeedEntryCard({required this.entry, required this.groupId});

  final FeedEntry entry;
  final int groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cleared =
        entry.declaredCount > 0 && entry.doneCount >= entry.declaredCount;

    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.user.nickname,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyStrong,
                ),
              ),
              if (entry.date != null)
                Text(
                  _dateLabel(entry.date!),
                  style: AppTypography.caption.copyWith(color: AppColors.muted),
                ),
              const SizedBox(width: AppSpacing.s8),
              StatusChip(
                label: '${entry.doneCount}/${entry.declaredCount}',
                tone: cleared ? ChipTone.done : ChipTone.active,
              ),
            ],
          ),
          if (entry.posts.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s12),
            for (final post in entry.posts)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s8),
                child: _ProofRow(
                  proof: post,
                  onTap: () async {
                    await ProofSheet.show(context, post);
                    if (context.mounted) {
                      ref.invalidate(groupFeedProvider(groupId));
                    }
                  },
                ),
              ),
          ],
          if (entry.missedItems.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s8),
            _MissedList(items: entry.missedItems),
          ],
        ],
      ),
    );
  }

  static String _dateLabel(String iso) {
    final parsed = DateTime.tryParse(iso);
    return parsed == null ? iso : '${parsed.month}월 ${parsed.day}일';
  }
}

/// 인증샷 한 줄. 이미지는 썸네일로만 보이고 누르면 시트에서 크게 본다.
class _ProofRow extends StatelessWidget {
  const _ProofRow({required this.proof, required this.onTap});

  final Proof proof;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.r8),
      child: Row(
        children: [
          _Thumb(url: proof.imageUrl),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  proof.caption?.isNotEmpty ?? false ? proof.caption! : '인증했어요',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body.copyWith(color: AppColors.inkSub),
                ),
                const SizedBox(height: AppSpacing.s4),
                Row(
                  children: [
                    if (proof.reactionTotal > 0) ...[
                      Text(
                        _reactionGlyphs(proof.reactions),
                        style: AppTypography.label,
                      ),
                      const SizedBox(width: AppSpacing.s4),
                      Text(
                        '${proof.reactionTotal}',
                        style: AppTypography.label
                            .copyWith(color: AppColors.muted),
                      ),
                      const SizedBox(width: AppSpacing.s8),
                    ],
                    if (proof.commentCount > 0)
                      Text(
                        '댓글 ${proof.commentCount}',
                        style: AppTypography.label
                            .copyWith(color: AppColors.muted),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _reactionGlyphs(Map<String, int> reactions) {
    final glyphs = reactions.keys
        .map(ReactionTypeX.tryParse)
        .whereType<ReactionType>()
        .map((t) => t.glyph);
    return glyphs.join();
  }
}

/// 사진이 없거나 버킷이 아직 설정되지 않은 경우의 자리표시자.
class _Thumb extends StatelessWidget {
  const _Thumb({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.r8),
      child: SizedBox(
        width: 56,
        height: 56,
        child: url == null
            ? const ColoredBox(
                color: AppColors.fill,
                child: Icon(
                  Icons.photo_rounded,
                  size: 20,
                  color: AppColors.disabled,
                ),
              )
            : Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => const ColoredBox(
                  color: AppColors.fill,
                  child: Icon(
                    Icons.broken_image_rounded,
                    size: 20,
                    color: AppColors.disabled,
                  ),
                ),
              ),
      ),
    );
  }
}

class _MissedList extends StatelessWidget {
  const _MissedList({required this.items});

  final List<MissedItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: AppColors.fill,
        borderRadius: BorderRadius.circular(AppRadius.r8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '못 한 것',
            style: AppTypography.label.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: AppSpacing.s4),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          AppTypography.caption.copyWith(color: AppColors.inkSub),
                    ),
                  ),
                  if (item.status == DeclarationItemStatus.deferred)
                    Text(
                      '미룸',
                      style: AppTypography.label
                          .copyWith(color: AppColors.amberInk),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
