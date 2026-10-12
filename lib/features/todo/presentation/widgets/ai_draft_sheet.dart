import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_illustrations.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../ai/data/ai_models.dart';
import '../../../ai/data/ai_repository.dart';
import '../../data/todo_models.dart';

/// 사용자가 확인을 마친 초안. 이것만 서버에 저장한다.
class AiDraftResult {
  const AiDraftResult({required this.items, this.parseId});

  final List<TodoDraftInput> items;

  /// `/ai/parse` 가 준 식별자. `POST /todos/bulk` 에 그대로 돌려준다.
  final String? parseId;
}

/// 말한 문장을 서버가 쪼갠 결과를 보여 주고, 저장할 것만 고르게 한다.
///
/// **여기까지는 아무것도 저장되지 않는다.** `/ai/parse` 는 초안만 돌려주고,
/// 실제 생성은 사용자가 확인 버튼을 누른 뒤 `POST /todos/bulk` 로 한 번에 한다.
///
/// AI가 틀릴 수 있다는 전제로 만든다. 제목은 바로 고칠 수 있게 열어 두고,
/// 확신이 낮거나 규칙 파서로 내려온 결과는 그렇다고 말해 준다.
class AiDraftSheet extends ConsumerStatefulWidget {
  const AiDraftSheet({
    required this.text,
    required this.referenceDate,
    super.key,
  });

  final String text;
  final String referenceDate;

  static Future<AiDraftResult?> show(
    BuildContext context, {
    required String text,
    required String referenceDate,
  }) {
    return showModalBottomSheet<AiDraftResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AiDraftSheet(text: text, referenceDate: referenceDate),
    );
  }

  @override
  ConsumerState<AiDraftSheet> createState() => _AiDraftSheetState();
}

class _AiDraftSheetState extends ConsumerState<AiDraftSheet> {
  AiParseResult? _result;
  ApiException? _error;

  /// 초안별 제목 편집기. draft_id 로 묶는다.
  final Map<String, TextEditingController> _titles = {};
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _parse();
  }

  @override
  void dispose() {
    for (final controller in _titles.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _parse() async {
    setState(() {
      _result = null;
      _error = null;
    });
    try {
      final result = await ref
          .read(aiRepositoryProvider)
          .parse(text: widget.text, referenceDate: widget.referenceDate);
      if (!mounted) return;
      for (final controller in _titles.values) {
        controller.dispose();
      }
      _titles.clear();
      _selected.clear();
      for (final draft in result.drafts) {
        _titles[draft.draftId] = TextEditingController(text: draft.title);
        _selected.add(draft.draftId);
      }
      setState(() => _result = result);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  void _confirm() {
    final result = _result;
    if (result == null) return;

    final items = <TodoDraftInput>[];
    for (final draft in result.drafts) {
      if (!_selected.contains(draft.draftId)) continue;
      final title = _titles[draft.draftId]?.text.trim() ?? '';
      if (title.isEmpty) continue;
      items.add(
        TodoDraftInput(
          title: title,
          date: draft.date,
          goalId: draft.goalId,
          estimatedMinutes: draft.estimatedMinutes,
        ),
      );
    }
    if (items.isEmpty) return;

    Navigator.of(
      context,
    ).pop(AiDraftResult(items: items, parseId: result.parseId));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.screenH,
        right: AppSpacing.screenH,
        top: AppSpacing.s8,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.s24,
      ),
      child: switch ((_error, _result)) {
        (final ApiException error, _) => _errorView(error),
        (_, final AiParseResult result) => _draftsView(result),
        _ => const _LoadingView(),
      },
    );
  }

  // ------------------------------------------------------------------ 오류

  Widget _errorView(ApiException error) {
    final quota = error.code == ApiErrorCode.aiQuotaExceeded;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(AppIllustrations.loadAdjust, height: 120),
        const SizedBox(height: AppSpacing.s12),
        Text(
          quota ? '조금 쉬었다 할까요?' : '지금은 정리해 드리기 어려워요',
          style: AppTypography.titleM,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.s8),
        Text(
          error.message,
          textAlign: TextAlign.center,
          style: AppTypography.caption.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: AppSpacing.s20),
        FilledButton(
          onPressed: () => Navigator.of(
            context,
          ).pop(AiDraftResult(items: [TodoDraftInput(title: widget.text)])),
          child: const Text('말한 그대로 추가할게요'),
        ),
        if (!quota) TextButton(onPressed: _parse, child: const Text('다시 시도')),
      ],
    );
  }

  // ------------------------------------------------------------------ 초안

  Widget _draftsView(AiParseResult result) {
    final count = _selected.where((id) {
      return (_titles[id]?.text.trim().isNotEmpty ?? false);
    }).length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('이해한 게 맞나요?', style: AppTypography.titleM)),
            if (result.parseMethod.needsReview)
              const StatusChip(label: '확인 필요', tone: ChipTone.warn)
            else
              const StatusChip(label: 'AI 검수', tone: ChipTone.active),
          ],
        ),
        const SizedBox(height: AppSpacing.s4),
        Text(
          result.quotaExceeded
              ? '오늘 AI 사용을 많이 하셨어요. 간단히 나눠 두었으니 확인해 주세요.'
              : '저장할 항목을 골라 주세요. 완료 체크는 저장 후 할 수 있어요.',
          style: AppTypography.caption.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: AppSpacing.s16),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: result.drafts.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, index) => _DraftRow(
              draft: result.drafts[index],
              controller: _titles[result.drafts[index].draftId]!,
              selected: _selected.contains(result.drafts[index].draftId),
              referenceDate: widget.referenceDate,
              onToggle: () => setState(() {
                final id = result.drafts[index].draftId;
                _selected.contains(id)
                    ? _selected.remove(id)
                    : _selected.add(id);
              }),
              onChanged: () => setState(() {}),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s16),
        FilledButton(
          onPressed: count == 0 ? null : _confirm,
          child: Text(count == 0 ? '추가할 항목을 골라 주세요' : '맞아요, $count개 추가하기'),
        ),
      ],
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(AppIllustrations.aiPlan, height: 130),
        const SizedBox(height: AppSpacing.s12),
        Text('말씀하신 걸 정리하고 있어요', style: AppTypography.titleM),
        const SizedBox(height: AppSpacing.s16),
        const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(height: AppSpacing.s24),
      ],
    );
  }
}

