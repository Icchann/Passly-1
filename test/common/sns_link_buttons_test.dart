import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passly/common/widgets/sns_link_buttons.dart';
import 'package:passly/features/user/domain/user_model.dart';

UserModel _user({
  String x = '',
  String gh = '',
  String cp = '',
  String pf = '',
}) => UserModel(
  id: 'u',
  name: 'テスト',
  twitterUrl: x,
  githubUrl: gh,
  connpassUrl: cp,
  portfolioUrl: pf,
);

Future<void> _pump(WidgetTester tester, UserModel u, {double scale = 1}) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(360, 640),
          textScaler: TextScaler.linear(scale),
        ),
        child: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 21),
            child: SnsLinkButtons(profile: u),
          ),
        ),
      ),
    ),
  );
}

void main() {
  test('ボタンに出す順は X → GitHub → connpass → ポートフォリオ', () {
    final kinds = snsLinksOf(
      _user(x: 'a', gh: 'b', cp: 'c', pf: 'd.dev'),
    ).map((l) => l.kind);
    expect(kinds, [
      SnsKind.x,
      SnsKind.github,
      SnsKind.connpass,
      SnsKind.portfolio,
    ]);
  });

  test('ポートフォリオのドメイン表示', () {
    expect(
      portfolioDomainOf('https://www.example.com/works/'),
      'example.com/works',
    );
    expect(normalizePortfolioUrl('example.com'), 'https://example.com');
    expect(normalizePortfolioUrl('http://a.dev'), 'http://a.dev');
  });

  testWidgets('X だけなら全幅の「でフォロー」1 つ', (tester) async {
    await _pump(tester, _user(x: 'a'));
    expect(find.text('でフォロー'), findsOneWidget);
    expect(tester.getSize(find.bySemanticsLabel('Xでフォロー')).width, 318);
  });

  testWidgets('X がなければ GitHub が大きい「を見る」', (tester) async {
    await _pump(tester, _user(gh: 'b', cp: 'c'));
    expect(find.text('を見る'), findsOneWidget);
    expect(find.text('でフォロー'), findsNothing);
    expect(find.bySemanticsLabel('connpassを見る'), findsOneWidget);
  });

  testWidgets('ポートフォリオだけでも出す', (tester) async {
    await _pump(tester, _user(pf: 'example.com'));
    expect(find.text('ポートフォリオ'), findsOneWidget);
    expect(find.text('example.com'), findsOneWidget);
  });

  testWidgets('4 つあっても小さい画面・大きい文字ではみ出さない', (tester) async {
    await _pump(
      tester,
      _user(
        x: 'a',
        gh: 'b',
        cp: 'c',
        pf: 'https://very-long-portfolio-domain.example.com/works',
      ),
      scale: 1.3,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('ポートフォリオ'), findsOneWidget);
  });

  testWidgets('何もなければ何も出さない', (tester) async {
    await _pump(tester, _user());
    expect(find.byType(InkWell), findsNothing);
  });
}
