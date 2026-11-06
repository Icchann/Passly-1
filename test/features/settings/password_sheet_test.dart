import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:passly/features/settings/presentation/settings_screen.dart';
import 'package:passly/features/settings/presentation/settings_sheets.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> openDialog(WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SettingsScreen())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('パスワードを変更'));
    await tester.pumpAndSettle();
  }

  testWidgets('visibility toggles affect only their own field', (tester) async {
    await openDialog(tester);
    final fields = find.byType(TextField);
    for (var i = 0; i < 3; i++) {
      final toggle = find.descendant(
        of: find.byType(TextFormField).at(i),
        matching: find.byType(IconButton),
      );
      await tester.tap(toggle);
      await tester.pump();
      for (var j = 0; j < 3; j++) {
        expect(tester.widget<TextField>(fields.at(j)).obscureText, j != i);
      }
      await tester.tap(toggle);
      await tester.pump();
      expect(
        tester.widgetList<TextField>(fields).every((f) => f.obscureText),
        isTrue,
      );
    }
  });

  testWidgets('cancel after password entry and reopen without errors', (
    tester,
  ) async {
    await openDialog(tester);
    await tester.enterText(find.byType(TextField).first, 'example-password');
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(ChangePasswordSheet), findsNothing);
    await tester.tap(find.text('パスワードを変更'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<TextField>(find.byType(TextField))
          .every((f) => f.controller!.text.isEmpty && f.obscureText),
      isTrue,
    );
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.byType(ChangePasswordSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('change button is enabled only when all rules are met', (
    tester,
  ) async {
    await openDialog(tester);
    FilledButton button() =>
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, '変更する'));
    final fields = find.byType(TextField);

    expect(button().onPressed, isNull);
    await tester.enterText(fields.at(0), 'old-pass');
    await tester.enterText(fields.at(1), 'abc');
    await tester.enterText(fields.at(2), 'abc');
    await tester.pump();
    expect(button().onPressed, isNull); // 6 文字未満

    await tester.enterText(fields.at(1), 'old-pass');
    await tester.enterText(fields.at(2), 'old-pass');
    await tester.pump();
    expect(button().onPressed, isNull); // いまと同じ

    await tester.enterText(fields.at(1), 'new-pass');
    await tester.enterText(fields.at(2), 'new-pas');
    await tester.pump();
    expect(button().onPressed, isNull); // 2 つがちがう

    await tester.enterText(fields.at(2), 'new-pass');
    await tester.pump();
    expect(button().onPressed, isNotNull);
  });
}