/// 초안 한 줄. 체크 · 제목(수정 가능) · AI 가 잡은 날짜와 시간.
class _DraftRow extends StatelessWidget {
  const _DraftRow({
    required this.draft,
    required this.controller,
    required this.selected,
    required this.referenceDate,
    required this.onToggle,
    required this.onChanged,
  });

  final TodoDraft draft;
  final TextEditingController controller;
  final bool selected;
  final String referenceDate;
  final VoidCallback onToggle;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Check(selected: selected, onTap: onToggle),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  enabled: selected,
                  onChanged: (_) => onChanged(),
                  style: AppTypography.body.copyWith(
                    color: selected ? AppColors.ink : AppColors.disabled,
                  ),
                  decoration: const InputDecoration(
                    filled: false,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                  ),
                ),
                const SizedBox(height: AppSpacing.s4),
                Wrap(
                  spacing: AppSpacing.s4,
                  runSpacing: AppSpacing.s4,
                  children: [
                    StatusChip(label: _dateLabel),
                    if (draft.timeHint?.label != null)
                      StatusChip(label: draft.timeHint!.label!),
                    if (draft.estimatedMinutes != null)
                      StatusChip(label: '${draft.estimatedMinutes}분'),
                    if (draft.goalTitle != null)
                      StatusChip(
                        label: draft.goalTitle!,
                        tone: ChipTone.active,
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

  /// 오늘·내일은 그대로 읽히게, 나머지는 날짜로.
  String get _dateLabel {
    final base = DateTime.tryParse(referenceDate);
    final target = DateTime.tryParse(draft.date);
    if (base == null || target == null) return draft.date;
    final diff = target.difference(base).inDays;
    return switch (diff) {
      0 => '오늘',
      1 => '내일',
      2 => '모레',
      _ => DateFormat('M월 d일 (E)', 'ko_KR').format(target),
    };
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 24,
        height: 24,
        margin: const EdgeInsets.only(top: 2),
        decoration: BoxDecoration(
          color: selected ? AppColors.mintInk : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.r4),
          border: selected
              ? null
              : Border.all(color: AppColors.line, width: 1.5),
        ),
        child: selected
            ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
            : null,
      ),
    );
  }
}
