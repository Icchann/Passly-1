import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passly/features/auth/domain/auth_notifier.dart';
import 'package:passly/features/auth/presentation/login_screen.dart';
import 'package:passly/features/auth/presentation/sign_up_screen.dart';
import 'package:passly/features/user/domain/user_model.dart';

class _LoggedOut extends AuthNotifier {
  @override
  FutureOr<UserModel?> build() => null;
}

const _screens = {
  'Android 小さめ': Size(360, 640),
  'Android 標準': Size(412, 915),
  'iPhone SE': Size(375, 667),
  'iPhone 標準': Size(393, 852),
  'iPhone 大きめ': Size(440, 956),
};

Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  required Size size,
  required double textScale,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authNotifierProvider.overrideWith(_LoggedOut.new)],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: screen,
      ),
    ),
  );
  await tester.pump();
}

void main() {
  for (final entry in _screens.entries) {
    for (final textScale in [1.0, 1.3]) {
      testWidgets('login fits on ${entry.key} (text x$textScale)', (
        tester,
      ) async {
        await _pump(
          tester,
          const LoginScreen(),
          size: entry.value,
          textScale: textScale,
        );
        expect(tester.takeException(), isNull);
        expect(find.text('おかえりなさい'), findsOneWidget);
        expect(find.text('ログイン'), findsOneWidget);
      });

      testWidgets('sign up steps fit on ${entry.key} (text x$textScale)', (
        tester,
      ) async {
        await _pump(
          tester,
          const SignUpScreen(),
          size: entry.value,
          textScale: textScale,
        );
        expect(tester.takeException(), isNull);
        expect(find.text('メールとパスワード'), findsOneWidget);

        // 入力しないと次へ進めない
        await tester.tap(find.text('つぎへ'));
        await tester.pump();
        expect(find.text('メールとパスワード'), findsOneWidget);
        expect(find.text('メールアドレスを入力してください'), findsOneWidget);

        final fields = find.byType(TextFormField);
        await tester.enterText(fields.at(0), 'taro@example.com');
        await tester.enterText(fields.at(1), 'secret1');
        await tester.enterText(fields.at(2), 'secret1');
        await tester.tap(find.text('つぎへ'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('すれ違った人に見せる名前'), findsOneWidget);

        await tester.enterText(find.byType(TextFormField).at(0), 'パスリー たろう');
        await tester.enterText(find.byType(TextFormField).at(1), 'passly_taro');
        await tester.pump();
        expect(find.text('すれ違った人にはこう見えます'), findsNothing);
        await tester.tap(find.text('つぎへ'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('connpassとつなぐ'), findsOneWidget);
        expect(find.text('ユーザー名はどこにある？'), findsOneWidget);
        expect(find.text('あとで設定する'), findsOneWidget);

        // 戻ると前のステップの入力が残っている
        await tester.tap(find.byTooltip('戻る'));
        await tester.pumpAndSettle();
        expect(find.text('すれ違った人に見せる名前'), findsOneWidget);
        expect(
          tester
              .widget<EditableText>(find.byType(EditableText).at(1))
              .controller
              .text,
          'passly_taro',
        );
      });
    }
  }
}
