import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:passly/core/constants/app_colors.dart';
import 'package:passly/core/constants/passly_tokens.dart';
import 'package:passly/features/user/domain/user_model.dart';

/// 名前のすぐ下に並べる SNS ボタン（マイページ・相手のプロフィール共通）。
///
/// X と GitHub は名前の代わりにロゴを出し，「でフォロー」「を見る」を続ける。
/// 2 列で並べ，先頭だけ黒塗り，ほかは白地に枠線。
/// どれも設定されていなければ何も出さない。
class SnsLinkButtons extends StatelessWidget {
  final UserModel profile;

  const SnsLinkButtons({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final links = snsLinksOf(profile);
    if (links.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        final width = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (int i = 0; i < links.length; i++)
              SizedBox(
                width: width,
                child: _SnsButton(link: links[i], primary: i == 0),
              ),
          ],
        );
      },
    );
  }
}

/// SNS ボタン 1 つ分。
class SnsLink {
  /// ロゴ（assets/sns/*.svg）。なければ文字だけ。
  final String? logoAsset;
  final String label;
  final String url;

  const SnsLink({this.logoAsset, required this.label, required this.url});
}

/// プロフィールに設定されている SNS を，ボタンに出す順で返す。
List<SnsLink> snsLinksOf(UserModel profile) => [
  if (profile.twitterUrl.isNotEmpty)
    SnsLink(
      logoAsset: 'assets/sns/x.svg',
      label: 'でフォロー',
      url: normalizeTwitterUrl(profile.twitterUrl),
    ),
  if (profile.githubUrl.isNotEmpty)
    SnsLink(
      logoAsset: 'assets/sns/github.svg',
      label: 'を見る',
      url: normalizeGitHubUrl(profile.githubUrl),
    ),
  if (profile.portfolioUrl.isNotEmpty)
    SnsLink(label: 'ポートフォリオ', url: profile.portfolioUrl),
  if (profile.connpassUrl.isNotEmpty)
    SnsLink(
      label: 'connpass を見る',
      url: normalizeConnpassUrl(profile.connpassUrl),
    ),
];

class _SnsButton extends StatelessWidget {
  final SnsLink link;
  final bool primary;

  const _SnsButton({required this.link, required this.primary});

  @override
  Widget build(BuildContext context) {
    final color = primary ? Colors.white : AppColors.textPrimary;
    return Material(
      color: primary ? PasslyText.primary : PasslyBg.surface,
      shape: StadiumBorder(
        side: primary
            ? BorderSide.none
            : const BorderSide(color: PasslyBorder.strong),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () => _launchUrl(link.url),
        child: SizedBox(
          height: 48,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (link.logoAsset != null) ...[
                  SvgPicture.asset(
                    link.logoAsset!,
                    width: 20,
                    height: 20,
                    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                  ),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    link.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: PasslyFont.family,
                      color: color,
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
