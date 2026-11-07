import 'package:flutter/material.dart';
import 'package:passly/common/widgets/sized_network_image.dart';

import 'package:passly/common/widgets/passly_icon.dart';
import 'package:passly/common/widgets/press_feedback.dart';
import 'package:passly/common/widgets/tag_sticker.dart';
import 'package:passly/core/constants/passly_tokens.dart';

/// 共通タグ付きの「すれ違った人」1 件分のカード。
///
/// アバター + 名前（お気に入りなら黄色の★）+ 会ったイベント（任意）+
/// タグのステッカー（4 つまで + 「+N」，同じタグは緑のふち）+ 右向きシェブロン。
/// ホームの「ほかに共通点のある人」/ その日に出会った人 / 広場で使う。
class CommonTagPersonCard extends StatelessWidget {
  final String name;
  final String iconUrl;

  /// 名前の下に出す 1 行（例: "3月11日 SysHack2026"）。null なら出さない。
  final String? subtitle;

  /// 共通タグ。null は計算中、空は「共通タグなし」。
  final List<String>? commonTags;

  /// 相手のタグ全部。渡すと共通タグ以外のタグも並べる（広場の「すべて」）。
  /// null のときは共通タグだけを出す。
  final List<String>? allTags;

  final bool isFavorite;
  final VoidCallback? onTap;

  const CommonTagPersonCard({
    super.key,
    required this.name,
    required this.iconUrl,
    required this.commonTags,
    this.allTags,
    this.subtitle,
    this.isFavorite = false,
    this.onTap,
  });

  static const Color favoriteStar = Color(0xFFF5B400);

  @override
  Widget build(BuildContext context) {
    final tags = allTags ?? commonTags;
    final content = Container(
      constraints: const BoxConstraints(minHeight: 71),
      decoration: BoxDecoration(
        color: PasslyBg.surface,
        borderRadius: BorderRadius.circular(22.93),
        border: Border.all(color: PasslyBorder.divider, width: 0.99),
      ),
      padding: const EdgeInsets.fromLTRB(13, 10, 21.5, 10),
      child: Row(
        children: [
          _Avatar(url: iconUrl),
          const SizedBox(width: 18.82),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name.isEmpty ? '名前未設定' : name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: PasslyFont.family,
                          color: PasslyText.primary,
                          fontSize: 13.87,
                          fontWeight: PasslyFont.bold,
                          height: 19.015 / 13.87,
                        ),
                      ),
                    ),
                    if (isFavorite) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.star_rounded,
                        color: favoriteStar,
                        size: 18,
                      ),
                    ],
                  ],
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: PasslyFont.family,
                      color: PasslyText.secondary,
                      fontSize: 11,
                      fontWeight: PasslyFont.regular,
                      height: 1.3,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                if (tags == null)
                  const SizedBox(height: 30)
                else if (tags.isEmpty)
                  Text(
                    allTags == null ? '共通タグなし' : 'タグ未設定',
                    style: const TextStyle(
                      fontFamily: PasslyFont.family,
                      color: PasslyText.secondary,
                      fontSize: 11,
                      fontWeight: PasslyFont.regular,
                    ),
                  )
                else
                  TagStickerRow(tags: tags, common: commonTags ?? const []),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const PasslyIcon(
            asset: PasslyIcons.chevron,
            size: 23.77,
            color: PasslyText.secondary,
            flipHorizontal: true,
          ),
        ],
      ),
    );

    if (onTap == null) return content;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: PressFeedback(child: content),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String url;
  const _Avatar({required this.url});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox(
        width: 49.52,
        height: 49.52,
        child: url.isNotEmpty
            ? SizedNetworkImage(
                url: url,
                gaplessPlayback: true,
                fallback: (_) => const _AvatarFallback(),
              )
            : const _AvatarFallback(),
      ),
    );
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
