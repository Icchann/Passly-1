import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:passly/core/network/dio_client.dart';
import 'package:passly/core/utils/app_time.dart';

final calendarRepositoryProvider = Provider<CalendarRepository>((ref) {
  return CalendarRepository(
    ref.read(dioProvider),
    ref.read(secureStorageProvider),
  );
});

/// カレンダー画面のデータを取得するリポジトリ
class CalendarRepository {
  final Dio _dio;
  final FlutterSecureStorage _storage;

  CalendarRepository(this._dio, this._storage);

  /// 特定の日付のすれ違い数とイベント名を取得する（GET /users/:id/calendar/daily?date=YYYY-MM-DD）
  Future<Map<String, dynamic>> fetchDailyEncounters({
    required String userId,
    required String dateString, // YYYY-MM-DD
  }) async {
    final cacheKey = 'cached_calendar_${userId}_$dateString';
    try {
      final response = await _dio.get(
        '/users/$userId/calendar/daily',
        queryParameters: {'date': dateString},
      );
      final data = response.data as Map<String, dynamic>;
      await _storage.write(key: cacheKey, value: jsonEncode(data));
      return data;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.unknown) {
        final cachedStr = await _storage.read(key: cacheKey);
        if (cachedStr != null) {
          try {
            return jsonDecode(cachedStr) as Map<String, dynamic>;
          } catch (_) {}
        }
      }
      rethrow;
    }
  }

  /// 月内のイベント一覧を取得する（GET /events）
  Future<List<Map<String, dynamic>>> fetchMonthEvents(DateTime month) async {
    final cacheKey = 'cached_events_${month.year}_${month.month}';
    List<dynamic>? data;

    try {
      final response = await _dio.get('/events');
      data = response.data as List?;
      if (data != null) {
        await _storage.write(key: cacheKey, value: jsonEncode(data));
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.unknown) {
        final cachedStr = await _storage.read(key: cacheKey);
        if (cachedStr != null) {
          try {
            data = jsonDecode(cachedStr) as List?;
          } catch (_) {}
        }
      }
      if (data == null) rethrow;
    }

    if (data == null) return const [];

    return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).where(
      (event) {
        final startAtUtc = DateTime.tryParse(
          event['start_at']?.toString() ?? '',
        );
        if (startAtUtc == null) return false;
        final startAt = AppTime.toAppLocal(startAtUtc);
        return startAt.year == month.year && startAt.month == month.month;
      },
    ).toList();
  }

  /// イベント一覧をそのまま返す（GET /events）。月で絞らない。
  Future<List<Map<String, dynamic>>> fetchAllEvents() async {
    final response = await _dio.get('/events');
    final data = response.data;
    if (data is! List) return const [];
    return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// プロフィールの connpass ユーザー名で、参加した・参加予定のイベントを返す
  /// （GET /users/:id/connpass-events）。ユーザー名が未設定なら空。
  Future<List<Map<String, dynamic>>> fetchConnpassEvents(String userId) async {
    final response = await _dio.get('/users/$userId/connpass-events');
    final data = response.data;
    if (data is! List) return const [];
    return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// イベントがある日付（日本時間の年月日）をすべて返す（GET /events）。
  /// 週表示の目印に使う。月をまたぐ週でも出せるよう、月で絞らない。
  Future<Set<DateTime>> fetchEventDates() async {
    final dates = <DateTime>{};
    for (final raw in await fetchAllEvents()) {
      final startAtUtc = DateTime.tryParse(raw['start_at']?.toString() ?? '');
      if (startAtUtc == null) continue;
      final local = AppTime.toAppLocal(startAtUtc);
      dates.add(DateTime(local.year, local.month, local.day));
    }
    return dates;
  }

  /// 指定月のすれ違い情報を「日付 → data」のマップで返す。
  ///
  /// 呼び出し側は日別 API のループを直接組む必要がなくなる。
  ///
  /// ## バックエンド切替ポイント
  /// サーバー側で GET /users/:id/calendar/monthly?month=YYYY-MM が実装されたら、
  /// 内部を [_fetchByMonthlyApi] に差し替える。それまでは日別 API を
  /// 内部でループする [_fetchByDailyLoop] を使う。
  Future<Map<DateTime, Map<String, dynamic>>> fetchMonthlyCalendar({
    required String userId,
    required DateTime month,
  }) {
    // TODO(passly): サーバー側 monthly API がデプロイされたら
    // _fetchByMonthlyApi に差し替える。
    return _fetchByDailyLoop(userId: userId, month: month);
  }

  /// 従来の日別 API を月内全日に対して並列で叩く実装。
  Future<Map<DateTime, Map<String, dynamic>>> _fetchByDailyLoop({
    required String userId,
    required DateTime month,
  }) async {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final futures = <Future<MapEntry<DateTime, Map<String, dynamic>>?>>[];

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(month.year, month.month, day);
      final dateString =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      futures.add(_fetchOneDay(userId, date, dateString));
    }

    final results = await Future.wait(futures);
    final map = <DateTime, Map<String, dynamic>>{};
    for (final entry in results) {
      if (entry != null) {
        map[entry.key] = entry.value;
      }
    }
    return map;
  }

  /// 将来の monthly API 実装用プレースホルダ。
  /// バックエンド側の実装完了後に有効化する。
  // ignore: unused_element
  Future<Map<DateTime, Map<String, dynamic>>> _fetchByMonthlyApi({
    required String userId,
    required DateTime month,
  }) async {
    final monthString =
        '${month.year}-${month.month.toString().padLeft(2, '0')}';
    final response = await _dio.get(
      '/users/$userId/calendar/monthly',
      queryParameters: {'month': monthString},
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) return const {};

    final rawDays = data['days'];
    if (rawDays is! List) return const {};

    final result = <DateTime, Map<String, dynamic>>{};
    for (final raw in rawDays) {
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);
      final dateUtc = DateTime.tryParse(map['date']?.toString() ?? '');
      if (dateUtc == null) continue;
      final date = AppTime.toAppLocal(dateUtc);
      result[DateTime(date.year, date.month, date.day)] = _normalizeDayData(
        map,
      );
    }
    return result;
  }

  Future<MapEntry<DateTime, Map<String, dynamic>>?> _fetchOneDay(
    String userId,
    DateTime date,
    String dateString,
  ) async {
    try {
      final data = await fetchDailyEncounters(
        userId: userId,
        dateString: dateString,
      );
      final normalized = _normalizeDayData(data);
      final count = normalized['count'] as int? ?? 0;
      if (count > 0) {
        return MapEntry(date, normalized);
      }
    } catch (_) {
      // 個別失敗は無視して他日のデータを返す
    }
    return null;
  }

  /// daily / monthly 双方のレスポンス差異を吸収して統一形式で返す。
  Map<String, dynamic> _normalizeDayData(Map<String, dynamic> data) {
    final count =
        (data['encounter_count'] as int?) ?? (data['count'] as int?) ?? 0;
    final event =
        data['event'] as String? ??
        ((data['event_names'] as List?)?.cast<String?>().firstWhere(
          (name) => name != null && name.isNotEmpty,
          orElse: () => null,
        ));
    final users = _parseEncounterUsers(data);
    return {
      'count': count,
      'event': event,
      'event_location': data['event_location']?.toString() ?? '',
      'event_url': data['event_url']?.toString() ?? '',
      'event_id': data['event_id'],
      'participant_count': data['participant_count'],
      'event_image_url': data['event_image_url']?.toString() ?? '',
      'users': users,
    };
  }

  List<Map<String, dynamic>> _parseEncounterUsers(Map<String, dynamic> data) {
    final candidates = [
      data['users'],
      data['encounter_users'],
      data['encounters'],
    ];
    for (final candidate in candidates) {
      if (candidate is List) {
        return candidate
            .whereType<Map>()
            .map(
              (raw) => {
                'id': raw['id']?.toString() ?? '',
                'name': raw['name']?.toString() ?? '',
                'iconUrl':
                    (raw['icon_url'] ?? raw['iconUrl'])?.toString() ?? '',
                'comment':
                    (raw['one_word'] ?? raw['comment'])?.toString() ?? '',
                'techStack':
                    (raw['tech_stack'] ?? raw['techStack'])?.toString() ?? '',
              },
            )
            .where((user) => user['id']!.isNotEmpty)
            .toList();
      }
    }
    return const [];
  }
}
