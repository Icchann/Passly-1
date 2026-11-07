import 'package:flutter_test/flutter_test.dart';
import 'package:passly/features/user/domain/next_event.dart';

void main() {
  test('reads started_at and url', () {
    final e = NextEvent.tryParse({
      'title': 'Flutter Meetup',
      'started_at': '2026-11-20T10:00:00Z',
      'url': 'https://example.connpass.com/event/1/',
    });
    expect(e?.title, 'Flutter Meetup');
    expect(e?.startedAt, DateTime.utc(2026, 11, 20, 10));
    expect(e?.url, 'https://example.connpass.com/event/1/');
  });

  test('also reads start_at and event_url like GET /events', () {
    final e = NextEvent.tryParse({
      'title': 'Flutter Meetup',
      'start_at': '2026-11-20T10:00:00Z',
      'event_url': 'https://example.connpass.com/event/1/',
    });
    expect(e?.startedAt, DateTime.utc(2026, 11, 20, 10));
    expect(e?.url, 'https://example.connpass.com/event/1/');
  });

  test('null when title or date is missing', () {
    expect(NextEvent.tryParse(null), isNull);
    expect(NextEvent.tryParse({'title': 'x'}), isNull);
    expect(NextEvent.tryParse({'start_at': '2026-11-20T10:00:00Z'}), isNull);
  });
}
