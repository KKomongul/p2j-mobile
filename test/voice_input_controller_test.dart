import 'dart:async';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:p2j_mobile/features/todo/presentation/voice_input_controller.dart';

class FakeSpeech implements SpeechToText {
  Future<bool> ready = Future.value(true);
  SpeechResultListener? result;
  SpeechStatusListener? status;
  SpeechErrorListener? error;
  int listens = 0;
  @override
  dynamic noSuchMethod(Invocation invocation) {
    switch (invocation.memberName) {
      case #initialize:
        error = invocation.namedArguments[#onError] as SpeechErrorListener?;
        status = invocation.namedArguments[#onStatus] as SpeechStatusListener?;
        return ready;
      case #listen:
        listens++;
        result = invocation.namedArguments[#onResult] as SpeechResultListener?;
        return Future<void>.value();
      case #stop:
      case #cancel:
        return Future<void>.value();
      default:
        return super.noSuchMethod(invocation);
    }
  }
}

void main() {
  testWidgets('브라우저 network 오류는 무음으로 오인하지 않는다', (tester) async {
    final speech = FakeSpeech();
    final controller = VoiceInputController(speech: speech);
    await controller.start();
    speech.error!(SpeechRecognitionError('network', false));
    expect(controller.status, VoiceStatus.unavailable);
    expect(controller.errorMessage, contains('network'));
    speech.status!('done');
    await tester.pump(const Duration(seconds: 6));
    expect(controller.errorMessage, contains('network'));
    controller.dispose();
  });
  testWidgets('웹 무음 종료 후 실제 재청취 시작은 이전 오류 예약을 해제한다', (tester) async {
    final speech = FakeSpeech();
    final controller = VoiceInputController(speech: speech);
    await controller.start();
    speech.error!(SpeechRecognitionError('no-speech', false));
    await tester.pump(const Duration(milliseconds: 300));
    expect(speech.listens, 2);
    speech.status!('listening');
    await tester.pump(const Duration(seconds: 5));
    expect(controller.recognizerReady, isTrue);
    expect(controller.status, VoiceStatus.listening);
    expect(controller.errorMessage, isNull);
    controller.dispose();
  });
  testWidgets('브라우저 not-allowed는 권한 오류로 안내한다', (tester) async {
    final speech = FakeSpeech();
    final controller = VoiceInputController(speech: speech);
    await controller.start();
    speech.error!(SpeechRecognitionError('not-allowed', false));
    expect(controller.errorMessage, contains('권한'));
    controller.dispose();
  });

  testWidgets('무음 오류는 5초까지 기다리며 조기 종료 후 재청취한다', (tester) async {
    final speech = FakeSpeech();
    final controller = VoiceInputController(speech: speech);
    await controller.start();
    speech.error!(SpeechRecognitionError('error_no_match', true));
    speech.status!('done');
    await tester.pump(const Duration(milliseconds: 300));
    expect(speech.listens, 2);
    await tester.pump(const Duration(milliseconds: 4699));
    expect(controller.status, VoiceStatus.listening);
    expect(controller.errorMessage, isNull);
    await tester.pump(const Duration(milliseconds: 1));
    expect(controller.status, VoiceStatus.unavailable);
    controller.dispose();
  });
  testWidgets('수동 종료하면 예약된 무음 오류가 나중에 뜨지 않는다', (tester) async {
    final speech = FakeSpeech();
    final controller = VoiceInputController(speech: speech);
    await controller.start();
    speech.error!(SpeechRecognitionError('error_no_match', true));
    await controller.stop();
    await tester.pump(const Duration(seconds: 6));
    expect(controller.status, VoiceStatus.idle);
    expect(controller.errorMessage, isNull);
    expect(speech.listens, 1);
    controller.dispose();
  });
  testWidgets('권한 오류는 5초를 기다리지 않고 안내한다', (tester) async {
    final speech = FakeSpeech();
    final controller = VoiceInputController(speech: speech);
    await controller.start();
    speech.error!(SpeechRecognitionError('error_permission', true));
    expect(controller.status, VoiceStatus.unavailable);
    expect(controller.errorMessage, contains('권한'));
    controller.dispose();
  });

  test('마지막 인식 결과로 확인 상태가 되고 닫힌 뒤 콜백은 무시한다', () async {
    final speech = FakeSpeech();
    final controller = VoiceInputController(speech: speech);
    await controller.start();
    expect(controller.status, VoiceStatus.listening);
    final result = SpeechRecognitionResult.fromJson({
      'alternates': [
        {'recognizedWords': '오늘 요가 삼십 분', 'confidence': 1.0},
      ],
      'resultType': ResultType.finalResult.value,
    });
    speech.result!(result);
    expect(controller.status, VoiceStatus.done);
    expect(controller.text, '오늘 요가 삼십 분');
    controller.dispose();
    expect(() => speech.result!(result), returnsNormally);
    expect(() => speech.status!('done'), returnsNormally);
  });
  test('초기화 도중 닫히면 마이크를 켜지 않는다', () async {
    final ready = Completer<bool>();
    final speech = FakeSpeech()..ready = ready.future;
    final controller = VoiceInputController(speech: speech);
    final starting = controller.start();
    controller.dispose();
    ready.complete(true);
    await starting;
    expect(speech.listens, 0);
  });
  test('마이크를 사용할 수 없으면 글 입력 안내를 제공한다', () async {
    final controller = VoiceInputController(
      speech: FakeSpeech()..ready = Future.value(false),
    );
    await controller.start();
    expect(controller.status, VoiceStatus.unavailable);
    expect(controller.errorMessage, contains('글로'));
    controller.dispose();
  });
}
