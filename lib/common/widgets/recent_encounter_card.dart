import 'package:flutter/material.dart';
import 'package:passly/common/widgets/sized_network_image.dart';

import 'package:passly/common/widgets/passly_icon.dart';
import 'package:passly/common/widgets/press_feedback.dart';
import 'package:passly/core/constants/app_colors.dart';
import 'package:passly/core/constants/passly_tokens.dart';

/// Figma node 1093:1455 「最近すれ違った人」1 件分のカード。
///
/// 382x71 白背景、divider 境界、丸型アバター + 名前 + (時刻 / 場所) + 右端に
/// 右向きシェブロン。タップで詳細プロフィールへ遷移する想定。
class RecentEncounterCard extends StatelessWidget {
  final String? avatarUrl;
  final String name;

  /// 時刻表示 (例: "18:22")。
  final String time;

  /// 場所表示 (例: "SysHack2026")。
  final String location;

  /// 所属表示 (例: "◯◯大学 / ◯◯サークル")。
  ///
  /// 空でない場合は [time]/[location] の代わりに名前の下に 1 行で表示される。
  /// 「親しい人」など時刻/場所より所属を出したいカードで指定する。
  final String affiliation;

  final VoidCallback? onTap;

  const RecentEncounterCard({
    super.key,
    required this.avatarUrl,
    required this.name,
    required this.time,
    required this.location,
    this.affiliation = '',
    this.onTap,
  });

  static const double _height = 71;
  static const double _radius = 22.93;
  static const double _avatarSize = 49.52;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      height: _height,
      decoration: BoxDecoration(
        color: PasslyBg.surface,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: PasslyBorder.divider, width: 0.99),
      ),
      padding: const EdgeInsets.only(
        left: 12.88,
        right: 21.5,
        top: 8.42,
        bottom: 8.42,
      ),
      child: Row(
        children: [
          _Avatar(url: avatarUrl),
          const SizedBox(width: 18.82),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: PasslyFont.family,
                    color: AppColors.textPrimary,
                    fontSize: 13.87,
                    fontWeight: PasslyFont.bold,
                    height: 19.015 / 13.87,
                  ),
                ),
                const SizedBox(height: 7.92),
                if (affiliation.isNotEmpty)
                  Text(
                    affiliation,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: PasslyFont.family,
                      color: PasslyText.secondary,
                      fontSize: 11.88,
                      fontWeight: PasslyFont.regular,
                      height: 14.26 / 11.88,
                    ),
                  )
                else
                  Row(
                    children: [
                      Text(
                        time,
                        style: const TextStyle(
                          fontFamily: PasslyFont.family,
                          color: PasslyText.secondary,
                          fontSize: 11.88,
                          fontWeight: PasslyFont.regular,
                          height: 14.26 / 11.88,
                        ),
                      ),
                      const SizedBox(width: 19.81),
                      Flexible(
                        child: Text(
                          location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: PasslyFont.family,
                            color: PasslyText.secondary,
                            fontSize: 11.88,
                            fontWeight: PasslyFont.regular,
                            height: 14.26 / 11.88,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
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
  final String? url;
  const _Avatar({required this.url});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox(
        width: RecentEncounterCard._avatarSize,
        height: RecentEncounterCard._avatarSize,
        child: url != null
            ? SizedNetworkImage(
                url: url!,
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

/// Figma node 1300:1005 「当日の出会い一覧」セクション。
///
/// タイトル + サブタイトル + [RecentEncounterCard] のリストを縦に並べる。
/// タイトル/サブタイトル文言は任意なので「3月11日の出会い」「最近すれ違った人」
/// など呼び出し側で自由に指定できる。
class RecentEncounterList extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<RecentEncounterCard> children;

  const RecentEncounterList({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: PasslyFont.family,
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                height: 19.2 / 16,
              ),
            ),
            const SizedBox(height: PasslySpace.s8),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: PasslyFont.family,
                color: PasslyText.secondary,
                fontSize: 14,
                fontWeight: PasslyFont.medium,
                height: 16.8 / 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: PasslySpace.s12),
        for (int i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: PasslySpace.s4),
          children[i],
        ],
      ],
    );
  }
}
