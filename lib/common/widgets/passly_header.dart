import 'package:flutter/material.dart';
import 'package:passly/common/widgets/sized_network_image.dart';

import 'package:passly/common/widgets/text_field_context_menu.dart';
import 'package:passly/common/widgets/passly_circle_button.dart';
import 'package:passly/common/widgets/passly_icon.dart';
import 'package:passly/common/widgets/press_feedback.dart';
import 'package:passly/core/constants/app_colors.dart';
import 'package:passly/core/constants/passly_tokens.dart';

/// Passly 共通ヘッダー。
///
/// Figma のヘッダー ComponentSet (node 1191:1101) の 7 バリアントを
/// 名前付きコンストラクタで提供する:
/// - [PasslyHeader.home]           : おかえり！+ サブタイトル + アバター
/// - [PasslyHeader.calendar]       : カレンダー + サブタイトル + 検索 + アバター
/// - [PasslyHeader.otherProfile]   : 戻るボタンのみ（円形）
/// - [PasslyHeader.myProfile]      : 戻る + 編集ペン
/// - [PasslyHeader.search]         : 戻る（角丸小）+ 検索フィールド
/// - [PasslyHeader.encounteredList]: その日に出会った人 + サブタイトル
/// - [PasslyHeader.qr]             : 透明背景 + 閉じる + QR スキャン (node 1528:4372)
///
/// 既存のフレキシブル API（title / subtitle / leading / centerContent / trailing）は
/// そのまま利用可能。既存呼び出し側との後方互換を保つ。
class PasslyHeader extends StatelessWidget {
  /// 左端に置くウィジェット（例: 戻るボタン、なし）
  final Widget? leading;

  /// 大見出し（H1 24px w900）
  final String? title;

  /// 副見出し（14px w500 secondary）
  final String? subtitle;

  /// タイトル領域の代わりに任意ウィジェット（例: 検索フィールド全体）を差し込む場合に使う。
  /// これが与えられている場合、title / subtitle は無視される。
  final Widget? centerContent;

  /// 右端に並べるウィジェット群（例: 検索アイコン、アバター、ペン）
  final List<Widget> trailing;

  /// 下線 divider を表示するか
  final bool showBottomDivider;

  /// ヘッダーの背景色。QR 画面のようにグラデーション背景の上に載せたい場合は
  /// `Colors.transparent` を指定する。
  final Color backgroundColor;

  const PasslyHeader({
    super.key,
    this.leading,
    this.title,
    this.subtitle,
    this.centerContent,
    this.trailing = const [],
    this.showBottomDivider = true,
    this.backgroundColor = AppColors.backgroundWhite,
  }) : assert(
         title != null || centerContent != null || leading != null,
         'PasslyHeader には title / centerContent / leading のいずれかを与える必要があります',
       );

  /// ホームヘッダー (Figma node 1110:2236)。
  /// 「おかえり！」+ サブタイトル + 右端にアバター。
  factory PasslyHeader.home({
    Key? key,
    String? avatarUrl,
    VoidCallback? onAvatarTap,
    String title = 'おかえり！',
    String subtitle = '今日の出会いを見てみよう',
  }) {
    return PasslyHeader(
      key: key,
      title: title,
      subtitle: subtitle,
      trailing: [_HeaderAvatar(url: avatarUrl, onTap: onAvatarTap)],
    );
  }

  /// カレンダーヘッダー (Figma node 1191:1102)。
  /// 「カレンダー」+ サブタイトル + 検索アイコン。
  factory PasslyHeader.calendar({
    Key? key,
    VoidCallback? onSearchTap,
    String title = 'カレンダー',
    String subtitle = 'その日の記録',
  }) {
    return PasslyHeader(
      key: key,
      title: title,
      subtitle: subtitle,
      trailing: [_HeaderSearchIcon(onTap: onSearchTap)],
    );
  }

