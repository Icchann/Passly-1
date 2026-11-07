import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passly/common/widgets/text_field_context_menu.dart';
import 'package:passly/features/auth/domain/auth_notifier.dart';
import 'package:passly/features/mypage/presentation/profile_edit_screen.dart';
import 'package:passly/features/user/domain/user_model.dart';

class _FakeAuth extends AuthNotifier {
  @override
  FutureOr<UserModel?> build() => const UserModel(
    id: 'me',
    name: 'えいでん',
    twitterUrl: 'https://x.com/aiden?s=11',
    connpassUrl: 'aiden',
  );
}

void main() {
  // iOS 16 以降の純正メニューは，欄を切り替えると前のメニューが残ったまま
  // 次を出そうとして止まることがあるので，どの欄も Flutter のメニューを使う。
  testWidgets('every field on the edit screen uses the app context menu', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authNotifierProvider.overrideWith(_FakeAuth.new)],
        child: const MaterialApp(home: ProfileEditScreen()),
      ),
    );
    await tester.pump();

    final listView = find.byType(Scrollable).first;
    final seen = <TextEditingController?>{};
    for (var i = 0; i < 20; i++) {
      for (final field in tester.widgetList<TextField>(
        find.byType(TextField),
      )) {
        seen.add(field.controller);
        expect(field.contextMenuBuilder, same(passlyContextMenuBuilder));
      }
      await tester.drag(listView, const Offset(0, -300));
      await tester.pump();
    }
    // 名前・所属・自己紹介文・タグ検索・X・GitHub・ポートフォリオ・connpass
    expect(seen.length, greaterThanOrEqualTo(8));
    debugDefaultTargetPlatformOverride = null;
  });
}
