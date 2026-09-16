import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../data/group_models.dart';
import '../../data/group_repository.dart';
import '../group_provider.dart';

/// 초대 코드 시트.
///
/// 코드는 카톡으로 옮겨 적는 값이라 **누르면 복사**가 기본 동작이다.
/// 재발급은 이전 코드를 폐기하므로 그 사실을 버튼 옆에 적어 둔다.
class InviteSheet extends ConsumerStatefulWidget {
  const InviteSheet({required this.group, super.key});

  final Group group;

  static Future<void> show(BuildContext context, Group group) {
    return showModalBottomSheet<void>(
      context: context,
      builder: (_) => InviteSheet(group: group),
    );
  }

  @override
  ConsumerState<InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends ConsumerState<InviteSheet> {
  late String? _code = widget.group.inviteCode;
  bool _busy = false;

  Future<void> _copy() async {
    if (_code == null) return;
    await Clipboard.setData(ClipboardData(text: _code!));
    if (mounted) AppSnackBar.show(context, '초대 코드를 복사했어요.');
  }

  Future<void> _reissue() async {
    setState(() => _busy = true);
    try {
      final invite =
          await ref.read(groupRepositoryProvider).issueInvite(widget.group.groupId);
      if (!mounted) return;
      setState(() {
        _code = invite.inviteCode;
        _busy = false;
      });
      ref.invalidate(groupDetailProvider(widget.group.groupId));
      AppSnackBar.show(context, '새 코드를 만들었어요. 이전 코드는 더 이상 쓸 수 없어요.');
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppSnackBar.show(context, error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final full = widget.group.isFull;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          AppSpacing.s20,
          AppSpacing.screenH,
          AppSpacing.s20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('초대 코드', style: AppTypography.titleL),
            const SizedBox(height: AppSpacing.s4),
            Text(
              full
                  ? '정원이 가득 찼어요. 누군가 나가면 다시 받을 수 있어요.'
                  : '이 코드를 받은 사람이 그룹에 들어올 수 있어요. 7일 동안 쓸 수 있어요.',
              style: AppTypography.caption.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: AppSpacing.s20),
            InkWell(
              onTap: _code == null ? null : _copy,
              borderRadius: BorderRadius.circular(AppRadius.r8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s16,
                  vertical: AppSpacing.s20,
                ),
                decoration: BoxDecoration(
                  color: AppColors.fill,
                  borderRadius: BorderRadius.circular(AppRadius.r8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _code ?? '코드가 없어요',
                        style: AppTypography.titleL.copyWith(
                          color: _code == null
                              ? AppColors.disabled
                              : AppColors.ink,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    if (_code != null)
                      const Icon(
                        Icons.content_copy_rounded,
                        size: 20,
                        color: AppColors.muted,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              '${widget.group.memberCount}/${widget.group.maxMembers}명이 함께하고 있어요.',
              style: AppTypography.caption.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: AppSpacing.s20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _busy ? null : _reissue,
                child: Text(_busy ? '만드는 중' : '새 코드 만들기'),
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              '새로 만들면 지금 코드는 바로 쓸 수 없게 돼요.',
              style: AppTypography.caption.copyWith(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
