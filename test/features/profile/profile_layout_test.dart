import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passly/features/auth/domain/auth_notifier.dart';
import 'package:passly/features/close_friend/domain/close_friend_list_notifier.dart';
import 'package:passly/features/mypage/presentation/mypage_screen.dart';
import 'package:passly/features/plaza/presentation/profile_screen.dart';
import 'package:passly/features/user/data/user_repository.dart';
import 'package:passly/features/user/domain/last_encounter.dart';
import 'package:passly/features/user/domain/user_model.dart';

final _me = UserModel(
  id: 'me',
  name: 'えいでん',
  affiliation: '愛知工業大学',
  about: 'Figmaで画面を作るのが好きです．\nイベントで話しかけてもらえるとうれしいです．',
  techStack: 'Figma,Flutter,React,Git',
  twitterUrl: 'aiden',
  githubUrl: 'aiden',
  portfolioUrl: 'https://example.com',
  connpassUrl: 'aiden',
);

final _other = UserModel(
  id: 'u1',
  name: 'とても長い名前のシスにゃんさん',
  about: 'システムエンジニア\nバックエンドが好きです',
  techStack: 'Figma,Flutter,Go,React Native,PostgreSQL,AWS',
  twitterUrl: 'sysnyan',
  githubUrl: 'sysnyan',
  lastEncounter: LastEncounter(
    metAt: DateTime.utc(2026, 3, 11, 3),
    eventName: 'SysHack2026 とても長いイベントの名前',
  ),
);

class _FakeAuth extends AuthNotifier {
  @override
  FutureOr<UserModel?> build() => _me;
}

class _NoFavorites extends CloseFriendListNotifier {
  @override
  FutureOr<List<UserModel>> build() => const [];
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
      overrides: [
        authNotifierProvider.overrideWith(_FakeAuth.new),
        closeFriendListProvider.overrideWith(_NoFavorites.new),
        userByIdProvider('u1').overrideWith((ref) async => _other),
      ],
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
  await tester.pump();
}

void main() {
  testWidgets('my page: 「…」から QR 交換と設定を開ける', (tester) async {
    await _pump(
      tester,
      const MyPageScreen(),
      size: const Size(393, 852),
      textScale: 1,
    );
    expect(find.text('QRでプロフィール交換'), findsNothing);
    await tester.tap(find.byTooltip('その他'));
    await tester.pumpAndSettle();
    expect(find.text('QRでプロフィール交換'), findsOneWidget);
    expect(find.text('設定'), findsOneWidget);
  });

  for (final entry in _screens.entries) {
    for (final textScale in [1.0, 1.3]) {
      testWidgets('my page fits on ${entry.key} (text x$textScale)', (
        tester,
      ) async {
        await _pump(
          tester,
          const MyPageScreen(),
          size: entry.value,
          textScale: textScale,
        );
        expect(tester.takeException(), isNull);
        expect(find.text('自己紹介'), findsOneWidget);
        expect(find.text('タグ'), findsOneWidget);
        expect(find.text('でフォロー'), findsOneWidget);
        // GitHub・connpass は丸いロゴ，ポートフォリオは下に横長
        expect(find.bySemanticsLabel('GitHubを見る'), findsOneWidget);
        expect(find.bySemanticsLabel('connpassを見る'), findsOneWidget);
        expect(find.bySemanticsLabel('ポートフォリオを見る'), findsOneWidget);
        expect(find.bySemanticsLabel('プロフィールを編集'), findsOneWidget);
      });

      testWidgets('profile fits on ${entry.key} (text x$textScale)', (
        tester,
      ) async {
        await _pump(
          tester,
          const ProfileScreen(userId: 'u1'),
          size: entry.value,
          textScale: textScale,
        );
        expect(tester.takeException(), isNull);
        expect(
          find.text('3月11日 SysHack2026 とても長いイベントの名前 で出会いました'),
          findsOneWidget,
        );
        expect(find.text('あなたと同じタグが2つ'), findsOneWidget);
        expect(find.text('NEXT EVENT'), findsNothing);
      });
    }
  }
}
