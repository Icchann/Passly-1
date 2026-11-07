import 'package:dio/dio.dart';

import 'package:passly/core/utils/app_time.dart';
import 'package:passly/demo/demo_image_server.dart';
import 'package:passly/demo/demo_events.dart';
import 'package:passly/demo/demo_people.dart';

/// デモモードで本番 API の代わりに応答する Dio インターセプター。
///
/// サーバーには一切通信せず、[DemoApi] が持つダミーデータを返す。
/// 対応していないパスは 404 にする。
class DemoApiInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final data = DemoApi.instance.handle(options);
    if (data == null) {
      handler.reject(
        DioException(
          requestOptions: options,
          response: Response(requestOptions: options, statusCode: 404),
          type: DioExceptionType.badResponse,
        ),
      );
      return;
    }
    handler.resolve(
      Response(requestOptions: options, statusCode: 200, data: data),
    );
  }
}

/// デモ用のダミーデータと、アプリ起動中だけ保つ状態（お気に入り・未確認のすれ違いなど）。
class DemoApi {
  /// アプリを開くたびに、まずすれ違い画面から始まるようにしておく。
  DemoApi._() {
    startEncounter();
  }

  static final DemoApi instance = DemoApi._();

  final Set<String> _favoriteIds = {...demoInitialFavoriteIds};
  final DemoEvent _todayEvent = demoTodayEvent(AppTime.nowLocal());
  late final List<DemoEvent> _events = [...demoEvents, _todayEvent];
  final Map<String, dynamic> _meOverrides = {};

  /// すれ違い画面に出す相手（未確認）。起動時と [startEncounter] で入る。
  List<String> _pendingIds = const [];

  /// まだ確認していないすれ違いがあるか。
  bool get hasPendingEncounter => _pendingIds.isNotEmpty;

  /// すれ違い画面に出す相手を用意する。共通タグが多い人から並べる。
  void startEncounter() {
    final ids = [...demoTodayPeople]
      ..sort((a, b) => _commonCount(b).compareTo(_commonCount(a)));
    _pendingIds = ids.where((id) => _commonCount(id) > 0).toList();
  }

  int _commonCount(String id) =>
      _person(id)!.tags.where(demoMe.tags.contains).length;

  /// [options] への応答を返す。対応していなければ null。
  Object? handle(RequestOptions options) {
    final method = options.method.toUpperCase();
    final segments = Uri.parse(
      options.path,
    ).pathSegments.where((s) => s.isNotEmpty).toList();

    switch (segments) {
      case ['login'] when method == 'POST':
        return {'user_id': demoMeId, 'token': 'demo'};
      case ['signup']:
        return <String, dynamic>{};
      case ['events'] when method == 'GET':
        return [for (final e in _events) _eventJson(e)];
      case ['users', _, 'connpass-events'] when method == 'GET':
        return [for (final e in _events) _eventJson(e)];
      case ['events', final id] when method == 'GET':
        final event = _event(int.tryParse(id));
        return event == null ? null : _eventDetailJson(event);
      case ['encounters'] || ['encounters', 'batch']:
        return <String, dynamic>{};
      case ['users', _, 'home'] when method == 'GET':
        return _homeJson();
      case ['users', _, 'calendar', 'daily'] when method == 'GET':
        return _dailyJson(options.queryParameters['date']?.toString() ?? '');
      case ['users', _, 'encounters'] when method == 'GET':
        final ids = _records.map((r) => r.personId).toSet();
        return [for (final id in ids) _userJson(_person(id)!)];
      case ['users', _, 'encounters', 'confirm']:
        _pendingIds = const [];
        return <String, dynamic>{};
      case ['users', _, 'close-friends'] when method == 'GET':
        return [
          for (final id in _favoriteIds)
            if (_person(id) case final p?) _userJson(p),
        ];
      case ['users', _, 'close-friends'] when method == 'POST':
        final body = options.data;
        if (body is Map && body['target_id'] != null) {
          _favoriteIds.add(body['target_id'].toString());
        }
        return <String, dynamic>{};
      case ['users', _, 'close-friends', final targetId]
          when method == 'DELETE':
        _favoriteIds.remove(targetId);
        return <String, dynamic>{};
      case ['users', _, 'ephemeral-tokens']:
        return <dynamic>[];
      case ['users', _, 'achievements']:
        return _achievementsJson();
      case ['users', _, 'password']:
        return <String, dynamic>{};
      case ['users', _, 'avatar' || 'cover']:
        return _meJson();
      case ['users', final id] when method == 'PATCH':
        final body = options.data;
        if (id == demoMeId && body is Map) {
          _meOverrides.addAll(Map<String, dynamic>.from(body));
        }
        return _meJson();
      case ['users', _] when method == 'DELETE':
        return <String, dynamic>{};
      case ['users', final id] when method == 'GET':
        if (id == demoMeId) return _meJson();
        final person = _person(id);
        return person == null ? null : _userJson(person);
    }
    return null;
  }

