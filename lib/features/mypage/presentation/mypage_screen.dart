import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:passly/common/widgets/tag_sticker.dart';
import 'package:passly/common/widgets/passly_circle_button.dart';
import 'package:passly/common/widgets/passly_icon.dart';
import 'package:passly/common/widgets/profile_section_card.dart';
import 'package:passly/common/widgets/sns_link_buttons.dart';
import 'package:passly/core/constants/app_colors.dart';
import 'package:passly/core/constants/passly_tokens.dart';
import 'package:passly/features/auth/domain/auth_notifier.dart';
import 'package:passly/features/mypage/presentation/widgets/profile_images.dart';
import 'package:passly/features/user/data/tech_tag_catalog.dart';

/// 自分のプロフィール画面 (Figma「マイページ案A：相手と同じ見た目（1画面）」)。
///
/// すれ違った人に見える相手プロフィールと同じ見た目にしている。
/// 上から: カバー写真 + 右上 (友だち追加 / 設定) + アバター +
/// 名前 / 一言 / 組織チップ + SNS ボタン + 自己紹介 / タグ（白いカード） +
/// 「すれ違った人にもこの見た目で表示されます」+「プロフィールを編集」。
///
/// 編集は別画面 (/mypage/edit, [ProfileEditScreen]) で行う。
class MyPageScreen extends ConsumerWidget {
  const MyPageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authNotifierProvider).value;

    if (user == null) {
      return const Scaffold(
        backgroundColor: PasslyBg.defaultBg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: PasslyBg.defaultBg,
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 140),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // カバー画像が Dynamic Island / 時計に隠されないよう
                // ステータスバー分だけ上に伸ばす。
                _CoverAndAvatar(
                  coverUrl: user.coverUrl,
                  iconUrl: user.iconUrl,
                  extraTopHeight: MediaQuery.of(context).padding.top,
                ),
                const SizedBox(height: 16),
                _NameSection(
                  name: user.name,
                  oneWord: user.oneWord,
                  affiliation: user.affiliation,
                ),
                if (snsLinksOf(user).isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 21),
                    child: SnsLinkButtons(profile: user),
                  ),
                ],
                const SizedBox(height: PasslySpace.s24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: _AboutSection(about: user.about),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: _TechTagSection(techStack: user.techStack),
                ),
                const SizedBox(height: 28),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 21),
                  child: _EditProfileButton(
                    onTap: () => context.push('/mypage/edit'),
                  ),
                ),
              ],
            ),
          ),
          // カバー写真の上に (QR / 友だち追加) + 歯車。
          SafeArea(
            child: _FloatingHeader(
              onOpenSettings: () => context.push('/settings'),
              onOpenQr: () => context.push('/mypage/qr'),
            ),
          ),
        ],
      ),
    );
  }
}

/// カバー写真 + 中央に半分乗ったアバター。
///
/// Figma spec: カバー 275x412 (top -85 で上端にせり出す) + アバター 100x100 中央下寄せ。
class _CoverAndAvatar extends StatelessWidget {
  final String coverUrl;
  final String iconUrl;

  /// 画面上端 (ステータスバー / Dynamic Island の下) までカバーを伸ばすための
  /// 追加高さ。呼び出し側で MediaQuery.padding.top を渡す。
  final double extraTopHeight;

  const _CoverAndAvatar({
    required this.coverUrl,
    required this.iconUrl,
    this.extraTopHeight = 0,
  });

  static const double _baseCoverHeight = 190;
  static const double _avatarSize = 100;

  @override
  Widget build(BuildContext context) {
    final coverHeight = _baseCoverHeight + extraTopHeight;
    return SizedBox(
      // アバターが半分下にせり出す分だけ余白を確保。
      height: coverHeight + _avatarSize / 2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: coverHeight,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              child: ProfileCoverImage(url: coverUrl),
            ),
          ),
          Positioned(
            top: coverHeight - _avatarSize / 2,
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                width: _avatarSize,
                height: _avatarSize,
                child: ProfileAvatarCircle(url: iconUrl),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Figma のヘッダー (node 1300:1904) 準拠: カバー写真の上に配置する
/// 透明ヘッダー。右端に「友だち追加 (QR) + 歯車」を並べる。
///
/// マイページはボトムナビタブから開くため戻る先が無く Figma の左上戻る
/// ボタンは撤去済み。代わりに歯車ボタンから設定画面へ遷移する。
class _FloatingHeader extends StatelessWidget {
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenQr;

  const _FloatingHeader({required this.onOpenSettings, required this.onOpenQr});

  @override
  Widget build(BuildContext context) {
    // 右端に「友だち追加 (QR) + 歯車」を横並びに配置。
    // 編集は画面下の「プロフィールを編集」ボタンから入る。
    // 他画面のヘッダー (PasslyHeader) と横方向の位置を揃えるため
    // 左右 20 のパディングに統一する。
    // ボタンは白い丸なので、カバー写真の明るさに関係なくアイコンは濃い色。
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          PasslyCircleButton(
            asset: PasslyIcons.addFriend,
            iconSize: 20,
            onTap: onOpenQr,
          ),
          const SizedBox(width: 8),
          PasslyCircleButton(
            asset: PasslyIcons.settings,
            iconSize: 24,
            onTap: onOpenSettings,
          ),
        ],
      ),
    );
  }
}

