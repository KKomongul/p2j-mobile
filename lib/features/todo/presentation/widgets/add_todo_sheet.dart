import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_illustrations.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../voice_input_controller.dart';
import 'mic_button.dart';

/// 추가 시트가 돌려주는 것.
sealed class AddTodoResult {
  const AddTodoResult();
}

/// 직접 적은 할 일 한 건. AI 를 거치지 않는 빠져나갈 길이다.
class ManualTodo extends AddTodoResult {
  const ManualTodo({required this.title, this.estimatedMinutes});

  final String title;
  final int? estimatedMinutes;
}

/// 말한 문장 그대로. 여러 할 일로 쪼개는 건 서버 `/ai/parse` 가 한다.
class SpokenSentence extends AddTodoResult {
  const SpokenSentence(this.text);

  final String text;
}

/// 할 일 추가 바텀시트.
///
/// 말하는 게 기본이다. 이 앱은 계획 세우는 일을 대신해 주는 앱이라,
/// 사용자가 문장을 다듬어 입력할 필요가 없어야 한다. 타이핑은 빠져나갈
/// 길로만 둔다.
///
/// 말이 끝나면 바로 보내지 않고 받아 적은 문장을 한 번 보여 준다.
/// 잘못 들었을 때 되돌릴 길이 없으면 음성 입력을 안 쓰게 된다.
class AddTodoSheet extends StatefulWidget {
  const AddTodoSheet({super.key});

  static Future<AddTodoResult?> show(BuildContext context) {
    return showModalBottomSheet<AddTodoResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const AddTodoSheet(),
    );
  }

  @override
  State<AddTodoSheet> createState() => _AddTodoSheetState();
}

enum _Mode {
  /// 마이크 대기·듣는 중.
  voice,

  /// 받아 적은 문장 확인.
  confirm,

  /// 말하듯 문장으로 적기. 마이크를 못 쓰는 사람도 AI 정리를 쓸 수 있어야 한다.
  dictate,

  /// 직접 한 건 적기.
  typing,
}

class _AddTodoSheetState extends State<AddTodoSheet> {
  final _voice = VoiceInputController();
  final _titleController = TextEditingController();
  final _minutesController = TextEditingController();
  final _sentenceController = TextEditingController();

  _Mode _mode = _Mode.voice;
  String _heard = '';
  String? _titleError;

  @override
  void initState() {
    super.initState();
    _voice.addListener(_onVoiceChanged);
  }

  @override
  void dispose() {
    _voice
      ..removeListener(_onVoiceChanged)
      ..dispose();
    _titleController.dispose();
    _minutesController.dispose();
    _sentenceController.dispose();
    super.dispose();
  }

  void _onVoiceChanged() {
    if (!mounted) return;
    if (_voice.status == VoiceStatus.done && _mode == _Mode.voice) {
      setState(() {
        _heard = _voice.text.trim();
        _mode = _Mode.confirm;
      });
      return;
    }
    setState(() {});
  }

  Future<void> _toggleListening() async {
    if (_voice.isListening) {
      await _voice.stop();
    } else {
      await _voice.start();
    }
  }

