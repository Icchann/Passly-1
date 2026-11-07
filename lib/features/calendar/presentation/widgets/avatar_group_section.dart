import 'package:flutter/material.dart';
import 'package:passly/common/widgets/sized_network_image.dart';

import 'package:passly/core/constants/app_colors.dart';

/// 「この日に出会った人」「親しい友達」共通のアバター横並びセクション。
///
/// 上位 6 人のアバターを表示し、7 人目以降がある場合は「+N」の丸を末尾に出す。
/// 全体タップで一覧画面へ遷移する想定（onTap で親から遷移を渡す）。
class AvatarGroupSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<AvatarItem> items;
  final int totalCount;
  final VoidCallback onTap;

  const AvatarGroupSection({
    super.key,
    required this.title,
    required this.subtitle,
    required this.items,
    required this.totalCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // 最大 6 個まで表示、残りは「+N」で示す
    final displayItems = items.take(6).toList();
    final overflow = totalCount - displayItems.length;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.divider, width: 1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  height: 19.2 / 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 16.8 / 14,
                ),
              ),
              const SizedBox(height: 8),
              _AvatarRow(items: displayItems, overflow: overflow),
            ],
          ),
        ),
      ),
    );
  }
}

class AvatarItem {
  final String userId;
  final String iconUrl;

  const AvatarItem({required this.userId, this.iconUrl = ''});
}

class _AvatarRow extends StatelessWidget {
  final List<AvatarItem> items;
  final int overflow;

  const _AvatarRow({required this.items, required this.overflow});

  // 6 avatars + overflow chip を w=382 に space-between で並べたときのアイテム間
  // ギャップ (382 - 7*45) / 6 ≒ 11px。左詰め時もこの値に揃える。
  static const double _gap = 11;

  @override
  Widget build(BuildContext context) {
    final slots = <Widget>[
      for (final item in items) _Avatar(iconUrl: item.iconUrl),
      if (overflow > 0) _OverflowBadge(count: overflow),
    ];

    if (slots.isEmpty) {
      return const SizedBox(height: 45);
    }

    // オーバーフローあり = 7 スロット詰まる → Figma 準拠で space-between。
    // オーバーフローなし (6 人以下) = 左詰めで固定ギャップ。
    if (overflow > 0) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: slots,
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        for (int i = 0; i < slots.length; i++) ...[
          if (i > 0) const SizedBox(width: _gap),
          slots[i],
        ],
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  final String iconUrl;

  const _Avatar({required this.iconUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 45,
      height: 45,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.backgroundGrey,
      ),
      child: ClipOval(
        child: iconUrl.isNotEmpty
            ? SizedNetworkImage(url: iconUrl, fallback: (_) => _fallback())
            : _fallback(),
      ),
    );
  }

  Widget _fallback() {
    return const Icon(Icons.person, color: AppColors.textLight, size: 24);
  }
}

class _OverflowBadge extends StatelessWidget {
  final int count;

  const _OverflowBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 45,
      height: 45,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.divider,
      ),
      alignment: Alignment.center,
      child: Text(
        '+$count',
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          height: 13 / 11,
        ),
      ),
    );
  }
}
