import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p2j_mobile/features/todo/data/todo_models.dart';
import 'package:p2j_mobile/features/todo/presentation/widgets/todo_tile.dart';
import 'package:p2j_mobile/features/todo/presentation/widgets/todo_rename_dialog.dart';

void main() {
  testWidgets('항목 메뉴 선택이 완료 체크를 변경하지 않는다', (tester) async {
    var toggles = 0;
    var renames = 0;
    var deletes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TodoTile(
            todo: const Todo(
              todoId: 1,
              title: '운동',
              date: '2026-09-30',
              status: TodoStatus.pending,
            ),
            onToggle: () => toggles++,
            onLockedTap: () {},
            onAttachProof: () {},
            onChangeGoal: () {},
            onRename: () => renames++,
            onDelete: () => deletes++,
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('할 일 메뉴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('이름 수정'));
    await tester.pumpAndSettle();
    expect(renames, 1);
    expect(toggles, 0);
    await tester.tap(find.byTooltip('할 일 메뉴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제하기'));
    await tester.pumpAndSettle();
    expect(deletes, 1);
    expect(toggles, 0);
  });

  testWidgets('이름 수정은 빈 이름을 막고 저장 실패 시 입력을 보존한다', (tester) async {
    var saves = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TodoRenameDialog(
            title: '운동',
            onSave: (title) async {
              saves++;
              throw Exception('offline');
            },
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.text('저장'));
    await tester.pump();
    expect(find.text('이름을 입력해 주세요.'), findsOneWidget);
    expect(saves, 0);
    await tester.enterText(find.byType(TextField), '아침 운동');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(saves, 1);
    expect(find.text('저장하지 못했어요. 다시 시도해 주세요.'), findsOneWidget);
    expect(find.text('아침 운동'), findsOneWidget);
  });
}
