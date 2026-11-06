import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:passly/common/widgets/common_tag_person_card.dart';
import 'package:passly/common/widgets/passly_header.dart';
import 'package:passly/common/widgets/passly_segmented_switch.dart';
import 'package:passly/common/widgets/loading_card_skeleton.dart';
import 'package:passly/common/widgets/passly_icon.dart';
import 'package:passly/core/constants/app_colors.dart';
import 'package:passly/core/constants/passly_tokens.dart';
import 'package:passly/features/close_friend/domain/close_friend_list_notifier.dart';
import 'package:passly/features/home/domain/home_notifier.dart';
import 'package:passly/features/home/domain/recent_encounter.dart';
import 'package:passly/features/user/domain/common_tags.dart';
import 'package:passly/features/user/domain/user_model.dart';

/// 広場画面。
///
/// 今まですれ違った人を「共通点のある人 / すべて」で切り替えて並べる。
/// 開いたときは共通点のある人（0 人なら「すべて」）。
/// お気に入りの人は名前の横に黄色の★が付く。
///
/// バックエンド追加ゼロで既存プロバイダー流用:
/// - すれ違った人: [homeNotifierProvider] の `recentEncounters`
///   (`GET /users/:id/home` の recent_encounters を再利用)
/// - お気に入り: [closeFriendListProvider] (`GET /users/:id/close-friends`)
class PlazaScreen extends ConsumerStatefulWidget {
  const PlazaScreen({super.key});

  @override
  ConsumerState<PlazaScreen> createState() => _PlazaScreenState();
}

class _PlazaScreenState extends ConsumerState<PlazaScreen> {
  /// ユーザーが切り替えた後のタブ。null の間は自動で決める。
  int? _selectedTab;

  @override
  Widget build(BuildContext context) {
    final homeState = ref.watch(homeNotifierProvider);
    final favoriteIds = {
      for (final u
          in ref.watch(closeFriendListProvider).asData?.value ??
              const <UserModel>[])
        u.id,
    };

    return Scaffold(
      backgroundColor: PasslyBg.defaultBg,
      body: Column(
        children: [
          PasslyHeader(
            title: 'すれ違い一覧',
            subtitle: '友達検索も',
            trailing: [
              _HeaderSearchIcon(onTap: () => context.push('/plaza/search')),
            ],
          ),
          Expanded(
            child: RefreshIndicator(
              color: PasslyBrand.primary,
              onRefresh: () async {
                // CloseFriendListNotifier に refresh は無いので invalidate で
                // build() をやり直させて再フェッチする。
                ref.invalidate(closeFriendListProvider);
                await ref.read(homeNotifierProvider.notifier).refresh();
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(15, 16, 15, 120),
                children: homeState.when(
                  data: (data) => _buildList(
                    context,
                    _uniqueByUser(data.recentEncounters),
                    favoriteIds,
                  ),
                  loading: () => const [LoadingCardsSkeleton()],
                  error: (_, _) => const [
                    _EmptyMessage(text: 'すれ違い履歴の取得に失敗しました'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildList(
    BuildContext context,
    List<RecentEncounter> encounters,
    Set<String> favoriteIds,
  ) {
    if (encounters.isEmpty) {
      return const [_EmptyMessage(text: 'まだすれ違いがありません')];
    }

    final tagsByUser = <String, AsyncValue<List<String>>>{
      for (final e in encounters)
        e.userId: ref.watch(
          commonTagsProvider((userId: e.userId, techStack: e.techStack)),
        ),
    };
    List<String>? tagsOf(RecentEncounter e) =>
        tagsByUser[e.userId]?.asData?.value;

    final stillLoading = tagsByUser.values.any((v) => v.isLoading);
    final withCommon = encounters
        .where((e) => (tagsOf(e) ?? const []).isNotEmpty)
        .toList();
    final tab = _selectedTab ?? (withCommon.isEmpty && !stillLoading ? 1 : 0);
    final visible = tab == 0 ? withCommon : encounters;

    return [
      PasslySegmentedSwitch(
        labels: ['共通点のある人　${withCommon.length}', 'すべて　${encounters.length}'],
        selectedIndex: tab,
        onChanged: (i) => setState(() => _selectedTab = i),
      ),
      const SizedBox(height: PasslySpace.s4),
      if (visible.isEmpty)
        stillLoading
            ? const LoadingCardsSkeleton(count: 2)
            : const _EmptyMessage(text: '共通点のある人はまだいません')
      else
        for (final e in visible)
          Padding(
            key: ValueKey(e.userId),
            padding: const EdgeInsets.only(top: PasslySpace.s4),
            child: CommonTagPersonCard(
              name: e.name,
              iconUrl: e.iconUrl,
              subtitle: e.eventName.trim(),
              commonTags: tagsOf(e),
              allTags: ref
                  .watch(
                    techTagsOfProvider((
                      userId: e.userId,
                      techStack: e.techStack,
                    )),
                  )
                  .asData
                  ?.value,
              isFavorite: favoriteIds.contains(e.userId),
              onTap: () => context.push('/profile/${e.userId}'),
            ),
          ),
    ];
  }

  /// 同じ人と何度すれ違っても 1 件にまとめる（新しい方を残す）。
  static List<RecentEncounter> _uniqueByUser(List<RecentEncounter> items) {
    final sorted = [...items]..sort((a, b) => b.metAt.compareTo(a.metAt));
    final seen = <String>{};
    return sorted.where((e) => seen.add(e.userId)).toList();
  }
}

class _EmptyMessage extends StatelessWidget {
  final String text;
  const _EmptyMessage({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: PasslyFont.family,
          color: PasslyText.secondary,
          fontSize: 14,
          fontWeight: PasslyFont.medium,
        ),
      ),
    );
  }
}

/// 40x40 の検索アイコン。カレンダーヘッダーと同じ [PasslyIcons.search] を使い、
/// アプリ全体でアイコンの見た目 / タップサイズを統一する。
class _HeaderSearchIcon extends StatelessWidget {
  final VoidCallback onTap;
  const _HeaderSearchIcon({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: const SizedBox(
        width: 40,
        height: 40,
        child: Center(
          child: PasslyIcon(
            asset: PasslyIcons.search,
            size: 30,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
