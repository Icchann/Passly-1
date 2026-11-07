import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:passly/common/widgets/tag_sticker.dart';
import 'package:passly/common/widgets/passly_icon.dart';
import 'package:passly/common/widgets/loading_card_skeleton.dart';
import 'package:passly/common/widgets/profile_section_card.dart';
import 'package:passly/common/widgets/sns_link_buttons.dart';
import 'package:passly/core/constants/app_colors.dart';
import 'package:passly/core/constants/passly_tokens.dart';
import 'package:passly/features/auth/domain/auth_notifier.dart';
import 'package:passly/features/close_friend/domain/close_friend_list_notifier.dart';
import 'package:passly/features/user/data/user_repository.dart';
import 'package:passly/features/user/domain/common_tags.dart';
import 'package:passly/features/user/domain/user_model.dart';
import 'package:passly/core/utils/app_time.dart';

final profileProvider = userByIdProvider;

/// 相手プロフィール画面。
///
/// 上から 名前・お気に入り・SNS ボタン・出会ったイベント・自己紹介・タグ。
/// タグでは自分と同じタグを緑のチェック付きで先頭に出し，
/// 「話のネタ」と SNS ボタンで次に話しかけるきっかけを作る。
/// 次に行くイベントはここには出さず，イベント画面で見せる。
/// 名前の下のボタンでお気に入りに追加・解除できる
/// （中身は既存の close-friends API を使う）。
class ProfileScreen extends ConsumerWidget {
  final String userId;

  const ProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (userId.isEmpty) {
      return const Scaffold(
        backgroundColor: AppColors.backgroundGrey,
        body: Center(child: Text('プロフィールIDが不正です')),
      );
    }

    final profileAsync = ref.watch(profileProvider(userId));
    final myTechStack = ref.watch(
      authNotifierProvider.select((s) => s.value?.techStack ?? ''),
    );

    return Scaffold(
      backgroundColor: AppColors.backgroundGrey,
      body: profileAsync.when(
        data: (profile) => _ProfileBody(
          userId: userId,
          profile: profile,
          myTechStack: myTechStack,
        ),
        loading: () => const Padding(
          padding: EdgeInsets.all(16),
          child: LoadingCardsSkeleton(),
        ),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'プロフィールの取得に失敗しました\n$error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}

/// プロフィール本体。
class _ProfileBody extends StatelessWidget {
  final String userId;
  final UserModel profile;
  final String myTechStack;

  const _ProfileBody({
    required this.userId,
    required this.profile,
    required this.myTechStack,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: 24 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CoverAndAvatar(profile: profile),
          const SizedBox(height: 16),
          _NameSection(profile: profile),
          const SizedBox(height: 12),
          Center(
            child: _FavoriteButton(userId: userId, profile: profile),
          ),
          if (snsLinksOf(profile).isNotEmpty) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 21),
              child: SnsLinkButtons(profile: profile),
            ),
          ],
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: _EncounterCard(profile: profile),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: _AboutSection(profile: profile),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: _TechTagSection(profile: profile, myTechStack: myTechStack),
          ),
        ],
      ),
    );
  }
}

/// カバー画像 + 戻るボタン + 半分重なるアバターを 1 つの Stack で構成する。
class _CoverAndAvatar extends StatelessWidget {
  static const double _coverHeight = 190;
  static const double _avatarSize = 100;

  final UserModel profile;

  const _CoverAndAvatar({required this.profile});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return SizedBox(
      height: _coverHeight + _avatarSize / 2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SizedBox(
            height: _coverHeight,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              child: _buildCover(),
            ),
          ),
          Positioned(top: topPadding + 12, left: 20, child: _BackButton()),
          Positioned(
            top: _coverHeight - _avatarSize / 2,
            left: 0,
            right: 0,
            child: Center(child: _Avatar(iconUrl: profile.iconUrl)),
          ),
        ],
      ),
    );
  }

  Widget _buildCover() {
    if (profile.coverUrl.isNotEmpty) {
      return Image.network(
        profile.coverUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _coverFallback(),
      );
    }
    return _coverFallback();
  }

  Widget _coverFallback() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.6),
            AppColors.primary.withValues(alpha: 0.9),
          ],
        ),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.image_outlined, color: Colors.white, size: 48),
    );
  }
}

class _BackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.divider,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: () {
          if (context.canPop()) {
            context.pop();
          }
        },
        child: const SizedBox(
          width: 36,
          height: 36,
          child: Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.textPrimary,
            size: 18,
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String iconUrl;

  const _Avatar({required this.iconUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.backgroundWhite,
        border: Border.all(color: AppColors.backgroundWhite, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: iconUrl.isNotEmpty
            ? Image.network(
                iconUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _fallback(),
              )
            : _fallback(),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      color: AppColors.backgroundGrey,
      alignment: Alignment.center,
      child: const Icon(Icons.person, color: AppColors.textLight, size: 48),
    );
  }
}

class _NameSection extends StatelessWidget {
  final UserModel profile;

  const _NameSection({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          profile.name.isEmpty ? '名前未設定' : profile.name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            height: 24 / 20,
          ),
        ),
      ],
    );
  }
}

