import 'package:flutter/material.dart';
import 'package:passly/common/widgets/sized_network_image.dart';
import 'package:passly/common/widgets/loading_card_skeleton.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:passly/common/widgets/passly_header.dart';
import 'package:passly/core/constants/app_colors.dart';

/// 「その日に出会った人一覧」「親しい友達一覧」など、
/// 同じレイアウトでデータソースだけ違う人物リスト画面のための共通ウィジェット。
///
/// Figma node 1300:1158 の構造に準拠：
/// - ヘッダー（タイトル + サブタイトル）
/// - セクション見出し（対象名 + 件数）
/// - スクロール可能なカードリスト（アバター + 名前 + 時刻 + イベント + chevron）
class PersonListView extends StatelessWidget {
  final String headerTitle;
  final String headerSubtitle;
  final String sectionTitle;
  final String sectionSubtitle;
  final AsyncValue<List<PersonListItem>> itemsAsync;
  final void Function(String userId) onItemTap;
  final String emptyMessage;

  const PersonListView({
    super.key,
    required this.headerTitle,
    required this.headerSubtitle,
    required this.sectionTitle,
    required this.sectionSubtitle,
    required this.itemsAsync,
    required this.onItemTap,
    this.emptyMessage = '該当する人はいません',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundGrey,
      // PasslyHeader 自身が SafeArea を処理するため wrap しない (背景を上端まで延ばす)。
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PasslyHeader(
            leading: PasslyBackButton(
              onTap: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              },
            ),
            title: headerTitle,
            subtitle: headerSubtitle,
          ),
          Expanded(
            child: itemsAsync.when(
              data: (items) => _buildList(items),
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: LoadingCardsSkeleton(),
              ),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'データの取得に失敗しました\n$error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<PersonListItem> items) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(15, 12, 15, 24),
      itemCount: items.length + 1, // +1 for section header
      separatorBuilder: (context, index) {
        // header と最初のアイテムの間だけ 12px、それ以外は 4px
        if (index == 0) return const SizedBox(height: 12);
        return const SizedBox(height: 4);
      },
      itemBuilder: (context, index) {
        if (index == 0) {
          return _SectionHeading(
            title: sectionTitle,
            subtitle: sectionSubtitle,
          );
        }
        final itemIndex = index - 1;
        if (items.isEmpty) {
          // items.length + 1 で index >= 1 は絶対来ないが型のため
          return const SizedBox.shrink();
        }
        final item = items[itemIndex];
        return _PersonCard(item: item, onTap: () => onItemTap(item.userId));
      },
    ).let((child) {
      // items が空の場合は emptyMessage を出す
      if (items.isEmpty) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 12, 15, 12),
              child: _SectionHeading(
                title: sectionTitle,
                subtitle: sectionSubtitle,
              ),
            ),
            Expanded(
              child: Center(
                child: Text(
                  emptyMessage,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        );
      }
      return child;
    });
  }
}

/// リストの 1 件分のデータ。
class PersonListItem {
  final String userId;
  final String name;
  final String iconUrl;
  final String? timeLabel;
  final String? eventLabel;

  const PersonListItem({
    required this.userId,
    required this.name,
    this.iconUrl = '',
    this.timeLabel,
    this.eventLabel,
  });
}

/// セクション見出し（「3月11日の出会い / 3人と出会いました」）
class _SectionHeading extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeading({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
      ],
    );
  }
}

/// リストカード 1 件
class _PersonCard extends StatelessWidget {
  final PersonListItem item;
  final VoidCallback onTap;

  const _PersonCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.backgroundWhite,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.divider, width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          child: Row(
            children: [
              _Avatar(iconUrl: item.iconUrl),
              const SizedBox(width: 19),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name.isEmpty ? '名前未設定' : item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 19 / 14,
                      ),
                    ),
                    if (item.timeLabel != null || item.eventLabel != null) ...[
                      const SizedBox(height: 6),
                      _SubtitleRow(
                        timeLabel: item.timeLabel,
                        eventLabel: item.eventLabel,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textSecondary,
                size: 24,
              ),
            ],
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
      width: 50,
      height: 50,
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
    return const Icon(Icons.person, color: AppColors.textLight, size: 28);
  }
}

class _SubtitleRow extends StatelessWidget {
  final String? timeLabel;
  final String? eventLabel;

  const _SubtitleRow({this.timeLabel, this.eventLabel});

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (timeLabel != null && timeLabel!.isNotEmpty) timeLabel!,
      if (eventLabel != null && eventLabel!.isNotEmpty) eventLabel!,
    ];
    if (parts.isEmpty) return const SizedBox.shrink();

    return Text(
      parts.join('    '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 14.3 / 12,
      ),
    );
  }
}

/// ListView に対して分岐で別 Widget を返すための小さな拡張。
extension _WidgetLet<T extends Widget> on T {
  Widget let(Widget Function(T self) transform) => transform(this);
}
