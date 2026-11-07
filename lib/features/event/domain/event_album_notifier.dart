import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:passly/core/utils/app_time.dart';
import 'package:passly/features/auth/domain/auth_notifier.dart';
import 'package:passly/features/calendar/data/calendar_repository.dart';
import 'package:passly/features/user/domain/common_tags.dart';

/// イベント画面のカード 1 枚分。
class EventSummary {
  final int? id;
  final String name;

  /// 開始日時（日本時間）。
  final DateTime startAt;
  final String location;
  final String imageUrl;

  /// イベントのページ（connpass など）。なければ空文字。
  final String url;

  /// そのイベントの日に出会った人（アイコン用）。
  final List<EventMetUser> metUsers;

  /// 出会った人のうち、自分と同じタグがある人の数。
  final int sameTagCount;

  const EventSummary({
    required this.id,
    required this.name,
    required this.startAt,
    required this.location,
    required this.imageUrl,
    this.url = '',
    this.metUsers = const [],
    this.sameTagCount = 0,
  });

  DateTime get day => DateTime(startAt.year, startAt.month, startAt.day);
}

class EventMetUser {
  final String id;
  final String iconUrl;

  const EventMetUser({required this.id, required this.iconUrl});
}

/// イベント画面のデータ。
class EventAlbum {
  /// 今日のイベント（出会った人の数つき）。なければ null。
  final EventSummary? today;

  /// これから参加するイベント（明日から）。日付の早い順。
  final List<EventSummary> upcoming;

  /// 参加したイベント（昨日まで）。新しい順。
  final List<EventSummary> past;

  const EventAlbum({this.today, this.upcoming = const [], required this.past});
}

/// イベント画面（旧カレンダー）のデータ。
///
/// プロフィールの connpass ユーザー名で参加イベント（GET /users/:id/connpass-events）
/// を取り、今日までのものは GET /users/:id/calendar/daily でその日に出会った人を
/// 取って、人数と同じタグの人数を出す。
///
/// アカウントを作る前のイベントでは誰ともすれ違っていないので，日別 API は
/// 呼ばない（connpass の参加履歴が多い人でも通信が増えないように）。
/// 自分の情報はイベント一覧に使う id・タグ・登録日だけを見て，
/// アイコンや自己紹介を変えただけでは取り直さない。
final eventAlbumProvider = FutureProvider<EventAlbum>((ref) async {
  final me = ref.watch(
    authNotifierProvider.select((s) {
      final u = s.value;
      return u == null
          ? null
          : (id: u.id, techStack: u.techStack, createdAt: u.createdAt);
    }),
  );
  if (me == null) return const EventAlbum(past: []);

  final repo = ref.read(calendarRepositoryProvider);
  final now = AppTime.nowLocal();
  final today = DateTime(now.year, now.month, now.day);

  final events = <EventSummary>[];
  for (final raw in await repo.fetchConnpassEvents(me.id)) {
    final startUtc = DateTime.tryParse(raw['start_at']?.toString() ?? '');
    if (startUtc == null) continue;
    events.add(
      EventSummary(
        id: raw['id'] is int ? raw['id'] as int : int.tryParse('${raw['id']}'),
        name: raw['name']?.toString() ?? '',
        startAt: AppTime.toAppLocal(startUtc),
        location: raw['location']?.toString() ?? '',
        imageUrl: raw['image_url']?.toString() ?? '',
        url: (raw['event_url'] ?? raw['url'])?.toString() ?? '',
      ),
    );
  }

  final upcoming = events.where((e) => e.day.isAfter(today)).toList()
    ..sort((a, b) => a.startAt.compareTo(b.startAt));
  final past = events.where((e) => !e.day.isAfter(today)).toList()
    ..sort((a, b) => b.startAt.compareTo(a.startAt));

  final joined = me.createdAt == null
      ? null
      : () {
          final local = AppTime.toAppLocal(me.createdAt!);
          return DateTime(local.year, local.month, local.day);
        }();

  final withPeople = await Future.wait(
    past.map((e) async {
      if (!mayHaveEncounters(e.day, joined)) return e;
      try {
        final data = await repo.fetchDailyEncounters(
          userId: me.id,
          dateString: eventDateParam(e.day),
        );
        // 実バックエンドは encounter_users、デモは users で返す。
        final users =
            (data['users'] as List? ??
                    data['encounter_users'] as List? ??
                    const [])
                .whereType<Map>()
                .toList();
        return EventSummary(
          id: e.id,
          name: e.name,
          startAt: e.startAt,
          location: e.location,
          imageUrl: e.imageUrl,
          url: e.url,
          metUsers: [
            for (final u in users)
              EventMetUser(
                id: u['id']?.toString() ?? '',
                iconUrl: (u['icon_url'] ?? u['iconUrl'])?.toString() ?? '',
              ),
          ],
          sameTagCount: users
              .where(
                (u) => commonTechTags(
                  me.techStack,
                  (u['tech_stack'] ?? u['techStack'])?.toString() ?? '',
                ).isNotEmpty,
              )
              .length,
        );
      } catch (_) {
        return e;
      }
    }),
  );

  // 今日のイベントは一覧ではなく上の「今日・すれ違い中」カードに出す
  final todays = withPeople.where((e) => e.day == today).toList();
  return EventAlbum(
    today: todays.isEmpty ? null : todays.first,
    upcoming: upcoming,
    past: withPeople.where((e) => e.day != today).toList(),
  );
});

/// [day] のイベントで誰かとすれ違っている可能性があるか。
/// アカウントを作った日 [joined] より前なら無い。[joined] が分からなければある扱い。
bool mayHaveEncounters(DateTime day, DateTime? joined) =>
    joined == null || !day.isBefore(joined);

/// 日別 API や /encounters/day/:date に渡す YYYY-MM-DD。
String eventDateParam(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