  /// 相手のプロフィールヘッダー (Figma node 1269:521)。
  /// 円形の戻るボタンのみ。divider・タイトルなし。
  factory PasslyHeader.otherProfile({Key? key, required VoidCallback onBack}) {
    return PasslyHeader(
      key: key,
      leading: PasslyBackButton(onTap: onBack),
      showBottomDivider: false,
    );
  }

  /// 自分のプロフィールヘッダー (Figma node 1300:1904)。
  /// 戻るボタン + 右端に編集ペンボタン。divider なし。
  factory PasslyHeader.myProfile({
    Key? key,
    required VoidCallback onBack,
    required VoidCallback onEdit,
  }) {
    return PasslyHeader(
      key: key,
      leading: PasslyBackButton(onTap: onBack),
      trailing: [_HeaderEditButton(onTap: onEdit)],
      showBottomDivider: false,
    );
  }

  /// 検索ヘッダー (Figma node 1297:859)。
  /// 角丸小の戻るボタン + 検索フィールド。
  factory PasslyHeader.search({
    Key? key,
    required VoidCallback onBack,
    TextEditingController? controller,
    String hintText = 'なんかいい感じの検索',
    ValueChanged<String>? onSubmitted,
    ValueChanged<String>? onChanged,
  }) {
    return PasslyHeader(
      key: key,
      leading: _SmallBackButton(onTap: onBack),
      centerContent: _HeaderSearchField(
        controller: controller,
        hintText: hintText,
        onSubmitted: onSubmitted,
        onChanged: onChanged,
      ),
    );
  }

  /// 出会った人一覧ヘッダー (Figma node 1300:1257)。
  /// 「その日に出会った人」+ サブタイトル。leading / trailing なし。
  factory PasslyHeader.encounteredList({
    Key? key,
    String title = 'その日に出会った人',
    String subtitle = '気になる人を見つけよう！',
  }) {
    return PasslyHeader(key: key, title: title, subtitle: subtitle);
  }

  /// QR 画面ヘッダー (Figma node 1528:4372)。
  ///
  /// 透明背景 (divider なし) + 左端に 30x30 X (閉じる) + 右端に 30x30 mage:qr-code
  /// (QR スキャン起動)。マイページの QR 画面のようにグラデーション背景の上に
  /// 重ねる用途を想定。
  factory PasslyHeader.qr({
    Key? key,
    required VoidCallback onClose,
    required VoidCallback onOpenScan,
  }) {
    return PasslyHeader(
      key: key,
      leading: _HeaderCloseButton(onTap: onClose),
      trailing: [_HeaderQrScanButton(onTap: onOpenScan)],
      showBottomDivider: false,
      backgroundColor: Colors.transparent,
    );
  }

  @override
  Widget build(BuildContext context) {
    // 白背景 + divider は SafeArea の外側 (DecoratedBox) に置く。
    // これで背景がステータスバー / Dynamic Island 領域まで完全に延びる。
    // SafeArea はコンテンツ (Row) の位置を top padding 分だけ押し下げる用途のみ。
    // 呼び出し側が SafeArea 内に置いていた場合は top padding が 0 になるだけ。
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: showBottomDivider
            ? const Border(
                bottom: BorderSide(color: AppColors.divider, width: 1),
              )
            : null,
      ),
      child: SafeArea(
        bottom: false,
        left: false,
        right: false,
        // Figma の 110 はステータスバー込みの高さ。SafeArea の内側なので、
        // ここではステータスバーを除いた中身の高さだけを取る。
        child: Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          alignment: Alignment.center,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 12)],
              Expanded(child: _buildCenter()),
              for (final w in trailing) ...[const SizedBox(width: 8), w],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCenter() {
    if (centerContent != null) return centerContent!;
    if (title == null && subtitle == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (title != null)
          Text(
            title!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              height: 28.8 / 24,
            ),
          ),
        if (title != null && subtitle != null) const SizedBox(height: 4),
        if (subtitle != null)
          Text(
            subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 16.8 / 14,
            ),
          ),
      ],
    );
  }
}

