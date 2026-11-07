import 'package:flutter_test/flutter_test.dart';
import 'package:passly/features/event/domain/event_album_notifier.dart';

void main() {
  test('events before the account was made are skipped', () {
    final joined = DateTime(2026, 10, 24);
    expect(mayHaveEncounters(DateTime(2026, 10, 23), joined), isFalse);
    expect(mayHaveEncounters(DateTime(2026, 10, 24), joined), isTrue);
    expect(mayHaveEncounters(DateTime(2026, 11, 8), joined), isTrue);
  });

  test('unknown sign-up date keeps every event', () {
    expect(mayHaveEncounters(DateTime(2020, 1, 1), null), isTrue);
  });
}