  // ---- すれ違いの履歴 ----

  late final List<_Record> _records = _buildRecords();

  List<_Record> _buildRecords() {
    final records = <_Record>[];
    for (final MapEntry(key: eventId, value: ids)
        in demoEncountersByEvent.entries) {
      final event = _event(eventId)!;
      for (var i = 0; i < ids.length; i++) {
        records.add(
          _Record(
            personId: ids[i],
            event: event,
            metAt: event.startAt.add(Duration(minutes: 20 + i * 13)),
          ),
        );
      }
    }

    // 今日のすれ違いは、今から 15 分ずつさかのぼった時刻にする（日付はまたがない）。
    final now = AppTime.nowUtc();
    final local = AppTime.toAppLocal(now);
    final startOfToday = DateTime.utc(
      local.year,
      local.month,
      local.day,
    ).subtract(AppTime.timeZoneOffset);
    for (var i = 0; i < demoTodayPeople.length; i++) {
      var metAt = now.subtract(Duration(minutes: 5 + i * 15));
      if (metAt.isBefore(startOfToday)) metAt = startOfToday;
      records.add(
        _Record(personId: demoTodayPeople[i], event: _todayEvent, metAt: metAt),
      );
    }

    records.sort((a, b) => b.metAt.compareTo(a.metAt));
    return records;
  }