/// 「出会ったイベント」のカード：最後にすれ違った日とイベント。
/// 自己紹介やタグと同じ白いカードにして，プロフィールの先頭に置く。
class _EncounterCard extends StatelessWidget {
  final UserModel profile;

  const _EncounterCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 15),
      decoration: BoxDecoration(
        color: PasslyBg.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PasslyBorder.divider),
      ),
      child: Row(
        children: [
          const PasslyIcon(asset: PasslyIcons.fire, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _formatLastEncounter(),
              style: const TextStyle(
                fontFamily: PasslyFont.family,
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: PasslyFont.medium,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 「3月11日 SysHack2026 で出会いました」。
  String _formatLastEncounter() {
    final last = profile.lastEncounter;
    if (last == null) return 'すれ違いで出会いました';
    final d = AppTime.toAppLocal(last.metAt);
    final eventName = last.eventName.trim();
    final place = eventName.isEmpty ? 'すれ違い' : eventName;
    return '${d.month}月${d.day}日 $place で出会いました';
  }
}

/// 「☆ お気に入りに追加」/「★ お気に入り済み」のピル。タップで切り替える。
class _FavoriteButton extends ConsumerWidget {
  final String userId;
  final UserModel profile;

  const _FavoriteButton({required this.userId, required this.profile});

  static const Color _star = Color(0xFFF5B400);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(closeFriendListProvider);
    final isBusy = favorites.isLoading;
    final isFavorite =
        favorites.asData?.value.any((u) => u.id == userId) ?? false;

    return Opacity(
      opacity: isBusy ? 0.5 : 1,
      child: Material(
        color: isFavorite ? const Color(0xFFFFF6D6) : AppColors.backgroundWhite,
        shape: StadiumBorder(
          side: BorderSide(
            color: isFavorite ? const Color(0xFFF5C542) : PasslyBorder.strong,
          ),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: isBusy ? null : () => _toggle(context, ref, isFavorite),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 7, 18, 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 18,
                  color: isFavorite ? _star : const Color(0xFF4B5563),
                ),
                const SizedBox(width: 6),
                Text(
                  isFavorite ? 'お気に入り済み' : 'お気に入りに追加',
                  style: TextStyle(
                    color: isFavorite
                        ? const Color(0xFF9A6B00)
                        : AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    bool isFavorite,
  ) async {
    final notifier = ref.read(closeFriendListProvider.notifier);
    try {
      if (isFavorite) {
        await notifier.removeFriend(userId);
      } else {
        await notifier.addFriend(profile.copyWith(id: userId));
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(isFavorite ? 'お気に入りの解除に失敗しました' : 'お気に入りの追加に失敗しました'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }
}

class _AboutSection extends StatelessWidget {
  final UserModel profile;

  const _AboutSection({required this.profile});

  @override
  Widget build(BuildContext context) {
    final text = profile.about.isEmpty ? '自己紹介は未設定です' : profile.about;

    return ProfileSectionCard(
      title: '自己紹介',
      child: Text(
        text,
        style: TextStyle(
          color: profile.about.isEmpty
              ? AppColors.textDisabled
              : AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.6,
        ),
      ),
    );
  }
}

class _TechTagSection extends StatelessWidget {
  final UserModel profile;
  final String myTechStack;

  const _TechTagSection({required this.profile, required this.myTechStack});

  @override
  Widget build(BuildContext context) {
    final tags = parseTechTags(profile.techStack);
    final common = commonTechTags(myTechStack, profile.techStack);
    final commonLower = common.map((t) => t.toLowerCase()).toSet();
    final others = tags
        .where((t) => !commonLower.contains(t.toLowerCase()))
        .toList();

    return ProfileSectionCard(
      title: 'タグ',
      note: common.isEmpty ? null : 'あなたと同じタグが${common.length}つ',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (tags.isEmpty)
            const Text(
              '未設定',
              style: TextStyle(
                color: AppColors.textDisabled,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 2),
              child: Wrap(
                spacing: 6,
                runSpacing: 12,
                children: [
                  for (final tag in common)
                    LabeledTagSticker(tag: tag, same: true),
                  for (final tag in others) LabeledTagSticker(tag: tag),
                ],
              ),
            ),
          if (common.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '次に会ったら「${common.first}好きなんですよね」と話しかけてみよう',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