  void _submitManual() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = '무엇을 할지 알려주세요.');
      return;
    }
    Navigator.of(context).pop(
      ManualTodo(
        title: title,
        estimatedMinutes: int.tryParse(_minutesController.text.trim()),
      ),
    );
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
      child: switch (_mode) {
        _Mode.voice => _voiceView(),
        _Mode.confirm => _confirmView(),
        _Mode.dictate => _dictateView(),
        _Mode.typing => _typingView(),
      },
    );
  }

  Widget _voiceView() {
    final listening = _voice.isListening;
    final failed = _voice.status == VoiceStatus.unavailable;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          AppIllustrations.voiceInput,
          height: 130,
          fit: BoxFit.contain,
        ),
        Text(
          listening ? '듣고 있어요' : '무엇을 할지 말해 주세요',
          style: AppTypography.titleM,
        ),
        const SizedBox(height: AppSpacing.s8),
        Text(
          listening
              ? _voice.text.isEmpty
                  ? '편하게 말씀하세요'
                  : _voice.text
              : '"내일 발표 자료 만들고 저녁에 운동" 처럼 한 번에요',
          textAlign: TextAlign.center,
          style: AppTypography.caption.copyWith(
            color: listening && _voice.text.isNotEmpty
                ? AppColors.ink
                : AppColors.muted,
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        MicButton(listening: listening, onTap: _toggleListening),
        if (failed) ...[
          Text(
            _voice.errorMessage ?? '마이크를 쓸 수 없어요.',
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(color: AppColors.coral),
          ),
          const SizedBox(height: AppSpacing.s12),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () => setState(() => _mode = _Mode.dictate),
              child: const Text('글로 적을게요'),
            ),
            Text(
              '·',
              style: AppTypography.caption.copyWith(color: AppColors.disabled),
            ),
            TextButton(
              onPressed: () => setState(() => _mode = _Mode.typing),
              child: const Text('한 개만 직접'),
            ),
          ],
        ),
      ],
    );
  }

  /// 말하듯 문장으로 적는 화면. 보내는 곳은 음성과 같다.
  Widget _dictateView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('무엇을 할지 편하게 적어 주세요', style: AppTypography.titleM),
        const SizedBox(height: AppSpacing.s8),
        Text(
          '여러 개를 한 문장에 적어도 알아서 나눠 드려요.',
          style: AppTypography.caption.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: AppSpacing.s16),
        TextField(
          controller: _sentenceController,
          autofocus: true,
          maxLines: 3,
          minLines: 2,
          textInputAction: TextInputAction.newline,
          style: AppTypography.body,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: '내일 발표 자료 만들고 저녁에 운동 한 시간',
          ),
        ),
        const SizedBox(height: AppSpacing.s20),
        FilledButton(
          onPressed: _sentenceController.text.trim().isEmpty
              ? null
              : () => Navigator.of(context)
                  .pop(SpokenSentence(_sentenceController.text.trim())),
          child: const Text('정리해 주세요'),
        ),
        Center(
          child: TextButton(
            onPressed: () => setState(() => _mode = _Mode.voice),
            child: const Text('말로 할게요'),
          ),
        ),
      ],
    );
  }

  /// 받아 적은 문장 확인. 여기서 AI 로 보낼지, 손으로 고칠지 고른다.
  Widget _confirmView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('이렇게 들었어요', style: AppTypography.titleM),
        const SizedBox(height: AppSpacing.s12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.s16),
          decoration: BoxDecoration(
            color: AppColors.fill,
            borderRadius: BorderRadius.circular(AppRadius.r8),
          ),
          child: Text(_heard, style: AppTypography.body),
        ),
        const SizedBox(height: AppSpacing.s20),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop(SpokenSentence(_heard)),
          child: const Text('정리해 주세요'),
        ),
        const SizedBox(height: AppSpacing.s4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () {
                _titleController.text = _heard;
                setState(() => _mode = _Mode.typing);
              },
              child: const Text('직접 고칠게요'),
            ),
            Text('·', style: AppTypography.caption.copyWith(
              color: AppColors.disabled,
            )),
            TextButton(
              onPressed: () => setState(() => _mode = _Mode.voice),
              child: const Text('다시 말할게요'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _typingView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('무엇을 할까요?', style: AppTypography.titleM),
        const SizedBox(height: AppSpacing.s20),
        AppTextField(
          label: '할 일',
          controller: _titleController,
          hintText: '헬스장 가서 하체 운동',
          errorText: _titleError,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: AppSpacing.s16),
        AppTextField(
          label: '예상 소요시간 (선택)',
          controller: _minutesController,
          hintText: '분 단위로 입력',
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
          ],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submitManual(),
        ),
        const SizedBox(height: AppSpacing.s8),
        Text(
          '비워 두면 소요시간 없이 추가돼요.',
          style: AppTypography.caption.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: AppSpacing.s24),
        FilledButton(onPressed: _submitManual, child: const Text('추가')),
      ],
    );
  }
}
