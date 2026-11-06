import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passly/common/widgets/tag_sticker.dart';
import 'package:passly/features/auth/domain/auth_notifier.dart';
import 'package:passly/features/encounter/domain/encounter_model.dart';
import 'package:passly/features/encounter/domain/encounter_notifier.dart';
import 'package:passly/features/encounter/presentation/encounter_result_screen.dart';
import 'package:passly/features/user/domain/user_model.dart';

class _FakeAuth extends AuthNotifier {
  @override
  FutureOr<UserModel?> build() => const UserModel(
    id: 'me',
    name: 'えいでん',
    techStack: 'Figma,Flutter,Go,React,Docker,Swift',
  );
}

class _FakeEncounters extends EncounterNotifier {
  final String techStack;

  _FakeEncounters(this.techStack);

  @override
  FutureOr<List<EncounterModel>> build() => [
    EncounterModel(
      id: 'e1',
      encounteredUser: EncounteredUserInfo(
        id: 'u1',
        name: 'シスにゃん',
        techStack: techStack,
      ),
      eventName: 'SysHack2026',
      encounteredAt: DateTime(2026, 11, 8, 14),
    ),
  ];
}

/// Android と iPhone でよく使われる画面サイズ（論理ピクセル）
const _screens = {
  'Android 小さめ': Size(360, 640),
  'Android 標準': Size(412, 915),
  'iPhone SE': Size(375, 667),
  'iPhone 標準': Size(393, 852),
  'iPhone 大きめ': Size(440, 956),
};

Future<void> _pumpScreen(
  WidgetTester tester, {
  required Size size,
  required String techStack,
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authNotifierProvider.overrideWith(_FakeAuth.new),
        encounterNotifierProvider.overrideWith(
          () => _FakeEncounters(techStack),
        ),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const EncounterResultScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  for (final entry in _screens.entries) {
    for (final textScale in [1.0, 1.3]) {
      testWidgets(
        'common tag stickers fit on ${entry.key} (text x$textScale)',
        (tester) async {
          await _pumpScreen(
            tester,
            size: entry.value,
            techStack: 'Figma,Flutter,Go,React,Docker',
            textScale: textScale,
          );
          expect(tester.takeException(), isNull);
          // たたんだ状態は「+N すべて見る」まで含めて 1 行に収まる
          // （幅の広い画面では 5 つ全部が 1 行に入るので「+N」は出ない）
          final shown = find.byType(LabeledTagSticker);
          final count = tester.widgetList(shown).length;
          expect(count, inInclusiveRange(1, 5));
          final rowTop = tester.getTopLeft(shown.first).dy;
          for (final e in shown.evaluate()) {
            expect(tester.getTopLeft(find.byWidget(e.widget)).dy, rowTop);
          }
          final more = find.text('すべて見る');
          if (count == 5) {
            expect(more, findsNothing);
            return;
          }
          expect(find.text('+${5 - count}'), findsOneWidget);
          expect(tester.getBottomLeft(more).dy, lessThan(rowTop + 80));

          await tester.ensureVisible(more);
          await tester.tap(more);
          await tester.pump();
          expect(tester.takeException(), isNull);
          expect(find.byType(LabeledTagSticker), findsNWidgets(5));
          expect(find.text('すべて見る'), findsNothing);
        },
      );
    }
  }

  testWidgets('three common tags show without the more button', (tester) async {
    await _pumpScreen(
      tester,
      size: _screens['Android 小さめ']!,
      techStack: 'Figma,Flutter,Go',
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(LabeledTagSticker), findsNWidgets(3));
    expect(find.text('すべて見る'), findsNothing);
  });
}
