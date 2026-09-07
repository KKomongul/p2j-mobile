import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../data/todo_models.dart';

/// 투두 한 줄.
///
/// 카드가 아니라 평면 위 divider 행이다. 여기는 장식을 넣지 않는다.
/// 목록은 훑는 곳이라 라운드·그림자·일러스트가 있으면 읽는 속도가 떨어진다.
/// 상태는 색이 아니라 칩의 글자로 먼저 읽히게 한다.
class TodoTile extends StatelessWidget {
  const TodoTile({
    required this.todo,
    required this.onToggle,
    required this.onLockedTap,
    super.key,
  });

  final Todo todo;
  final VoidCallback onToggle;
  final VoidCallback onLockedTap;

  @override
  Widget build(BuildContext context) {
    final done = todo.status.isDone;
    final inactive = todo.status.isInactive;

    return InkWell(
      onTap: todo.isDeclared && !done ? onLockedTap : onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s20,
          vertical: AppSpacing.s16,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Checkbox(done: done, inactive: inactive, onTap: onToggle),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          todo.title,
                          style: AppTypography.body.copyWith(
                            color: done || inactive
                                ? AppColors.disabled
                                : AppColors.ink,
                            decoration:
                                done ? TextDecoration.lineThrough : null,
                            decorationColor: AppColors.muted,
                          ),
                        ),
                      ),
                      if (_badgeLabel != null) ...[
                        const SizedBox(width: AppSpacing.s8),
                        StatusChip(label: _badgeLabel!, tone: _badgeTone),
                      ],
                    ],
                  ),
                  if (_subtitle.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      _subtitle,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (todo.isDeclared) ...[
              const SizedBox(width: AppSpacing.s8),
              const StatusChip(
                label: '선언',
                tone: ChipTone.active,
                icon: Icons.lock_outline_rounded,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// deferred/skipped 는 정해진 이름으로, 모르는 값은 원문 그대로 보여준다.
  /// 조용히 숨기면 서버가 값을 추가했을 때 아무도 눈치채지 못한다.
  String? get _badgeLabel {
    if (todo.status == TodoStatus.unknown) return todo.rawStatus;
    return todo.status.badgeLabel;
  }

  /// 미룸은 되돌릴 수 있는 경고, 모르는 값은 중립으로 둔다.
  ChipTone get _badgeTone => switch (todo.status) {
        TodoStatus.deferred => ChipTone.warn,
        TodoStatus.skipped => ChipTone.neutral,
        _ => ChipTone.neutral,
      };

  String get _subtitle {
    final parts = <String>[
      if (todo.goalTitle != null) todo.goalTitle!,
      if (todo.estimatedMinutes != null) '${todo.estimatedMinutes}분',
    ];
    return parts.join(' · ');
  }
}

class _Checkbox extends StatelessWidget {
  const _Checkbox({
    required this.done,
    required this.inactive,
    required this.onTap,
  });

  final bool done;
  final bool inactive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutBack,
        width: 24,
        height: 24,
        margin: const EdgeInsets.only(top: 2),
        decoration: BoxDecoration(
          color: done ? AppColors.mintInk : AppColors.surface,
          shape: BoxShape.circle,
          border: done
              ? null
              : Border.all(
                  color: inactive
                      ? AppColors.line
                      : AppColors.line,
                  width: 1.5,
                ),
        ),
        child: done
            ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
            : null,
      ),
    );
  }
}