  static String _dateKey(DateTime utc) {
    final local = AppTime.toAppLocal(utc);
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  // ---- JSON ----

  Map<String, dynamic> _homeJson() {
    final todayKey = _dateKey(AppTime.nowUtc());
    final today = _records.where((r) => _dateKey(r.metAt) == todayKey);
    return {
      'total_encounters': _records.length,
      'today_encounters': today.length,
      'unconfirmed': [
        for (final id in _pendingIds)
          {
            ..._shortUserJson(_person(id)!),
            'event_name': _todayEvent.name,
            'created_at': AppTime.nowUtc().toIso8601String(),
          },
      ],
      'random_three': <dynamic>[],
      'recent_encounters': [
        for (final r in _records)
          {
            'user_id': r.personId,
            'name': _person(r.personId)!.name,
            'icon_url': _icon(r.personId),
            'met_at': r.metAt.toIso8601String(),
            'event_name': r.event.name,
            'tech_stack': _person(r.personId)!.techStack,
          },
      ],
    };
  }

  Map<String, dynamic> _dailyJson(String date) {
    final records = _records.where((r) => _dateKey(r.metAt) == date).toList();
    final event = records.isNotEmpty
        ? records.first.event
        : _events.where((e) => _dateKey(e.startAt) == date).firstOrNull;
    return {
      'encounter_count': records.length,
      'event': event?.name,
      'event_location': event?.location ?? '',
      'event_url': event?.url ?? '',
      'event_id': event?.id,
      'participant_count': event?.accepted,
      'event_image_url': event == null
          ? ''
          : DemoImageServer.eventImageUrlFor(event.id),
      'users': [for (final r in records) _shortUserJson(_person(r.personId)!)],
    };
  }

  Map<String, dynamic> _eventJson(DemoEvent e) => {
    'id': e.id,
    'name': e.name,
    'start_at': e.startAt.toIso8601String(),
    'end_at': e.endAt.toIso8601String(),
    'location': e.location,
    'event_url': e.url,
    'image_url': DemoImageServer.eventImageUrlFor(e.id),
    'description': e.description,
    'accepted': e.accepted,
    'waiting': 0,
    'limit': e.limit,
  };

  Map<String, dynamic> _eventDetailJson(DemoEvent e) => {
    ..._eventJson(e),
    'participants': [
      for (final r in _records.where((r) => r.event.id == e.id))
        {
          'user_id': r.personId,
          'name': _person(r.personId)!.name,
          'icon_url': _icon(r.personId),
          'one_word': _person(r.personId)!.oneWord,
          'registered_at': e.startAt
              .subtract(const Duration(days: 7))
              .toIso8601String(),
        },
    ],
  };

  Map<String, dynamic> _shortUserJson(DemoPerson p) => {
    'id': p.id,
    'name': p.name,
    'icon_url': _icon(p.id),
    'one_word': p.oneWord,
    'tech_stack': p.techStack,
  };

  Map<String, dynamic> _userJson(DemoPerson p) {
    final last = _records.where((r) => r.personId == p.id).firstOrNull;
    return {
      'id': p.id,
      'name': p.name,
      'icon_url': _icon(p.id),
      'one_word': p.oneWord,
      'role': p.role,
      'tech_stack': p.techStack,
      'twitter_url': p.twitterUrl,
      'github_url': p.githubUrl,
      'affiliation': p.affiliation,
      'about': p.about,
      'is_close_friend': _favoriteIds.contains(p.id),
      if (last != null)
        'last_encounter': {
          'met_at': last.metAt.toIso8601String(),
          'event_name': last.event.name,
        },
      if (demoNextEvents[p.id] case final next?)
        'next_event': {
          'title': next.title,
          'started_at': next.startedAt.toIso8601String(),
          'place': next.place,
          'url': next.url,
        },
    };
  }

  Map<String, dynamic> _meJson() => {
    ..._userJson(demoMe),
    'email': 'demo@example.com',
    'twitter_url': 'https://x.com/example_eiden',
    'github_url': 'https://github.com/example-eiden',
    'connpass_url': 'https://connpass.com/user/akitsugu/',
    ..._meOverrides,
  };

  Map<String, dynamic> _achievementsJson() {
    final count = _records.length;
    final achievements = [
      _achievement('first', '🤝', 'はじめてのすれ違い', '1 人とすれ違う', count >= 1),
      _achievement('ten', '🔟', 'すれ違い 10 人', '10 人とすれ違う', count >= 10),
      _achievement('fifty', '🏅', 'すれ違い 50 人', '50 人とすれ違う', count >= 50),
      _achievement(
        'events',
        '🎪',
        'イベントの常連',
        '5 つのイベントですれ違う',
        demoEncountersByEvent.length >= 5,
      ),
      _achievement('hundred', '🏆', 'すれ違い 100 人', '100 人とすれ違う', count >= 100),
    ];
    return {
      'unlocked_count': achievements
          .where((a) => a['is_unlocked'] == true)
          .length,
      'total_count': achievements.length,
      'achievements': achievements,
    };
  }

  Map<String, dynamic> _achievement(
    String id,
    String emoji,
    String title,
    String description,
    bool unlocked,
  ) => {
    'id': id,
    'emoji': emoji,
    'title': title,
    'description': description,
    'is_unlocked': unlocked,
    if (unlocked) 'unlocked_at': demoEvents.first.startAt.toIso8601String(),
  };

  // ---- 検索 ----

  static DemoPerson? _person(String id) =>
      demoPeople.where((p) => p.id == id).firstOrNull;

  DemoEvent? _event(int? id) => _events.where((e) => e.id == id).firstOrNull;

  /// イラストのアイコン（なければ頭文字）。色は人ごとに変える（自分は 0 番）。
  static String _icon(String id) {
    if (id == demoMeId) return DemoImageServer.urlFor(id, demoMe.name, 0);
    final index = demoPeople.indexWhere((p) => p.id == id);
    if (index < 0) return '';
    return DemoImageServer.urlFor(id, demoPeople[index].name, index + 1);
  }
}

class _Record {
  final String personId;
  final DemoEvent event;
  final DateTime metAt;

  const _Record({
    required this.personId,
    required this.event,
    required this.metAt,
  });
}