/// プロフィール系ヘッダーの戻るボタン（白い丸 + chevron 23.8）。
class PasslyBackButton extends StatelessWidget {
  final VoidCallback onTap;

  const PasslyBackButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PasslyCircleButton(
      asset: PasslyIcons.chevron,
      iconSize: 23.8,
      onTap: onTap,
    );
  }
}

/// 検索ヘッダー用の戻るボタン（白い丸 + chevron 23.8）。
class _SmallBackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _SmallBackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PasslyCircleButton(
      asset: PasslyIcons.chevron,
      iconSize: 23.8,
      onTap: onTap,
    );
  }
}

/// ホーム/カレンダーヘッダー右端の丸型アバター（40x40）。
class _HeaderAvatar extends StatelessWidget {
  final String? url;
  final VoidCallback? onTap;

  const _HeaderAvatar({required this.url, this.onTap});

  @override
  Widget build(BuildContext context) {
    Widget avatar = ClipOval(
      child: SizedBox(
        width: 40,
        height: 40,
        child: url != null
            ? SizedNetworkImage(
                url: url!,
                fallback: (_) => const _AvatarFallback(),
              )
            : const _AvatarFallback(),
      ),
    );
    if (onTap != null) {
      avatar = InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: avatar,
      );
    }
    return avatar;
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback();
  @override
  Widget build(BuildContext context) {
    return Container(
      color: PasslyBg.elevated,
      alignment: Alignment.center,
      child: const Icon(Icons.person, color: PasslyText.tertiary, size: 24),
    );
  }
}

/// カレンダーヘッダーの検索アイコン。40x40 のタップターゲット + 30px SVG。
class _HeaderSearchIcon extends StatelessWidget {
  final VoidCallback? onTap;

  const _HeaderSearchIcon({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: PressFeedback(
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
      ),
    );
  }
}

/// 自分プロフィールヘッダーの編集ペンボタン（白い丸 + ペン 24）。
class _HeaderEditButton extends StatelessWidget {
  final VoidCallback onTap;

  const _HeaderEditButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PasslyCircleButton(
      asset: PasslyIcons.edit,
      iconSize: 24,
      onTap: onTap,
    );
  }
}

/// QR 画面ヘッダー左端の閉じるボタン（白い丸 + X）。
class _HeaderCloseButton extends StatelessWidget {
  final VoidCallback onTap;

  const _HeaderCloseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PasslyCircleButton(
      asset: PasslyIcons.close,
      iconSize: 20,
      onTap: onTap,
    );
  }
}

/// QR 画面ヘッダー右端の QR スキャン起動ボタン（白い丸 + QR 20）。
class _HeaderQrScanButton extends StatelessWidget {
  final VoidCallback onTap;

  const _HeaderQrScanButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PasslyCircleButton(
      asset: PasslyIcons.qrCode,
      iconSize: 20,
      onTap: onTap,
    );
  }
}

/// 検索ヘッダー中央の検索フィールド (Figma node 1297:877)。
class _HeaderSearchField extends StatelessWidget {
  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;

  const _HeaderSearchField({
    required this.controller,
    required this.hintText,
    required this.onSubmitted,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Figma は 32 高 / 12.6px 文字だが、他のヘッダーボタンと同じタップサイズ
    // (40 高) + 読みやすいフォント (14px) に合わせて拡大。
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: PasslyBorder.divider,
        borderRadius: BorderRadius.circular(90),
        border: Border.all(color: PasslyBorder.strong, width: 0.9),
      ),
      child: Row(
        children: [
          const PasslyIcon(
            asset: PasslyIcons.search,
            size: 20,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              contextMenuBuilder: passlyContextMenuBuilder,
              controller: controller,
              onSubmitted: onSubmitted,
              onChanged: onChanged,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                height: 16.8 / 14,
              ),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                hintText: hintText,
                hintStyle: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
