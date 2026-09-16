import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/form_controls.dart';
import '../../data/group_models.dart';
import '../../data/group_repository.dart';

/// 그룹을 시작하는 두 갈래를 한 시트에 둔다 — **만들기**와 **코드로 참여**.
///
/// 화면을 둘로 나누면 "어느 쪽이었지" 를 매번 고르게 된다. 실제로는 한 명이 만들고
/// 나머지는 코드를 받는 구조라, 같은 자리에서 전환되는 편이 짧다.
class GroupStartSheet extends ConsumerStatefulWidget {
  const GroupStartSheet({this.startOnJoin = false, super.key});

  /// 참여 쪽을 먼저 보여 줄지. 목록의 "코드로 참여" 에서 들어오면 true.
  final bool startOnJoin;

  /// 만들거나 참여했으면 그 그룹을 돌려준다. 취소하면 null.
  static Future<Group?> show(BuildContext context, {bool join = false}) {
    return showModalBottomSheet<Group>(
      context: context,
      isScrollControlled: true,
      builder: (_) => GroupStartSheet(startOnJoin: join),
    );
  }

  @override
  ConsumerState<GroupStartSheet> createState() => _GroupStartSheetState();
}

enum _Mode { create, join }

class _GroupStartSheetState extends ConsumerState<GroupStartSheet> {
  late _Mode _mode = widget.startOnJoin ? _Mode.join : _Mode.create;
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();

  /// 신청서 기준 3~6명. 서버도 같은 범위를 강제한다.
  int _maxMembers = 6;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // 버튼 활성화가 입력 길이에 걸려 있다. 리스너가 없으면 글자를 넣어도 눌리지 않는다.
    _nameController.addListener(_onTyped);
    _codeController.addListener(_onTyped);
  }

  void _onTyped() => setState(() {});

  @override
  void dispose() {
    _nameController
      ..removeListener(_onTyped)
      ..dispose();
    _codeController
      ..removeListener(_onTyped)
      ..dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final repository = ref.read(groupRepositoryProvider);
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final group = _mode == _Mode.create
          ? await repository.create(
              name: _nameController.text.trim(),
              maxMembers: _maxMembers,
            )
          : await repository.join(_codeController.text.trim());
      if (mounted) Navigator.of(context).pop(group);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error.message;
        });
      }
    }
  }

  bool get _canSubmit {
    if (_busy) return false;
    return _mode == _Mode.create
        ? _nameController.text.trim().isNotEmpty
        : _codeController.text.trim().length >= 4;
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
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
              SegmentedChoice<_Mode>(
                value: _mode,
                onChanged: _busy
                    ? null
                    : (next) => setState(() {
                          _mode = next;
                          _error = null;
                        }),
                options: const [
                  SegmentOption(value: _Mode.create, label: '새로 만들기'),
                  SegmentOption(value: _Mode.join, label: '코드로 참여'),
                ],
              ),
              const SizedBox(height: AppSpacing.s20),
              if (_error != null) ...[
                FormErrorBanner(message: _error!),
                const SizedBox(height: AppSpacing.s16),
              ],
              if (_mode == _Mode.create) ..._createFields() else ..._joinFields(),
              const SizedBox(height: AppSpacing.s24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _canSubmit ? _submit : null,
                  child: Text(
                    _busy
                        ? '잠시만요'
                        : _mode == _Mode.create
                            ? '그룹 만들기'
                            : '참여하기',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _createFields() => [
        AppTextField(
          label: '그룹 이름',
          controller: _nameController,
          hintText: '3학년 개발조',
          enabled: !_busy,
          onSubmitted: (_) => _canSubmit ? _submit() : null,
        ),
        const SizedBox(height: AppSpacing.s20),
        const FieldLabel('최대 인원'),
        const SizedBox(height: AppSpacing.s8),
        CountStepper(
          value: _maxMembers,
          min: 3,
          max: 6,
          suffix: '명',
          onChanged: _busy ? null : (next) => setState(() => _maxMembers = next),
        ),
        const SizedBox(height: AppSpacing.s8),
        Text(
          '서로 얼굴이 보이는 크기라야 압력이 생겨요. 3~6명까지 만들 수 있어요.',
          style: AppTypography.caption.copyWith(color: AppColors.muted),
        ),
      ];

  List<Widget> _joinFields() => [
        AppTextField(
          label: '초대 코드',
          controller: _codeController,
          hintText: 'P2J-K3M9',
          enabled: !_busy,
          textInputAction: TextInputAction.done,
          // 코드는 대문자 고정이다. 소문자로 받아 적어도 그대로 통과시킨다.
          inputFormatters: [UpperCaseFormatter()],
          onSubmitted: (_) => _canSubmit ? _submit() : null,
        ),
        const SizedBox(height: AppSpacing.s8),
        Text(
          '그룹을 만든 사람에게 받은 코드를 넣어 주세요.',
          style: AppTypography.caption.copyWith(color: AppColors.muted),
        ),
      ];
}

/// 입력을 바로 대문자로 바꾼다. 초대 코드는 대문자만 쓴다.
class UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}
