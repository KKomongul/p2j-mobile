import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_illustrations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/speech_bubble.dart';
import '../../../core/widgets/typewriter_text.dart';
import '../../auth/presentation/auth_controller.dart';
import 'widgets/onboarding_answer.dart';

/// 로그인하지 않은 사용자가 앱을 켤 때 항상 보는 화면.
///
/// **가입도 로그인도 여기서 끝난다.** 폼 화면을 따로 두지 않는다.
/// 이 앱은 계획 세우는 일을 대신해 주는 앱이라, 첫 화면부터 한 번에 여러 칸을
/// 채우게 하면 안 된다. 한 화면에 한 문장, 한 번에 한 가지만 묻는다.
///
/// 로그인만 밝은 배경의 일반 폼으로 두면 같은 앱으로 보이지 않는다.
/// 이미 계정이 있는 사람도 같은 말투, 같은 화면에서 받는다.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

enum _Step {
  // 가입 이야기
  mbti,
  name,
  difficulty,
  promise,
  together,
  email,
  password,
  // 이미 계정이 있는 사람
  welcomeBack,
  loginEmail,
  loginPassword,
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  _Step _step = _Step.mbti;
  bool _typed = false;
  bool _submitting = false;
  String? _error;
  String _name = '';
  Timer? _autoAdvance;

  /// 답을 받지 않고 스스로 넘어가는 줄과 그 뜸.
  static const Map<_Step, Duration> _autoAdvanceAfter = <_Step, Duration>{
    _Step.difficulty: Duration(milliseconds: 1100),
    _Step.promise: Duration(milliseconds: 1500),
    _Step.together: Duration(milliseconds: 1200),
    _Step.welcomeBack: Duration(milliseconds: 1200),
  };

  /// 다음 줄. 가입과 로그인 두 갈래가 한 enum 에 있어 순서를 직접 적는다.
  /// enum 순서에 기대면 가입 마지막 줄에서 로그인 줄로 흘러간다.
  static const Map<_Step, _Step> _nextStep = <_Step, _Step>{
    _Step.mbti: _Step.name,
    _Step.name: _Step.difficulty,
    _Step.difficulty: _Step.promise,
    _Step.promise: _Step.together,
    _Step.together: _Step.email,
    _Step.email: _Step.password,
    _Step.welcomeBack: _Step.loginEmail,
    _Step.loginEmail: _Step.loginPassword,
    // password 와 loginPassword 는 제출로 끝난다.
  };

  @override
  void dispose() {
    _autoAdvance?.cancel();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String get _line => switch (_step) {
        _Step.mbti => '당신의 MBTI는 무엇인가요?',
        _Step.name => '이름은 무엇인가요?',
        _Step.difficulty => '계획 세우기 어려우신가요?',
        _Step.promise => '$_name님 계획은 저희가 관리할게요!',
        _Step.together => '저희 함께 시작해봐요',
        _Step.email => '이메일을 알려주세요',
        _Step.password => '비밀번호를 만들어주세요',
        _Step.welcomeBack => '다시 만나 반가워요',
        _Step.loginEmail => '어떤 이메일로 오셨나요?',
        _Step.loginPassword => '비밀번호를 입력해 주세요',
      };

  /// 줄마다 포즈가 바뀐다. 같은 그림이 계속 나오면 금방 질린다.
  String get _illustration => switch (_step) {
        _Step.difficulty => AppIllustrations.loadAdjust,
        _Step.promise => AppIllustrations.aiPlan,
        _Step.together => AppIllustrations.achievement,
        _Step.welcomeBack => AppIllustrations.achievement,
        _ => AppIllustrations.mascot,
      };

  void _onTyped() {
    if (!mounted) return;
    setState(() => _typed = true);
    final delay = _autoAdvanceAfter[_step];
    if (delay != null) _autoAdvance = Timer(delay, _advance);
  }

  /// 줄을 바꾸는 유일한 통로. 예약된 자동 진행을 반드시 취소한다.
  void _goTo(_Step next, {String? error, bool showFieldNow = false}) {
    if (!mounted) return;
    _autoAdvance?.cancel();
    setState(() {
      _step = next;
      _typed = showFieldNow;
      _error = error;
    });
  }

  void _advance() {
    final next = _nextStep[_step];
    if (next != null) _goTo(next);
  }

  // ---------------------------------------------------------------- 가입

  void _submitName() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '이름을 입력해 주세요.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _name = name);
    _advance();
  }

