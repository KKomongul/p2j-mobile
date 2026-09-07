import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/form_controls.dart';
import '../data/goal_models.dart';
import '../data/goal_repository.dart';
import 'goal_provider.dart';

/// 새 목표 만들기.
///
/// 폼 화면이라 장식을 넣지 않는다. 종이 카드도 마스코트도 없다.
/// 대신 반복 목표의 결과("총 12번")를 입력하는 동안 계속 보여 준다.
/// 숫자를 다 채우고 나서야 무엇을 약속했는지 알게 되면 늦다.
///
/// 서버가 `type=recurring` 이면 `frequency` 를 요구하므로, 반복을 고르는
/// 순간 주 3회를 미리 채워 둔다. 빈 칸을 만들고 오류로 알리지 않는다.
class GoalCreateScreen extends ConsumerStatefulWidget {
  const GoalCreateScreen({super.key});

  /// 하단 탭 위로 전체 화면을 덮는다. 입력 중에는 다른 탭으로 갈 일이 없다.
  static Future<bool?> push(BuildContext context) {
    return Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const GoalCreateScreen()),
    );
  }

  @override
  ConsumerState<GoalCreateScreen> createState() => _GoalCreateScreenState();
}

class _GoalCreateScreenState extends ConsumerState<GoalCreateScreen> {
  final _titleController = TextEditingController();
  final _minutesController = TextEditingController();

  GoalType _type = GoalType.single;
  int _times = 3;
  FrequencyPer _per = FrequencyPer.week;
  int _weeks = 4;
  String? _color;

  bool _submitting = false;
  String? _titleError;
  String? _minutesError;
  String? _formError;

  bool get _isRecurring => _type == GoalType.recurring;

  /// 서버의 target_count 와 같은 식이다 (`frequency_times × duration_weeks`).
  int get _totalCount => _times * _weeks;

  @override
  void dispose() {
    _titleController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;

    final title = _titleController.text.trim();
    final minutesText = _minutesController.text.trim();
    final minutes = minutesText.isEmpty ? null : int.tryParse(minutesText);

    setState(() {
      _formError = null;
      _titleError = title.isEmpty
          ? '목표 이름을 알려주세요.'
          : title.length > 50
              ? '50자 안으로 줄여 주세요.'
              : null;
      _minutesError = minutes != null && (minutes < 1 || minutes > 1440)
          ? '1분에서 1440분 사이로 적어 주세요.'
          : null;
    });
    if (_titleError != null || _minutesError != null) return;

    setState(() => _submitting = true);
    try {
      await ref.read(goalRepositoryProvider).create(
            title: title,
            type: _type,
            color: _color,
            frequency: _isRecurring
                ? GoalFrequency(times: _times, per: _per)
                : null,
            durationWeeks: _isRecurring ? _weeks : null,
            estimatedMinutes: minutes,
          );
      ref.invalidate(activeGoalsProvider);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _titleError = error.fieldMessage('title');
        _minutesError = error.fieldMessage('estimated_minutes');
        if (_titleError == null && _minutesError == null) {
          _formError = error.message;
        }
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('새 목표'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: '닫기',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH,
                  AppSpacing.s8,
                  AppSpacing.screenH,
                  AppSpacing.s24,
                ),
                children: [
                  if (_formError != null) ...[
                    FormErrorBanner(message: _formError!),
                    const SizedBox(height: AppSpacing.s20),
                  ],
                  AppTextField(
                    label: '무엇을 이루고 싶으세요?',
                    controller: _titleController,
                    hintText: '주 3회 운동하기',
                    errorText: _titleError,
                    textInputAction: TextInputAction.next,
                    enabled: !_submitting,
                  ),
                  const SizedBox(height: AppSpacing.s24),
                  const FieldLabel('어떻게 할까요?'),
                  const SizedBox(height: AppSpacing.s8),
                  SegmentedChoice<GoalType>(
                    value: _type,
                    options: const <SegmentOption<GoalType>>[
                      SegmentOption(value: GoalType.single, label: '한 번만'),
                      SegmentOption(
                        value: GoalType.recurring,
                        label: '반복해서',
                      ),
                    ],
                    onChanged: _submitting
                        ? null
                        : (value) => setState(() => _type = value),
                  ),
                  if (_isRecurring) ...[
                    const SizedBox(height: AppSpacing.s24),
                    _frequencySection(),
                  ],
                  const SizedBox(height: AppSpacing.s24),
                  AppTextField(
                    label: '한 번에 얼마나 걸리나요? (선택)',
                    controller: _minutesController,
                    hintText: '분 단위로 입력',
                    errorText: _minutesError,
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    textInputAction: TextInputAction.done,
                    enabled: !_submitting,
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: AppSpacing.s24),
                  const FieldLabel('색 (선택)'),
                  const SizedBox(height: AppSpacing.s12),
                  ColorSwatches(
                    value: _color,
                    onChanged: _submitting
                        ? null
                        : (value) => setState(() => _color = value),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                0,
                AppSpacing.screenH,
                AppSpacing.s12,
              ),
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('목표 만들기'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _frequencySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FieldLabel('얼마나 자주?'),
        const SizedBox(height: AppSpacing.s8),
        Row(
          children: [
            SegmentedChoice<FrequencyPer>(
              value: _per,
              compact: true,
              options: const <SegmentOption<FrequencyPer>>[
                SegmentOption(value: FrequencyPer.week, label: '주'),
                SegmentOption(value: FrequencyPer.month, label: '달'),
              ],
              onChanged: _submitting
                  ? null
                  : (value) => setState(() => _per = value),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: CountStepper(
                value: _times,
                min: 1,
                max: 14,
                suffix: '회',
                onChanged: _submitting
                    ? null
                    : (value) => setState(() => _times = value),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s20),
        const FieldLabel('몇 주 동안?'),
        const SizedBox(height: AppSpacing.s8),
        CountStepper(
          value: _weeks,
          min: 1,
          max: 52,
          suffix: '주',
          onChanged: _submitting
              ? null
              : (value) => setState(() => _weeks = value),
        ),
        const SizedBox(height: AppSpacing.s12),
        // 숫자를 다 채우고 나서야 무엇을 약속했는지 알게 되면 늦다.
        Text(
          '$_weeks주 동안 총 $_totalCount번 하게 돼요.',
          style: AppTypography.caption.copyWith(color: AppColors.amberInk),
        ),
      ],
    );
  }
}
