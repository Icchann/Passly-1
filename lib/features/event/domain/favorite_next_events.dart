import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:passly/core/utils/app_time.dart';
import 'package:passly/features/close_friend/domain/close_friend_list_notifier.dart';
import 'package:passly/features/user/data/user_repository.dart';
import 'package:passly/features/user/domain/next_event.dart';
import 'package:passly/features/user/domain/user_model.dart';

/// お気に入りの人が次に参加するイベント 1 つ分と，参加する人。
class FavoriteNextEvent {
  final NextEvent event;
  final List<UserModel> users;

  const FavoriteNextEvent({required this.event, required this.users});
}

/// イベント画面の「お気に入りの人の次のイベント」。
///
/// お気に入り（close-friends）の人それぞれの next_event を集め，
/// 同じイベントはまとめて日付の早い順に並べる。今日より前のものは出さない。
/// 一覧に next_event が入っていない人は GET /users/:id で取りに行く。
final favoriteNextEventsProvider = FutureProvider<List<FavoriteNextEvent>>((
  ref,
) async {
  final favorites = await ref.watch(closeFriendListProvider.future);
  final now = AppTime.nowLocal();
  final today = DateTime(now.year, now.month, now.day);

  final withEvents = await Future.wait(
    favorites.map((u) async {
      if (u.nextEvent != null) return u;
      try {
        return await ref.watch(userByIdProvider(u.id).future);
      } catch (_) {
        return u;
      }
    }),
  );
  return groupFavoriteNextEvents(withEvents, today: today);
});

/// [users] の next_event を同じイベントごとにまとめ，日付順に並べる。
/// [today] より前のイベントは外す。
List<FavoriteNextEvent> groupFavoriteNextEvents(
  List<UserModel> users, {
  required DateTime today,
}) {
  final groups = <String, FavoriteNextEvent>{};
  for (final u in users) {
    final e = u.nextEvent;
    if (e == null) continue;
    final local = AppTime.toAppLocal(e.startedAt);
    if (DateTime(local.year, local.month, local.day).isBefore(today)) continue;
    final key = e.url.isNotEmpty
        ? e.url
        : '${e.title}|${e.startedAt.toIso8601String()}';
    final group = groups[key];
    groups[key] = FavoriteNextEvent(
      event: group?.event ?? e,
      users: [...?group?.users, u],
    );
  }
  return groups.values.toList()
    ..sort((a, b) => a.event.startedAt.compareTo(b.event.startedAt));
}