class _NameSection extends StatelessWidget {
  final String name;
  final String oneWord;
  final String affiliation;

  const _NameSection({
    required this.name,
    required this.oneWord,
    required this.affiliation,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          name.isEmpty ? '未設定' : name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: PasslyFont.family,
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            height: 24 / 20,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          oneWord.isEmpty ? '一言未設定' : oneWord,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: PasslyFont.family,
            color: oneWord.isEmpty
                ? AppColors.textDisabled
                : PasslyText.secondary,
            fontSize: 14,
            fontWeight: PasslyFont.regular,
            height: 16.8 / 14,
          ),
        ),
        if (affiliation.isNotEmpty) ...[
          const SizedBox(height: 8),
          _AffiliationChip(text: affiliation),
        ],
      ],
    );
  }
}

/// 組織 / 所属を表す小さめのチップ (Figma node 1242:1429 のタグと同構造)。
class _AffiliationChip extends StatelessWidget {
  final String text;
  const _AffiliationChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: PasslyBg.surface,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: PasslyBorder.strong, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.corporate_fare,
            size: 14,
            color: PasslyText.secondary,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontFamily: PasslyFont.family,
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: PasslyFont.medium,
              height: 14.4 / 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutSection extends StatelessWidget {
  final String about;

  const _AboutSection({required this.about});

  @override
  Widget build(BuildContext context) {
    return ProfileSectionCard(
      title: '自己紹介',
      child: Text(
        about.isEmpty ? '自己紹介は未設定です' : about,
        style: TextStyle(
          fontFamily: PasslyFont.family,
          color: about.isEmpty ? AppColors.textDisabled : AppColors.textPrimary,
          fontSize: 14,
          fontWeight: PasslyFont.medium,
          height: 1.6,
        ),
      ),
    );
  }
}

class _TechTagSection extends StatelessWidget {
  final String techStack;

  const _TechTagSection({required this.techStack});

  @override
  Widget build(BuildContext context) {
    return ProfileSectionCard(
      title: 'タグ',
      child: _TagWrap(tags: TechTagCatalog.parse(techStack)),
    );
  }
}

class _TagWrap extends StatelessWidget {
  final List<String> tags;
  const _TagWrap({required this.tags});

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) {
      return const Text(
        '未設定',
        style: TextStyle(
          fontFamily: PasslyFont.family,
          color: AppColors.textDisabled,
          fontSize: 12,
          fontWeight: PasslyFont.medium,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 2),
      child: Wrap(
        spacing: 6,
        runSpacing: 12,
        children: [for (final tag in tags) LabeledTagSticker(tag: tag)],
      ),
    );
  }
}

/// 画面下の「すれ違った人にもこの見た目で表示されます」＋「プロフィールを編集」。
///
/// マイページは相手プロフィールと同じ見た目にしているので，
/// 切り替えなしで「相手にはこう見える」ことを 1 行で伝える。
class _EditProfileButton extends StatelessWidget {
  final VoidCallback onTap;

  const _EditProfileButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.visibility_outlined,
              size: 16,
              color: PasslyText.secondary,
            ),
            SizedBox(width: 6),
            Flexible(
              child: Text(
                'すれ違った人にもこの見た目で表示されます',
                style: TextStyle(
                  fontFamily: PasslyFont.family,
                  color: PasslyText.secondary,
                  fontSize: 12,
                  fontWeight: PasslyFont.regular,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(100),
            onTap: onTap,
            child: Ink(
              height: 50,
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
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  PasslyIcon(
                    asset: PasslyIcons.edit,
                    size: 20,
                    color: Colors.white,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'プロフィールを編集',
                    style: TextStyle(
                      fontFamily: PasslyFont.family,
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
