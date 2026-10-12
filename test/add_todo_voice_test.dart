import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p2j_mobile/features/todo/presentation/voice_input_controller.dart';
import 'package:p2j_mobile/features/todo/presentation/widgets/add_todo_sheet.dart';
import 'package:p2j_mobile/features/todo/presentation/widgets/mic_button.dart';
import 'voice_input_controller_test.dart' show FakeSpeech;

class ControlledVoice extends VoiceInputController {
  ControlledVoice() : super(speech: FakeSpeech());
  final stopped = Completer<void>();
  int stops = 0;
  String recognized = '오늘 운동 30분';
  VoiceStatus current = VoiceStatus.idle;
  @override
  VoiceStatus get status => current;
  @override
  bool get isListening => current == VoiceStatus.listening;
  @override
  String get text => recognized;
  @override
  Future<void> start() async {
    current = VoiceStatus.listening;
    notifyListeners();
  }

  @override
  Future<void> stop() async {
    stops++;
    await stopped.future;
    current = recognized.isEmpty ? VoiceStatus.idle : VoiceStatus.done;
    notifyListeners();
  }
}

void main() {
  for (final viaMic in [false, true]) {
    testWidgets('종료 후 바로 문장을 반환한다 (마이크 버튼: $viaMic)', (tester) async {
      final voice = ControlledVoice();
      AddTodoResult? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('열기'),
                onPressed: () async {
                  result = await showModalBottomSheet<AddTodoResult>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => AddTodoSheet(voiceController: voice),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(MicButton));
      await tester.pump();
      expect(find.text('말 다 했어요 · 바로 정리'), findsOneWidget);
      await tester.tap(
        viaMic ? find.byType(MicButton) : find.text('말 다 했어요 · 바로 정리'),
      );
      await tester.pump();
      expect(find.byType(MicButton), findsNothing);
      expect(result, isNull);
      voice.stopped.complete();
      await tester.pumpAndSettle();
      expect(result, isA<SpokenSentence>());
      expect((result as SpokenSentence).text, '오늘 운동 30분');
      expect(voice.stops, 1);
    });
  }
  testWidgets('빈 음성은 정리 요청을 보내지 않는다', (tester) async {
    final voice = ControlledVoice()..recognized = '';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AddTodoSheet(voiceController: voice)),
      ),
    );
    await tester.tap(find.byType(MicButton));
    await tester.pump();
    await tester.tap(find.text('말 다 했어요 · 바로 정리'));
    voice.stopped.complete();
    await tester.pumpAndSettle();
    expect(find.byType(AddTodoSheet), findsOneWidget);
    expect(find.text('무엇을 할지 말해 주세요'), findsOneWidget);
  });
}
