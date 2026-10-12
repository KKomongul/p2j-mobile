import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p2j_mobile/features/ai/data/ai_models.dart';
import 'package:p2j_mobile/features/ai/data/ai_repository.dart';
import 'package:p2j_mobile/features/todo/presentation/widgets/ai_draft_sheet.dart';

class FakeAi implements AiRepository {
  @override
  Future<AiParseResult> parse({
    required String text,
    String? referenceDate,
    List<int>? goalIds,
  }) async => const AiParseResult(
    parseId: 'test-parse',
    parseMethod: ParseMethod.rules,
    drafts: [
      TodoDraft(
        draftId: 'a',
        title: '요가',
        date: '2026-09-30',
        estimatedMinutes: 90,
      ),
      TodoDraft(draftId: 'b', title: '독서', date: '2026-09-30'),
    ],
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('초안은 확인 전 반환하지 않고 수정한 내용으로 반환한다', (tester) async {
    AiDraftResult? result;
    var closed = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [aiRepositoryProvider.overrideWithValue(FakeAi())],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await AiDraftSheet.show(
                    context,
                    text: '요가하고 독서',
                    referenceDate: '2026-09-30',
                  );
                  closed = true;
                },
                child: const Text('입력'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('입력'));
    await tester.pumpAndSettle();
    expect(find.text('이해한 게 맞나요?'), findsOneWidget);
    expect(closed, isFalse);
    expect(result, isNull);
    await tester.enterText(find.byType(TextField).first, '아침 요가');
    await tester.tap(find.text('맞아요, 2개 추가하기'));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(result!.items.map((item) => item.title), ['아침 요가', '독서']);
    expect(result!.items.first.estimatedMinutes, 90);
    expect(result!.parseId, 'test-parse');
  });
  testWidgets('확인 화면을 닫으면 저장할 초안을 반환하지 않는다', (tester) async {
    AiDraftResult? result;
    var closed = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [aiRepositoryProvider.overrideWithValue(FakeAi())],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await AiDraftSheet.show(
                    context,
                    text: '요가',
                    referenceDate: '2026-09-30',
                  );
                  closed = true;
                },
                child: const Text('입력'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('입력'));
    await tester.pumpAndSettle();
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(result, isNull);
  });
}
