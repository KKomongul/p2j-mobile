import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../../../core/widgets/form_controls.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../core/theme/app_illustrations.dart';
import '../../../todo/presentation/todo_provider.dart';
import '../../data/group_models.dart';
import '../../data/group_repository.dart';

/// 아침 선언 시트 — 오늘 할 일 중에서 그룹에 걸 것을 고른다.
///
/// **되돌릴 수 없는 동작이라 그 사실을 먼저 말한다.** 선언하면 잠기고, 하루에 한 번뿐이다.
/// 고르는 화면과 경고를 한 장에 두어 "확인 다이얼로그를 또 띄우는" 단계를 없앴다.
class DeclareSheet extends ConsumerStatefulWidget {
  const DeclareSheet({required this.groupId, super.key});

  final int groupId;

  /// 선언했으면 결과를 돌려준다. 취소하면 null.
  static Future<Declaration?> show(BuildContext context, int groupId) {
    return showModalBottomSheet<Declaration>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DeclareSheet(groupId: groupId),
    );
  }

  @override
  ConsumerState<DeclareSheet> createState() => _DeclareSheetState();
}

class _DeclareSheetState extends ConsumerState<DeclareSheet> {
  final _selected = <int>{};
  bool _busy = false;
  String? _error;

  /// 서버가 한 번에 받는 상한과 같다.
  static const int _maxItems = 20;

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final declaration = await ref
          .read(groupRepositoryProvider)
          .declare(widget.groupId, todoIds: _selected.toList());
      if (mounted) Navigator.of(context).pop(declaration);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(selectedDateProvider);
    final todos = ref.watch(dayTodosControllerProvider(today));

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
            Text('오늘 뭘 하겠다고 말할까요', style: AppTypography.titleL),
            const SizedBox(height: AppSpacing.s4),
            Text(
              '선언하면 잠겨요. 제목을 바꾸거나 지울 수 없고, 하루에 한 번만 할 수 있어요.',
              style: AppTypography.caption.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: AppSpacing.s16),
            if (_error != null) ...[
              FormErrorBanner(message: _error!),
              const SizedBox(height: AppSpacing.s16),
            ],
            Flexible(
              child: todos.when(
                loading: () => const LoadingView(),
                error: (error, _) => Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.s24,
                  ),
                  child: Text(
                    '오늘 할 일을 불러오지 못했어요.',
                    style:
                        AppTypography.body.copyWith(color: AppColors.inkSub),
                  ),
                ),
                data: (day) {
                  // 이미 선언한 항목은 다시 고를 수 없다 (다른 그룹에 걸었어도 마찬가지).
                  final pickable = day.items
                      .where((t) => !t.isDeclared)
                      .toList(growable: false);
                  if (pickable.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.s16),
                      child: EmptyView(
                        imagePath: AppIllustrations.goalAdd,
                        title: '선언할 할 일이 없어요',
                        description: '오늘 탭에서 할 일을 먼저 적어 주세요.',
                      ),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: pickable.length,
                    itemBuilder: (context, index) {
                      final todo = pickable[index];
                      final checked = _selected.contains(todo.todoId);
                      return _PickRow(
                        title: todo.title,
                        minutes: todo.estimatedMinutes,
                        checked: checked,
                        enabled: !_busy &&
                            (checked || _selected.length < _maxItems),
                        onChanged: (next) => setState(() {
                          if (next) {
                            _selected.add(todo.todoId);
                          } else {
                            _selected.remove(todo.todoId);
                          }
                        }),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _selected.isEmpty || _busy ? null : _submit,
                child: Text(
                  _busy
                      ? '잠시만요'
                      : _selected.isEmpty
                          ? '할 일을 골라 주세요'
                          : '${_selected.length}개 선언하기',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickRow extends StatelessWidget {
  const _PickRow({
    required this.title,
    required this.minutes,
    required this.checked,
    required this.enabled,
    required this.onChanged,
  });

  final String title;
  final int? minutes;
  final bool checked;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? () => onChanged(!checked) : null,
      borderRadius: BorderRadius.circular(AppRadius.r8),
      child: Padding(
        // 48dp 터치 영역을 지킨다.
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            _Check(checked: checked, enabled: enabled),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body.copyWith(
                  color: enabled ? AppColors.ink : AppColors.disabled,
                ),
              ),
            ),
            if (minutes != null)
              Text(
                '$minutes분',
                style: AppTypography.caption.copyWith(color: AppColors.muted),
              ),
          ],
        ),
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.checked, required this.enabled});

  final bool checked;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: checked ? AppColors.purple : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.r4),
        border: Border.all(
          color: checked
              ? AppColors.purple
              : enabled
                  ? AppColors.line
                  : AppColors.disabled,
          width: 1.5,
        ),
      ),
      child: checked
          ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
          : null,
    );
  }
}
