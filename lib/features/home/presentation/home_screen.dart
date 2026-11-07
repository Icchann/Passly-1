import 'package:flutter/material.dart';
import 'package:passly/common/widgets/sized_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:passly/common/widgets/common_tag_chip.dart';
import 'package:passly/common/widgets/common_tag_person_card.dart';
import 'package:passly/common/widgets/loading_card_skeleton.dart';
import 'package:passly/common/widgets/passly_header.dart';
import 'package:passly/core/constants/app_colors.dart';
import 'package:passly/core/config/feature_flags.dart';
import 'package:passly/core/constants/passly_tokens.dart';
import 'package:passly/demo/demo_api.dart';
import 'package:passly/features/encounter/domain/encounter_notifier.dart';
import 'package:passly/features/home/domain/home_notifier.dart';
import 'package:passly/features/home/domain/recent_encounter.dart';
import 'package:passly/features/auth/domain/auth_notifier.dart';
import 'package:passly/features/home/presentation/widgets/pocket_mode_button.dart';
import 'package:passly/core/utils/app_time.dart';
import 'package:passly/features/user/domain/common_tags.dart';

/// ホーム画面。
///
/// 今日すれ違った人のうち，共通タグのある人だけを出す。
/// いちばん共通点が多い人を大きいカードで上に置き，残りは一覧にする。
/// 話しかける勇気がない人でも，共通点がある人なら最初の一言をかけやすいため。
/// 右上は自分のアイコン（マイページへ）。ポケットモードの切り替えは iOS だけ、
/// [MainScreen] がナビの上に [PocketModeButton] として出す。
///
/// ボトムナビは [MainScreen] 側で `PasslyBottomNav` として全タブ共通で描画する。
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  /// デモ用。すれ違ったことにして、すれ違い画面を開く。
  Future<void> _showDemoEncounter(BuildContext context, WidgetRef ref) async {
    DemoApi.instance.startEncounter();
    ref.invalidate(encounterNotifierProvider);
    await ref.read(encounterNotifierProvider.future);
    if (context.mounted) context.go('/encounter-result');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeState = ref.watch(homeNotifierProvider);
    final myIconUrl = ref.watch(
      authNotifierProvider.select((s) => s.value?.iconUrl),
    );

    return Scaffold(
      backgroundColor: PasslyBg.defaultBg,
      // PasslyHeader 自身が SafeArea を処理するため、ここでは wrap しない。
      // これでヘッダーの白背景がステータスバー / Dynamic Island 領域まで届く。
      body: Column(
        children: [
          GestureDetector(
            // デモモードのときだけ、ヘッダー長押しですれ違い画面を出す
            onLongPress: FeatureFlags.demoMode
                ? () => _showDemoEncounter(context, ref)
                : null,
            child: PasslyHeader.home(
              avatarUrl: (myIconUrl?.isEmpty ?? true) ? null : myIconUrl,
              onAvatarTap: () => context.go('/mypage'),
            ),
          ),
          Expanded(
            child: homeState.when(
              data: (data) => _buildContent(context, ref, data),
              loading: () => _buildContent(
                context,
                ref,
                HomeState.empty(),
                isLoading: true,
              ),
              error: (_, _) => _buildErrorState(ref),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    HomeState data, {
    bool isLoading = false,
  }) {
    final todayEncounters = _uniqueByUser(_filterToday(data.recentEncounters));

    return RefreshIndicator(
      color: PasslyBrand.primary,
      onRefresh: () => ref.read(homeNotifierProvider.notifier).refresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(
          left: PasslySpace.s16,
          right: PasslySpace.s16,
          top: PasslySpace.s24,
          // ナビとその上のポケットモードボタンに最後のカードが隠れないようにする
          bottom: 180,
        ),
        children: isLoading
            ? const [LoadingCardsSkeleton()]
            : _buildCommonTagSections(context, ref, todayEncounters),
      ),
    );
  }

  /// 「いちばん共通点が多い人」の大きいカードと「ほかに共通点のある人」一覧。
  ///
  /// 共通タグのない人はホームには出さない（なくても成り立つ情報は入れない）。
  List<Widget> _buildCommonTagSections(
    BuildContext context,
    WidgetRef ref,
    List<RecentEncounter> items,
  ) {
    if (items.isEmpty) {
      return const [_EmptyMessage(text: '今日はまだ誰ともすれ違っていません')];
    }

    final tagsByUser = <String, AsyncValue<List<String>>>{
      for (final e in items)
        e.userId: ref.watch(
          commonTagsProvider((userId: e.userId, techStack: e.techStack)),
        ),
    };
    List<String> tagsOf(RecentEncounter e) =>
        tagsByUser[e.userId]?.asData?.value ?? const [];

    final withCommon = items.where((e) => tagsOf(e).isNotEmpty).toList();
    final stillLoading = tagsByUser.values.any((v) => v.isLoading);

    if (withCommon.isEmpty) {
      return [
        if (stillLoading)
          const LoadingCardsSkeleton(count: 2)
        else
          const _EmptyMessage(text: '今日すれ違った人の中に，共通タグのある人はいませんでした'),
      ];
    }

    final featured = pickMostCommon(withCommon, tagsOf)!;
    final others = withCommon.where((e) => e != featured).toList();

    return [
      const _SectionTitle('いちばん共通点が多い人'),
      const SizedBox(height: PasslySpace.s20),
      _FeaturedCard(
        encounter: featured,
        commonTags: tagsOf(featured),
        onTap: () => context.push('/profile/${featured.userId}'),
      ),
      if (others.isNotEmpty) ...[
        const SizedBox(height: PasslySpace.s24),
        const _SectionTitle('ほかに共通点のある人'),
        const SizedBox(height: PasslySpace.s20),
        for (final e in others)
          Padding(
            padding: const EdgeInsets.only(bottom: PasslySpace.s4),
            child: CommonTagPersonCard(
              name: e.name,
              iconUrl: e.iconUrl,
              commonTags: tagsOf(e),
              onTap: () => context.push('/profile/${e.userId}'),
            ),
          ),
      ],
    ];
  }

  /// 同じ人と何度すれ違っても 1 件にまとめる（新しい方を残す）。
  List<RecentEncounter> _uniqueByUser(List<RecentEncounter> items) {
    final sorted = [...items]..sort((a, b) => b.metAt.compareTo(a.metAt));
    final seen = <String>{};
    return sorted.where((e) => seen.add(e.userId)).toList();
  }

  /// 日本時間で今日すれ違った人だけに絞る。
  List<RecentEncounter> _filterToday(List<RecentEncounter> items) {
    final today = AppTime.nowLocal();
    return items.where((e) {
      final local = AppTime.toAppLocal(e.metAt);
      return local.year == today.year &&
          local.month == today.month &&
          local.day == today.day;
    }).toList();
  }

  Widget _buildErrorState(WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 48,
            color: PasslyText.secondary,
          ),
          const SizedBox(height: PasslySpace.s16),
          const Text(
            'データの取得に失敗しました',
            style: TextStyle(color: PasslyText.secondary, fontSize: 16),
          ),
          const SizedBox(height: PasslySpace.s16),
          ElevatedButton(
            onPressed: () => ref.read(homeNotifierProvider.notifier).refresh(),
            style: ElevatedButton.styleFrom(
              backgroundColor: PasslyBrand.primary,
            ),
            child: const Text('再試行', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: PasslyFont.family,
        color: AppColors.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w900,
        height: 24 / 20,
      ),
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  final String text;
  const _EmptyMessage({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: PasslySpace.s16),
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

/// いちばん共通点が多い人のカード。
///
/// アイコン + 名前 + 「◯◯ですれ違いました」，共通タグ（全部・折り返し），
/// 「プロフィールを見る」ボタン。
class _FeaturedCard extends StatelessWidget {
  final RecentEncounter encounter;
  final List<String> commonTags;
  final VoidCallback onTap;

  const _FeaturedCard({
    required this.encounter,
    required this.commonTags,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final eventName = encounter.eventName.trim();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: PasslyBg.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _FeaturedAvatar(url: encounter.iconUrl),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      encounter.name.isEmpty ? '名前未設定' : encounter.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: PasslyFont.family,
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        height: 24 / 20,
                      ),
                    ),
                    if (eventName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        '$eventName ですれ違いました',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: PasslyFont.family,
                          color: PasslyText.secondary,
                          fontSize: 12,
                          fontWeight: PasslyFont.regular,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 3, right: 6),
                child: Text(
                  '共通タグ',
                  style: TextStyle(
                    fontFamily: PasslyFont.family,
                    color: PasslyBrand.primaryDark,
                    fontSize: 12,
                    fontWeight: PasslyFont.bold,
                  ),
                ),
              ),
              Expanded(child: CommonTagWrap(tags: commonTags)),
            ],
          ),
          const SizedBox(height: 14),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(100),
              onTap: onTap,
              child: Container(
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: PasslyBrand.primaryLight,
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Text(
                  'プロフィールを見る',
                  style: TextStyle(
                    fontFamily: PasslyFont.family,
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 16.8 / 20,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturedAvatar extends StatelessWidget {
  final String url;
  const _FeaturedAvatar({required this.url});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: PasslyBg.elevated,
      alignment: Alignment.center,
      child: const Icon(Icons.person, color: PasslyText.tertiary, size: 32),
    );
    return ClipOval(
      child: SizedBox(
        width: 63,
        height: 63,
        child: url.isNotEmpty
            ? SizedNetworkImage(url: url, fallback: (_) => fallback)
            : fallback,
      ),
    );
  }
}
