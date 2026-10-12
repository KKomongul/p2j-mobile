import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// 음성 입력의 상태.
enum VoiceStatus {
  /// 아직 시작하지 않음.
  idle,

  /// 듣는 중.
  listening,

  /// 말이 끝나 인식 결과를 들고 있음.
  done,

  /// 마이크 권한이 없거나 기기에 음성 인식기가 없음.
  unavailable,
}

/// 마이크로 받아 적는 일만 한다.
///
/// 받아 적은 문장은 확인·수정 후 서버 `/ai/parse`로 보낸다.
class VoiceInputController extends ChangeNotifier {
  VoiceInputController({SpeechToText? speech})
    : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;

  VoiceStatus _status = VoiceStatus.idle;
  String _text = '';
  String? _errorMessage;
  bool _disposed = false;
  bool _starting = false;
  bool _recognizerReady = false;
  bool get recognizerReady => _recognizerReady;
  Timer? _minimumWindow;
  Timer? _retry;
  String? _pendingFailure;
  bool _manualStop = false;
  int _session = 0;

  VoiceStatus get status => _status;

  /// 지금까지 받아 적은 문장. 듣는 동안에도 계속 갱신된다.
  String get text => _text;

  String? get errorMessage => _errorMessage;

  bool get isListening => _status == VoiceStatus.listening;

  Future<void> start() async {
    if (_disposed || _starting || isListening) return;
    _starting = true;
    _errorMessage = null;
    _recognizerReady = false;
    _text = '';
    _manualStop = false;
    _session++;
    _clearTimers();
    try {
      final ready = await _speech.initialize(
        onStatus: _handleStatus,
        onError: (error) {
          if (_disposed || _manualStop) return;
          final code = error.errorMsg.toLowerCase().replaceAll('-', '_');
          if (code.contains('permission') || code.contains('not_allowed')) {
            _fail('마이크 또는 음성 인식 권한이 차단됐어요. 브라우저 권한을 확인해 주세요.');
          } else if (code.contains('network')) {
            _fail(
              '브라우저 음성 인식 서비스에 연결하지 못했어요 (network). '
              'Chrome 또는 Edge에서 같은 주소를 열어 다시 시도해 주세요.',
            );
          } else if (code.contains('audio_capture')) {
            _fail('마이크 입력 장치를 사용할 수 없어요. PC의 입력 장치와 마이크 권한을 확인해 주세요.');
          } else if (code.contains('not_supported') ||
              code.contains('not supported')) {
            _fail('이 브라우저에서는 음성 인식을 지원하지 않아요. Chrome 또는 Edge에서 열어 주세요.');
          } else if (code.contains('aborted')) {
            // 재청취를 위한 cancel()이 만든 종료 이벤트는 오류로 표시하지 않는다.
            if (_retry == null) _fail('음성 인식이 중단됐어요. 마이크 버튼을 눌러 다시 시작해 주세요.');
          } else if (code.contains('no_match') ||
              code.contains('no_speech') ||
              code.contains('speech_timeout')) {
            _noSpeech();
          } else {
            _fail('음성 인식 서비스를 시작하지 못했어요. 오류: $code');
          }
        },
      );
      if (_disposed) return;
      if (!ready) {
        _fail('이 환경에서 마이크를 쓸 수 없어요. 권한을 확인하거나 글로 적어 주세요.');
        return;
      }
      _status = VoiceStatus.listening;
      notifyListeners();
      _minimumWindow = Timer(const Duration(seconds: 5), () {
        _minimumWindow = null;
        final failure = _pendingFailure;
        if (failure != null && !_manualStop) _fail(failure);
      });
      await _listen();
    } catch (_) {
      _fail('음성 입력을 시작하지 못했어요. 다시 시도하거나 글로 적어 주세요.');
    } finally {
      _starting = false;
    }
  }

  Future<void> _listen() async {
    await _speech.listen(
      listenOptions: SpeechListenOptions(
        localeId: kIsWeb ? 'ko-KR' : 'ko_KR',
        pauseFor: const Duration(seconds: 5),
        listenFor: const Duration(seconds: 60),
        partialResults: true,
        cancelOnError: true,
      ),
      onResult: (result) {
        if (_disposed) return;
        if (result.recognizedWords.trim().isNotEmpty) _pendingFailure = null;
        _text = result.recognizedWords;
        if (result.finalResult && _text.trim().isEmpty && !_manualStop) {
          _noSpeech();
          return;
        }
        if (result.finalResult) {
          _clearTimers();
          _status = _text.trim().isEmpty ? VoiceStatus.idle : VoiceStatus.done;
        }
        notifyListeners();
      },
    );
  }

  void _clearTimers() {
    _minimumWindow?.cancel();
    _minimumWindow = null;
    _retry?.cancel();
    _retry = null;
    _pendingFailure = null;
  }

  void _delayedFailure(String message) {
    if (_disposed || _manualStop) return;
    if (_minimumWindow?.isActive ?? false) {
      _pendingFailure = message;
    } else {
      _fail(message);
    }
  }

  void _noSpeech() {
    if (_disposed || _manualStop) return;
    const message = '음성을 인식하지 못했어요. 다시 말하거나 글로 적어 주세요.';
    _delayedFailure(message);
    if (!(_minimumWindow?.isActive ?? false) || _retry != null) return;
    final session = _session;
    // 브라우저가 무음으로 일찍 종료하면 5초 입력 구간 안에서 다시 듣는다.
    _retry = Timer(const Duration(milliseconds: 300), () async {
      try {
        await _speech.cancel();
        if (_disposed ||
            _manualStop ||
            session != _session ||
            !(_minimumWindow?.isActive ?? false)) {
          return;
        }
        await _listen();
      } catch (_) {
        _delayedFailure(message);
      } finally {
        _retry = null;
      }
    });
  }

  Future<void> stop() async {
    _manualStop = true;
    _clearTimers();
    try {
      await _speech.stop();
    } catch (_) {
      _fail('녹음을 마치지 못했어요. 다시 시도해 주세요.');
      return;
    }
    if (_disposed) return;
    _status = _text.trim().isEmpty ? VoiceStatus.idle : VoiceStatus.done;
    notifyListeners();
  }

  Future<void> cancel() async {
    _manualStop = true;
    _session++;
    _clearTimers();
    await _speech.cancel();
    if (_disposed) return;
    _text = '';
    _status = VoiceStatus.idle;
    notifyListeners();
  }

  void _handleStatus(String status) {
    // 사용자가 말을 멈추면 플러그인이 알아서 끝낸다.
    if (_disposed || _manualStop) return;
    if (status == 'listening') {
      _recognizerReady = true;
      _pendingFailure = null;
      notifyListeners();
      return;
    }
    if (status != 'done') return;
    if (_status != VoiceStatus.listening || _manualStop) return;
    if (_text.trim().isEmpty) {
      _noSpeech();
      return;
    }
    _clearTimers();
    _status = _text.trim().isEmpty ? VoiceStatus.idle : VoiceStatus.done;
    notifyListeners();
  }

  void _fail(String message) {
    if (_disposed) return;
    _clearTimers();
    _recognizerReady = false;
    _status = VoiceStatus.unavailable;
    _errorMessage = message;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _clearTimers();
    _speech.cancel().catchError((Object _) {});
    super.dispose();
  }
}
