import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passly/features/event/domain/event_album_notifier.dart';
import 'package:passly/features/event/domain/favorite_next_events.dart';
import 'package:passly/features/event/presentation/event_album_screen.dart';
import 'package:passly/features/user/domain/next_event.dart';
import 'package:passly/features/user/domain/user_model.dart';

EventSummary _event(String name, DateTime day, {int met = 3}) => EventSummary(
  id: null,
  name: name,
  startAt: day,
  location: '',
  imageUrl: '',
  metUsers: [for (var i = 0; i < met; i++) EventMetUser(id: '$i', iconUrl: '')],
  sameTagCount: met ~/ 2,
);

final _album = EventAlbum(
  today: _event('MEET STAGE とても長いイベントの名前が入ります', DateTime(2026, 11, 8), met: 5),
  upcoming: [_event('技育展2026 本選', DateTime(2026, 11, 28))],
  past: [
    _event('Passly 体験会', DateTime(2026, 10, 30), met: 12),
    _event('Matsuriba 夏祭り とても長い名前の夏祭り', DateTime(2026, 10, 18)),
    _event('技育CAMP ハッカソン', DateTime(2026, 9, 27), met: 0),
  ],
);

final _tech = NextEvent(
  title: '技育展2026 本選',
  startedAt: DateTime.utc(2026, 11, 28, 3),
  url: 'https://example.com/a',
);

final _favorites = [
  FavoriteNextEvent(
    event: NextEvent(
      title: 'Flutter 勉強会 名古屋',
      startedAt: DateTime.utc(2026, 11, 15, 3),
      url: 'https://example.com/b',
    ),
    users: const [UserModel(id: 'm', name: 'みなと')],
  ),
  FavoriteNextEvent(
    event: _tech,
    users: const [
      UserModel(id: 'a', name: 'シスにゃん'),
      UserModel(id: 'b', name: 'るい'),
      UserModel(id: 'c', name: 'とても長い名前のたろう'),
      UserModel(id: 'd', name: 'はなこ'),
    ],
  ),
];

const _screens = {
  'Android 小さめ': Size(360, 640),
  'Android 標準': Size(412, 915),
  'iPhone SE': Size(375, 667),
  'iPhone 標準': Size(393, 852),
  'iPhone 大きめ': Size(440, 956),
};

void main() {
  for (final entry in _screens.entries) {
    for (final textScale in [1.0, 1.3]) {
      testWidgets('event screen fits on ${entry.key} (text x$textScale)', (
        tester,
      ) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              eventAlbumProvider.overrideWith((ref) async => _album),
              favoriteNextEventsProvider.overrideWith(
                (ref) async => _favorites,
              ),
            ],
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!,
              ),
              home: const EventAlbumScreen(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(tester.takeException(), isNull);
        // 参加中・自分の予定・お気に入りの人の予定がそれぞれのラベルで出る
        expect(find.text('これから'), findsOneWidget);
        expect(find.text('参加中'), findsOneWidget);
        expect(find.text('5人と出会った'), findsOneWidget);
        expect(find.text('参加予定'), findsOneWidget);
        expect(find.text('参加してみる'), findsOneWidget);
        expect(find.text('★ お気に入り'), findsOneWidget);
        // 自分の予定と同じイベントに行くお気に入りの人は，自分の予定のカードにまとめる
        expect(
          find.text('シスにゃんさん，るいさん，とても長い名前のたろうさん，はなこさんが参加予定'),
          findsOneWidget,
        );
        expect(find.text('みなとさんが参加予定'), findsOneWidget);
        // 1 列 / 2 列の切り替えはもうない
        expect(find.text('Passly 体験会'), findsOneWidget);

        await tester.drag(find.byType(ListView), const Offset(0, -2000));
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  }

  test('favorites going to the same event are grouped by date order', () {
    final later = NextEvent(
      title: 'もくもく会',
      startedAt: DateTime.utc(2026, 12, 6, 3),
    );
    final past = NextEvent(
      title: '前のイベント',
      startedAt: DateTime.utc(2026, 1, 1),
    );
    final groups = groupFavoriteNextEvents([
      UserModel(id: 'a', name: 'A', nextEvent: later),
      UserModel(id: 'b', name: 'B', nextEvent: _tech),
      UserModel(id: 'c', name: 'C', nextEvent: _tech),
      UserModel(id: 'd', name: 'D', nextEvent: past),
      const UserModel(id: 'e', name: 'E'),
    ], today: DateTime(2026, 11, 7));
    expect(groups.map((g) => g.event.title), ['技育展2026 本選', 'もくもく会']);
    expect(groups.first.users.map((u) => u.name), ['B', 'C']);
  });
}
