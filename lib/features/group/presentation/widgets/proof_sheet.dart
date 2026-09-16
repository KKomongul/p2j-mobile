import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../data/group_models.dart';
import '../../data/group_repository.dart';
import '../group_provider.dart';

/// 인증샷 상세 — 사진, 리액션, 댓글.
///
/// 리액션은 사용자당 하나다. 이미 누른 걸 다시 누르면 취소되고, 다른 걸 누르면 교체된다.
/// 그래서 네 개를 한 줄에 두고 **지금 누른 것만 칠한다**.
class ProofSheet extends ConsumerStatefulWidget {
  const ProofSheet({required this.proof, super.key});

  final Proof proof;

  static Future<void> show(BuildContext context, Proof proof) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ProofSheet(proof: proof),
    );
  }

  @override
  ConsumerState<ProofSheet> createState() => _ProofSheetState();
}

class _ProofSheetState extends ConsumerState<ProofSheet> {
  final _commentController = TextEditingController();

  late Map<String, int> _reactions = Map.of(widget.proof.reactions);
  late ReactionType? _mine = widget.proof.myReactionType;
  bool _sending = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _react(ReactionType type) async {
    final repository = ref.read(groupRepositoryProvider);
    final postId = widget.proof.postId;
    final wasMine = _mine;

    try {
      if (wasMine == type) {
        // 같은 걸 다시 누르면 취소다.
        await repository.clearReaction(postId);
        if (!mounted) return;
        setState(() {
          _reactions = Map.of(_reactions)
            ..update(type.wire, (n) => n - 1, ifAbsent: () => 0)
            ..removeWhere((_, n) => n <= 0);
          _mine = null;
        });
      } else {
        final tally = await repository.setReaction(postId, type);
        if (!mounted) return;
        setState(() {
          _reactions = tally.reactions;
          _mine = ReactionTypeX.tryParse(tally.myReaction);
        });
      }
    } on ApiException catch (error) {
      if (mounted) AppSnackBar.show(context, error.message);
    }
  }

  Future<void> _comment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      await ref
          .read(groupRepositoryProvider)
          .addComment(widget.proof.postId, text);
      if (!mounted) return;
      _commentController.clear();
      ref.invalidate(postCommentsProvider(widget.proof.postId));
      setState(() => _sending = false);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _sending = false);
      AppSnackBar.show(context, error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final comments = ref.watch(postCommentsProvider(widget.proof.postId));
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH,
                    AppSpacing.s20,
                    AppSpacing.screenH,
                    AppSpacing.s16,
                  ),
                  children: [
                    if (widget.proof.user != null)
                      Text(
                        widget.proof.user!.nickname,
                        style: AppTypography.bodyStrong,
                      ),
                    const SizedBox(height: AppSpacing.s12),
                    _Photo(url: widget.proof.imageUrl),
                    if (widget.proof.caption?.isNotEmpty ?? false) ...[
                      const SizedBox(height: AppSpacing.s12),
                      Text(
                        widget.proof.caption!,
                        style: AppTypography.body.copyWith(
                          color: AppColors.inkSub,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.s16),
                    _ReactionRow(
                      counts: _reactions,
                      mine: _mine,
                      onTap: _react,
                    ),
                    const SizedBox(height: AppSpacing.s20),
                    Text('댓글', style: AppTypography.titleM),
                    const SizedBox(height: AppSpacing.s12),
                    comments.when(
                      loading: () => const LoadingView(),
                      error: (error, _) => Text(
                        '댓글을 불러오지 못했어요.',
                        style: AppTypography.caption
                            .copyWith(color: AppColors.muted),
                      ),
                      data: (items) => items.isEmpty
                          ? Text(
                              '첫 댓글을 남겨 보세요.',
                              style: AppTypography.caption
                                  .copyWith(color: AppColors.muted),
                            )
                          : Column(
                              children: [
                                for (final comment in items)
                                  _CommentRow(comment: comment),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
              _CommentInput(
                controller: _commentController,
                sending: _sending,
                onSend: _comment,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.r8),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: url == null
            // 스토리지 버킷이 아직 설정되지 않은 경우. 기능은 그대로 돈다.
            ? const ColoredBox(
                color: AppColors.fill,
                child: Center(
                  child: Icon(
                    Icons.photo_rounded,
                    size: 32,
                    color: AppColors.disabled,
                  ),
                ),
              )
            : Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => const ColoredBox(
                  color: AppColors.fill,
                  child: Center(
                    child: Icon(
                      Icons.broken_image_rounded,
                      size: 32,
                      color: AppColors.disabled,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _ReactionRow extends StatelessWidget {
  const _ReactionRow({
    required this.counts,
    required this.mine,
    required this.onTap,
  });

  final Map<String, int> counts;
  final ReactionType? mine;
  final ValueChanged<ReactionType> onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final type in ReactionType.values)
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.s8),
            child: _ReactionButton(
              type: type,
              count: counts[type.wire] ?? 0,
              selected: mine == type,
              onTap: () => onTap(type),
            ),
          ),
      ],
    );
  }
}

class _ReactionButton extends StatelessWidget {
  const _ReactionButton({
    required this.type,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final ReactionType type;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        // 48dp 터치 영역에 가깝게 유지한다.
        constraints: const BoxConstraints(minWidth: 52, minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8),
        decoration: BoxDecoration(
          color: selected ? AppColors.purpleSurface : AppColors.fill,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: selected
              ? Border.all(color: AppColors.purple, width: 1.5)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(type.glyph, style: const TextStyle(fontSize: 15)),
            if (count > 0) ...[
              const SizedBox(width: AppSpacing.s4),
              Text(
                '$count',
                style: AppTypography.label.copyWith(
                  color: selected ? AppColors.purple : AppColors.muted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CommentRow extends StatelessWidget {
  const _CommentRow({required this.comment});

  final PostComment comment;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(comment.user.nickname, style: AppTypography.label),
          const SizedBox(height: 2),
          Text(
            comment.content,
            style: AppTypography.body.copyWith(color: AppColors.inkSub),
          ),
        ],
      ),
    );
  }
}

class _CommentInput extends StatelessWidget {
  const _CommentInput({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.s8,
        AppSpacing.s8,
        AppSpacing.s8,
      ),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: !sending,
              maxLength: 500,
              minLines: 1,
              maxLines: 3,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: const InputDecoration(
                hintText: '한마디 남기기',
                counterText: '',
                border: InputBorder.none,
              ),
            ),
          ),
          IconButton(
            onPressed: sending ? null : onSend,
            icon: const Icon(Icons.send_rounded),
            color: AppColors.purple,
            tooltip: '보내기',
          ),
        ],
      ),
    );
  }
}