  void _submitEmail() {
    final email = _emailController.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = '이메일 형식이 올바르지 않아요.');
      return;
    }
    FocusScope.of(context).unfocus();
    _advance();
  }

  Future<void> _submitPassword() async {
    if (_submitting) return;
    final password = _passwordController.text;
    if (password.length < 8) {
      setState(() => _error = '비밀번호는 8자 이상으로 만들어 주세요.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).signup(
            email: _emailController.text.trim(),
            password: password,
            nickname: _name,
          );
      // 가입에 성공하면 라우터가 홈으로 옮긴다.
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.code == ApiErrorCode.emailAlreadyExists) {
        // 이미 있는 계정이면 이메일을 다시 묻지 않고 비밀번호부터 이어 받는다.
        _passwordController.clear();
        _goTo(
          _Step.loginPassword,
          error: '이미 가입된 이메일이에요. 비밀번호를 입력하면 이어서 시작할게요.',
          showFieldNow: true,
        );
      } else {
        setState(() => _error = error.message);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // -------------------------------------------------------------- 로그인

  void _submitLoginEmail() {
    final email = _emailController.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = '이메일 형식이 올바르지 않아요.');
      return;
    }
    FocusScope.of(context).unfocus();
    _advance();
  }

  Future<void> _submitLogin() async {
    if (_submitting) return;
    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() => _error = '비밀번호를 입력해 주세요.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).login(
            email: _emailController.text.trim(),
            password: password,
          );
      // 로그인에 성공하면 라우터가 홈으로 옮긴다.
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = switch (error.code) {
          ApiErrorCode.invalidCredentials => '이메일 또는 비밀번호가 맞지 않아요.',
          ApiErrorCode.validationError => error.fieldMessage('password') ??
              error.fieldMessage('email') ??
              error.message,
          _ => error.message,
        };
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// 로그인 갈래에서 가입 이야기로 되돌아간다. 앞서 입력한 값은 지운다.
  void _restartStory() {
    _nameController.clear();
    _emailController.clear();
    _passwordController.clear();
    _name = '';
    _goTo(_Step.mbti);
  }

  // ---------------------------------------------------------------- 화면

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.navy,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(child: Center(child: _stage())),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s24,
                  0,
                  AppSpacing.s24,
                  AppSpacing.s16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_field() != null) ...[
                      FadeSlideIn(visible: _typed, child: _field()!),
                      const SizedBox(height: AppSpacing.s16),
                    ],
                    FadeSlideIn(visible: _typed, child: _action()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stage() {
    // 키보드가 올라오면 마스코트를 접는다. 말풍선과 입력칸이 먼저다.
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SpeechBubble(
            child: TypewriterText(
              key: ValueKey(_step),
              text: _line,
              textAlign: TextAlign.center,
              startDelay: const Duration(milliseconds: 320),
              style: AppTypography.story.copyWith(color: AppColors.ink),
              onCompleted: _onTyped,
            ),
          ),
          if (!keyboardOpen) ...[
            const SizedBox(height: AppSpacing.s12),
            Flexible(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                child: Image.asset(
                  _illustration,
                  key: ValueKey(_illustration),
                  height: 260,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget? _field() {
    switch (_step) {
      case _Step.name:
        return OnboardingField(
          key: const ValueKey('name'),
          controller: _nameController,
          hintText: '이름',
          errorText: _error,
          onSubmitted: _submitName,
        );
      case _Step.email:
        return OnboardingField(
          key: const ValueKey('email'),
          controller: _emailController,
          hintText: 'name@example.com',
          keyboardType: TextInputType.emailAddress,
          errorText: _error,
          onSubmitted: _submitEmail,
        );
      case _Step.password:
        return OnboardingField(
          key: const ValueKey('password'),
          controller: _passwordController,
          hintText: '8자 이상',
          obscureText: true,
          errorText: _error,
          onSubmitted: _submitPassword,
        );
      case _Step.loginEmail:
        return OnboardingField(
          key: const ValueKey('loginEmail'),
          controller: _emailController,
          hintText: 'name@example.com',
          keyboardType: TextInputType.emailAddress,
          errorText: _error,
          onSubmitted: _submitLoginEmail,
        );
      case _Step.loginPassword:
        return OnboardingField(
          key: const ValueKey('loginPassword'),
          controller: _passwordController,
          hintText: '비밀번호',
          obscureText: true,
          errorText: _error,
          onSubmitted: _submitLogin,
        );
      default:
        return null;
    }
  }

  Widget _action() {
    switch (_step) {
      case _Step.mbti:
        return Column(
          children: [
            OnboardingChoices(
              options: const ['P', 'J'],
              onSelected: (_) => _advance(),
            ),
            const SizedBox(height: AppSpacing.s8),
            _linkButton('이미 계정이 있어요', () => _goTo(_Step.welcomeBack)),
          ],
        );
      case _Step.name:
        return _primary('확인', _submitName);
      case _Step.email:
        return _primary('다음', _submitEmail);
      case _Step.password:
        return _primary('가입하고 시작하기', _submitPassword, busy: _submitting);
      case _Step.loginEmail:
        return Column(
          children: [
            _primary('다음', _submitLoginEmail),
            const SizedBox(height: AppSpacing.s8),
            _linkButton('계정이 없다면 가입하기', _restartStory),
          ],
        );
      case _Step.loginPassword:
        return Column(
          children: [
            _primary('로그인', _submitLogin, busy: _submitting),
            const SizedBox(height: AppSpacing.s8),
            _linkButton('계정이 없다면 가입하기', _submitting ? null : _restartStory),
          ],
        );
      case _Step.difficulty:
      case _Step.promise:
      case _Step.together:
      case _Step.welcomeBack:
        return const SizedBox(height: 54);
    }
  }

  Widget _primary(String label, VoidCallback onPressed, {bool busy = false}) {
    return FilledButton(
      style: AppTheme.filledOnNavy(),
      onPressed: busy ? null : onPressed,
      child: busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.onAmber,
              ),
            )
          : Text(label),
    );
  }

  Widget _linkButton(String label, VoidCallback? onPressed) {
    return TextButton(
      onPressed: onPressed,
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: AppColors.onNavyMuted,
        ),
      ),
    );
  }
}
