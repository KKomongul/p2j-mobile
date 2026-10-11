import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// 그룹 안에서만 뜨는 하단 툴바.
///
/// 앱의 바텀 네비게이션(오늘 · 목표 · 그룹 · 통계)과 겹치지 않게, 그룹에 들어오면
/// 이 툴바가 그 자리를 대신한다. 엄지로 닿는 곳에 그룹 기능을 모은다.
///
/// 앞의 세 칸은 화면을 바꾸고, **초대** 는 화면을 바꾸지 않고 시트만 띄운다.
class GroupToolBar extends StatelessWidget {
  const GroupToolBar({
    required this.index,
    required this.onSelect,
    required this.onInvite,
    this.feedBadge = 0,
    super.key,
  });

  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback onInvite;

  /// 피드의 안 읽은 인증샷 수. 0 이면 점을 찍지 않는다.
  final int feedBadge;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.neutralLine)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _Item(
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: '홈',
                selected: index == 0,
                onTap: () => onSelect(0),
              ),
              _Item(
                icon: Icons.photo_library_outlined,
                activeIcon: Icons.photo_library_rounded,
                label: '피드',
                selected: index == 1,
                dot: feedBadge > 0,
                onTap: () => onSelect(1),
              ),
              _Item(
                icon: Icons.leaderboard_outlined,
                activeIcon: Icons.leaderboard_rounded,
                label: '순위',
                selected: index == 2,
                onTap: () => onSelect(2),
              ),
              _Item(
                icon: Icons.person_add_alt_outlined,
                activeIcon: Icons.person_add_alt_1_rounded,
                label: '초대',
                selected: false,
                onTap: onInvite,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.dot = false,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final bool dot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.ink : AppColors.disabled;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkResponse(
          onTap: onTap,
          radius: 32,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(selected ? activeIcon : icon, size: 24, color: color),
                  if (dot)
                    Positioned(
                      right: -3,
                      top: -1,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: AppColors.coral,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.s4),
              ExcludeSemantics(
                child: Text(
                  label,
                  style: AppTypography.label.copyWith(color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
