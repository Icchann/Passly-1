import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:passly/features/auth/domain/auth_notifier.dart';
import 'package:passly/features/user/data/tech_tag_catalog.dart';
import 'package:passly/features/user/data/user_repository.dart';

/// カンマ / スラッシュ / 中点 / 空白 で区切られた tech_stack 文字列をタグ配列にする。
///
/// 「React Native」のようにカタログに空白入りのタグがあるので，
/// 区切り方は [TechTagCatalog.parse] にそろえる。
List<String> parseTechTags(String raw) => TechTagCatalog.parse(raw);

/// 大文字小文字を無視して積集合を返す。表示順は相手側の順序を維持。
List<String> commonTechTags(String mine, String other) {
  final mineLower = parseTechTags(mine).map((t) => t.toLowerCase()).toSet();
  return parseTechTags(
    other,
  ).where((t) => mineLower.contains(t.toLowerCase())).toList();
}

/// 共通タグを求める相手。
///
/// [techStack] が空のときは GET /users/:id で相手のプロフィールを取りに行く。
/// recent_encounters や calendar/daily が tech_stack を返すようになれば
/// 追加の通信はなくなる。
typedef CommonTagsTarget = ({String userId, String techStack});

/// ログイン中ユーザーと相手の共通タグ。
final commonTagsProvider =
    FutureProvider.family<List<String>, CommonTagsTarget>((ref, target) async {
      final mine = ref.watch(
        authNotifierProvider.select((s) => s.value?.techStack ?? ''),
      );
      if (mine.trim().isEmpty) return const [];

      var other = target.techStack;
      if (other.trim().isEmpty && target.userId.isNotEmpty) {
        try {
          final user = await ref.watch(userByIdProvider(target.userId).future);
          other = user.techStack;
        } catch (_) {
          return const [];
        }
      }
      return commonTechTags(mine, other);
    });

/// 相手が付けているタグ全部。
///
/// [CommonTagsTarget.techStack] が空のときは GET /users/:id で取りに行く
/// （[commonTagsProvider] と同じ通信なので，キャッシュが共有される）。
final techTagsOfProvider =
    FutureProvider.family<List<String>, CommonTagsTarget>((ref, target) async {
      var raw = target.techStack;
      if (raw.trim().isEmpty && target.userId.isNotEmpty) {
        try {
          final user = await ref.watch(userByIdProvider(target.userId).future);
          raw = user.techStack;
        } catch (_) {
          return const [];
        }
      }
      return parseTechTags(raw);
    });

/// 共通タグが一番多い人を返す。同数のときは [items] で先に来る人を優先する。
T? pickMostCommon<T>(List<T> items, List<String> Function(T) tagsOf) {
  T? best;
  var bestCount = 0;
  for (final item in items) {
    final count = tagsOf(item).length;
    if (count > bestCount) {
      best = item;
      bestCount = count;
    }
  }
  return best;
}
