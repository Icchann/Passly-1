import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:passly/common/widgets/tag_sticker.dart';
import 'package:passly/common/widgets/passly_circle_button.dart';
import 'package:passly/common/widgets/passly_icon.dart';
import 'package:passly/common/widgets/press_feedback.dart';
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
/// 上から: カバー写真 + 右上（「編集」＋「…」メニュー）+ アバター +
/// 名前 / 組織チップ + SNS ボタン + 自己紹介 / タグ（白いカード）。
///
/// 編集ボタンは開いてすぐ見えるよう右上に置く（下にあるとスクロールが要った）。
/// QR 交換と設定は「…」のメニューにまとめて，右上のボタンを 2 つに減らす。
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
                _NameSection(name: user.name, affiliation: user.affiliation),
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
              ],
            ),
          ),
          // カバー写真の上に「編集」＋「…」（QR 交換・設定）。
          SafeArea(
            child: _FloatingHeader(
              onEdit: () => context.push('/mypage/edit'),
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

/// カバー写真の上の右上ボタン：「✏ 編集」と「…」。
///
/// 「…」を押すと QR でプロフィール交換・設定のメニューが開く。
/// マイページはボトムナビタブから開くため戻るボタンは置かない。
class _FloatingHeader extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenQr;

  const _FloatingHeader({
    required this.onEdit,
    required this.onOpenSettings,
    required this.onOpenQr,
  });

  @override
  Widget build(BuildContext context) {
    // 他画面のヘッダー (PasslyHeader) と横方向の位置を揃えるため左右 20。
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _EditPill(onTap: onEdit),
          const SizedBox(width: 4),
          _MoreMenuButton(onOpenQr: onOpenQr, onOpenSettings: onOpenSettings),
        ],
      ),
    );
  }
}

/// 白いピルの「✏ 編集」ボタン。丸ボタン（直径 30）と高さを揃える。
class _EditPill extends StatelessWidget {
  final VoidCallback onTap;

  const _EditPill({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'プロフィールを編集',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: PressFeedback(
          // タップ範囲は丸ボタンと同じ高さ 40 にする
          child: SizedBox(
            height: 40,
            child: Center(
              child: Container(
                height: PasslyCircleButton.diameter,
                padding: const EdgeInsets.only(left: 10, right: 12),
                decoration: const ShapeDecoration(
                  color: PasslyBg.surface,
                  shape: StadiumBorder(),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PasslyIcon(
                      asset: PasslyIcons.edit,
                      size: 15,
                      color: PasslyText.primary,
                    ),
                    SizedBox(width: 4),
                    Text(
                      '編集',
                      style: TextStyle(
                        fontFamily: PasslyFont.family,
                        color: PasslyText.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _MoreAction { qr, settings }

/// 「…」ボタン。押すと QR 交換・設定のメニューを出す。
class _MoreMenuButton extends StatelessWidget {
  final VoidCallback onOpenQr;
  final VoidCallback onOpenSettings;

  const _MoreMenuButton({required this.onOpenQr, required this.onOpenSettings});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_MoreAction>(
      tooltip: 'その他',
      offset: const Offset(0, 44),
      color: PasslyBg.surface,
      elevation: 6,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (action) => switch (action) {
        _MoreAction.qr => onOpenQr(),
        _MoreAction.settings => onOpenSettings(),
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: _MoreAction.qr,
          child: _MenuRow(
            asset: PasslyIcons.addFriend,
            iconSize: 18,
            label: 'QRでプロフィール交換',
          ),
        ),
        PopupMenuItem(
          value: _MoreAction.settings,
          child: _MenuRow(
            asset: PasslyIcons.settings,
            iconSize: 20,
            label: '設定',
          ),
        ),
      ],
      child: SizedBox(
        width: 40,
        height: 40,
        child: Center(
          child: Container(
            width: PasslyCircleButton.diameter,
            height: PasslyCircleButton.diameter,
            decoration: const BoxDecoration(
              color: PasslyBg.surface,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.more_horiz,
              size: 20,
              color: PasslyText.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final String asset;
  final double iconSize;
  final String label;

  const _MenuRow({
    required this.asset,
    required this.iconSize,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 22,
          child: Center(
            child: PasslyIcon(
              asset: asset,
              size: iconSize,
              color: PasslyText.primary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            fontFamily: PasslyFont.family,
            color: PasslyText.primary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _NameSection extends StatelessWidget {
  final String name;
  final String affiliation;

  const _NameSection({required this.name, required this.affiliation});

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
