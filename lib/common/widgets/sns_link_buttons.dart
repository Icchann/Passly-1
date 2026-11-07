import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:passly/common/widgets/passly_icon.dart';
import 'package:passly/core/constants/app_colors.dart';
import 'package:passly/core/constants/passly_tokens.dart';
import 'package:passly/features/user/domain/user_model.dart';

/// 名前のすぐ下に並べる SNS ボタン（マイページ・相手のプロフィール共通）。
///
/// - 1 行目：いちばん上の SNS（X → GitHub → connpass の順で最初にあるもの）を
///   黒い大きなボタン（ロゴ＋「でフォロー」「を見る」）にし，残りは右に丸いロゴで並べる。
///   1 つだけなら全幅になる。
/// - ポートフォリオはロゴがなく丸では何のリンクか分からないので，
///   下に「ポートフォリオ  ドメイン ↗」の横長ボタンを 1 本置く。
/// どれも設定されていなければ何も出さない。
class SnsLinkButtons extends StatelessWidget {
  final UserModel profile;

  const SnsLinkButtons({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final links = snsLinksOf(profile);
    if (links.isEmpty) return const SizedBox.shrink();
    final social = links.where((l) => l.kind != SnsKind.portfolio).toList();
    final portfolio = links.where((l) => l.kind == SnsKind.portfolio);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (social.isNotEmpty)
          Row(
            children: [
              Expanded(child: _MainSnsButton(link: social.first)),
              for (final link in social.skip(1)) ...[
                const SizedBox(width: 10),
                _RoundSnsButton(link: link),
              ],
            ],
          ),
        if (social.isNotEmpty && portfolio.isNotEmpty)
          const SizedBox(height: 10),
        if (portfolio.isNotEmpty) _PortfolioButton(link: portfolio.first),
      ],
    );
  }
}

enum SnsKind { x, github, connpass, portfolio }

/// SNS ボタン 1 つ分。
class SnsLink {
  final SnsKind kind;
  final String url;

  const SnsLink({required this.kind, required this.url});

  /// ロゴ（assets/sns/*.svg）。ポートフォリオはなし。
  String? get logoAsset => switch (kind) {
    SnsKind.x => 'assets/sns/x.svg',
    SnsKind.github => 'assets/sns/github.svg',
    SnsKind.connpass => 'assets/sns/connpass.svg',
    SnsKind.portfolio => null,
  };

  /// 大きいボタンのときにロゴの後ろに続ける言葉。
  String get action => kind == SnsKind.x ? 'でフォロー' : 'を見る';

  /// 読み上げ用の名前（丸ボタンは文字がないため）。
  String get semanticLabel => switch (kind) {
    SnsKind.x => 'Xでフォロー',
    SnsKind.github => 'GitHubを見る',
    SnsKind.connpass => 'connpassを見る',
    SnsKind.portfolio => 'ポートフォリオを見る',
  };

  /// connpass のロゴは元の色のまま出す（チケット形の赤）。
  bool get keepLogoColor => kind == SnsKind.connpass;
}

/// プロフィールに設定されている SNS を，ボタンに出す順で返す。
List<SnsLink> snsLinksOf(UserModel profile) => [
  if (profile.twitterUrl.isNotEmpty)
    SnsLink(kind: SnsKind.x, url: normalizeTwitterUrl(profile.twitterUrl)),
  if (profile.githubUrl.isNotEmpty)
    SnsLink(kind: SnsKind.github, url: normalizeGitHubUrl(profile.githubUrl)),
  if (profile.connpassUrl.isNotEmpty)
    SnsLink(
      kind: SnsKind.connpass,
      url: normalizeConnpassUrl(profile.connpassUrl),
    ),
  if (profile.portfolioUrl.isNotEmpty)
    SnsLink(
      kind: SnsKind.portfolio,
      url: normalizePortfolioUrl(profile.portfolioUrl),
    ),
];

const double _buttonHeight = 48;

Widget _logo(SnsLink link, Color color, double size) => SvgPicture.asset(
  link.logoAsset!,
  height: size,
  colorFilter: link.keepLogoColor
      ? null
      : ColorFilter.mode(color, BlendMode.srcIn),
);

/// 黒い大きなボタン：ロゴ＋「でフォロー」／「を見る」。
class _MainSnsButton extends StatelessWidget {
  final SnsLink link;

  const _MainSnsButton({required this.link});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: link.semanticLabel,
      excludeSemantics: true,
      child: Material(
        color: PasslyText.primary,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () => _launchUrl(link.url),
          child: SizedBox(
            height: _buttonHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _logo(link, Colors.white, link.keepLogoColor ? 16 : 20),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      link.action,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: PasslyFont.family,
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 白い丸のロゴボタン（2 つ目以降の SNS）。
class _RoundSnsButton extends StatelessWidget {
  final SnsLink link;

  const _RoundSnsButton({required this.link});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: link.semanticLabel,
      excludeSemantics: true,
      child: Material(
        color: PasslyBg.surface,
        shape: const CircleBorder(side: BorderSide(color: PasslyBorder.strong)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => _launchUrl(link.url),
          child: SizedBox.square(
            dimension: _buttonHeight,
            child: Center(
              child: _logo(
                link,
                AppColors.textPrimary,
                link.keepLogoColor ? 17 : 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 下に置く横長の「🔗 ポートフォリオ  example.com ↗」。
class _PortfolioButton extends StatelessWidget {
  final SnsLink link;

  const _PortfolioButton({required this.link});

  @override
  Widget build(BuildContext context) {
    final domain = portfolioDomainOf(link.url);
    return Semantics(
      button: true,
      label: link.semanticLabel,
      excludeSemantics: true,
      child: Material(
        color: PasslyBg.surface,
        shape: const StadiumBorder(
          side: BorderSide(color: PasslyBorder.strong),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () => _launchUrl(link.url),
          child: SizedBox(
            height: _buttonHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  const PasslyIcon(
                    asset: PasslyIcons.link,
                    size: 20,
                    color: AppColors.textPrimary,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'ポートフォリオ',
                    style: TextStyle(
                      fontFamily: PasslyFont.family,
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      domain,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontFamily: PasslyFont.family,
                        color: PasslyText.secondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.north_east,
                    size: 16,
                    color: PasslyText.secondary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _launchUrl(String url) async {
  if (url.isEmpty) return;
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

String normalizeTwitterUrl(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return '';
  if (value.startsWith('http://') || value.startsWith('https://')) return value;
  final handle = value.startsWith('@') ? value.substring(1) : value;
  return 'https://x.com/$handle';
}

String normalizeGitHubUrl(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return '';
  if (value.startsWith('http://') || value.startsWith('https://')) return value;
  if (value.startsWith('github.com/')) return 'https://$value';
  return 'https://github.com/$value';
}

String normalizeConnpassUrl(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return '';
  if (value.startsWith('http://') || value.startsWith('https://')) return value;
  final username = value.startsWith('@') ? value.substring(1) : value;
  return 'https://connpass.com/user/$username/';
}

/// ポートフォリオの URL。「example.com」のように https:// がなければ付ける。
String normalizePortfolioUrl(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return '';
  if (value.startsWith('http://') || value.startsWith('https://')) return value;
  return 'https://$value';
}

/// ボタンに出すドメイン（「https://www.example.com/works/」→「example.com/works」）。
String portfolioDomainOf(String url) {
  var v = url.trim().replaceFirst(RegExp(r'^https?://'), '');
  if (v.startsWith('www.')) v = v.substring(4);
  while (v.endsWith('/')) {
    v = v.substring(0, v.length - 1);
  }
  return v;
}
