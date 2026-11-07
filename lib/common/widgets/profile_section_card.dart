import 'package:flutter/material.dart';

import 'package:passly/core/constants/app_colors.dart';
import 'package:passly/core/constants/passly_tokens.dart';

/// プロフィールの項目（自己紹介・タグなど）を入れる白いカード。
/// マイページと相手のプロフィールで同じ見た目にする。
class ProfileSectionCard extends StatelessWidget {
  final String title;

  /// 見出しの右に出す小さい緑の文字（「あなたと同じタグが2つ」など）。
  final String? note;
  final Widget child;

  const ProfileSectionCard({
    super.key,
    required this.title,
    this.note,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(17, 16, 17, 18),
      decoration: BoxDecoration(
        color: PasslyBg.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PasslyBorder.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 10,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: PasslyFont.family,
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  height: 19.2 / 16,
                ),
              ),
              if (note != null)
                Text(
                  note!,
                  style: const TextStyle(
                    fontFamily: PasslyFont.family,
                    color: PasslyBrand.primaryDark,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
