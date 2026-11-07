import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:passly/common/widgets/loading_card_skeleton.dart';
import 'package:passly/common/widgets/passly_header.dart';
import 'package:passly/common/widgets/press_feedback.dart';
import 'package:passly/core/constants/passly_tokens.dart';
import 'package:passly/core/utils/app_time.dart';
import 'package:passly/features/event/domain/event_album_notifier.dart';
import 'package:passly/features/event/domain/favorite_next_events.dart';
import 'package:passly/features/user/domain/user_model.dart';

/// イベント画面（旧カレンダー）。
///
/// 上の「これから」に，今日のイベント（参加中）・自分が参加予定のイベント・
/// お気に入りの人が参加予定のイベントを並べる（Figma 2086:2285「案A＋C」）。
/// 参加中は緑の帯，自分の予定はオレンジの帯，お気に入りの人の予定は点線の枠。
/// どのカードも押すとイベントのページを開く。
/// その下に参加したイベントを新しい順に 2 列で並べる（node 2050:2143）。
/// カードを押すとそのイベントで出会った人の一覧へ。
class EventAlbumScreen extends ConsumerWidget {
  const EventAlbumScreen({super.key});

  static const List<String> _weekdays = ['月', '火', '水', '木', '金', '土', '日'];

  static String dateLabel(DateTime d) =>
      '${d.month}/${d.day}（${_weekdays[d.weekday - 1]}）';

  Future<void> _openSearch(BuildContext context) async {
    final selected = await context.push<DateTime>('/events/search');
    if (selected == null || !context.mounted) return;
    context.push('/encounters/day/${eventDateParam(selected)}');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final album = ref.watch(eventAlbumProvider);

    return Scaffold(
      backgroundColor: PasslyBg.defaultBg,
      body: Column(
        children: [
          PasslyHeader.calendar(
            title: 'イベント',
            onSearchTap: () => _openSearch(context),
          ),
          Expanded(
            child: RefreshIndicator(
              color: PasslyBrand.primary,
              onRefresh: () {
                ref.invalidate(favoriteNextEventsProvider);
                return ref.refresh(eventAlbumProvider.future);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                children: album.when(
                  loading: () => const [LoadingCardsSkeleton()],
                  error: (e, _) => [const _Message(text: 'イベントの取得に失敗しました')],
                  data: (data) => [
                    _ComingSection(album: data),
                    const _SectionTitle('参加したイベント'),
                    const SizedBox(height: 12),
                    if (data.past.isEmpty)
                      const _Message(text: 'まだ参加したイベントはありません')
                    else
                      _EventGrid(events: data.past),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// イベント詳細へ。ID がなければその日に出会った人の一覧へ。
void _openEvent(BuildContext context, EventSummary e) => e.id != null
    ? context.push('/events/${e.id}')
    : context.push('/encounters/day/${eventDateParam(e.day)}');

const Color _sameTagBg = Color(0xFFE8F5E8);
const Color _sameTagText = Color(0xFF1F7A1F);

final List<BoxShadow> _cardShadow = [
  BoxShadow(
    color: Colors.black.withValues(alpha: 0.05),
    blurRadius: 8,
    offset: const Offset(0, 2),
  ),
];

/// 画像がないイベントに使うグラデーション（Figma の仮画像の色）。
const List<List<Color>> _fallbackGradients = [
  [Color(0xFF7BD389), Color(0xFF2E9E5B)],
  [Color(0xFFFFB86B), Color(0xFFF2668B)],
  [Color(0xFF9CC9F5), Color(0xFF5B8DEF)],
  [Color(0xFFC4B5FD), Color(0xFF7C3AED)],
  [Color(0xFFFDE68A), Color(0xFFF59E0B)],
  [Color(0xFFA7F3D0), Color(0xFF0EA5A4)],
];

/// 「これから」のカードの種類。色と右上のラベルで見分ける（Figma 2086:2285）。
enum _ComingKind {
  /// 今日のイベント（参加中）。緑の帯。
  now,

  /// 自分が参加予定のイベント。オレンジの帯。
  mine,

  /// お気に入りの人が参加予定で，自分はまだのイベント。点線の枠。
  favorite,
}

class _ComingItem {
  final _ComingKind kind;
  final String title;

  /// 開始日時（日本時間）。
  final DateTime startAt;
  final String url;
  final EventSummary? event;

  /// このイベントに参加予定のお気に入りの人。
  final List<UserModel> favorites;

  const _ComingItem({
    required this.kind,
    required this.title,
    required this.startAt,
    this.url = '',
    this.event,
    this.favorites = const [],
  });
}

/// 「これから」に並べるものを作る。参加中を先頭に，あとは日付の早い順。
/// お気に入りの人の予定が自分の予定と同じイベントなら，自分の予定のカードにまとめる。
List<_ComingItem> _comingItems(
  EventAlbum album,
  List<FavoriteNextEvent> favorites,
) {
  bool same(FavoriteNextEvent f, EventSummary e) {
    if (f.event.url.isNotEmpty && f.event.url == e.url) return true;
    final d = AppTime.toAppLocal(f.event.startedAt);
    return f.event.title.trim() == e.name.trim() &&
        DateTime(d.year, d.month, d.day) == e.day;
  }

  List<UserModel> favoritesOf(EventSummary e) => [
    for (final f in favorites)
      if (same(f, e)) ...f.users,
  ];

  final mine = [if (album.today != null) album.today!, ...album.upcoming];
  final rest = <_ComingItem>[
    for (final e in album.upcoming)
      _ComingItem(
        kind: _ComingKind.mine,
        title: e.name,
        startAt: e.startAt,
        url: e.url,
        event: e,
        favorites: favoritesOf(e),
      ),
    for (final f in favorites)
      if (!mine.any((e) => same(f, e)))
        _ComingItem(
          kind: _ComingKind.favorite,
          title: f.event.title,
          startAt: AppTime.toAppLocal(f.event.startedAt),
          url: f.event.url,
          favorites: f.users,
        ),
  ]..sort((a, b) => a.startAt.compareTo(b.startAt));
  return [
    if (album.today != null)
      _ComingItem(
        kind: _ComingKind.now,
        title: album.today!.name,
        startAt: album.today!.startAt,
        url: album.today!.url,
        event: album.today,
        favorites: favoritesOf(album.today!),
      ),
    ...rest,
  ];
}

/// 「これから」の見出しとカード。何もなければ出さない。
class _ComingSection extends ConsumerWidget {
  final EventAlbum album;

  const _ComingSection({required this.album});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites =
        ref.watch(favoriteNextEventsProvider).asData?.value ?? const [];
    final items = _comingItems(album, favorites);
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionTitle('これから'),
          const SizedBox(height: 10),
          for (final (i, item) in items.indexed) ...[
            if (i > 0) const SizedBox(height: 10),
            _ComingCard(item: item),
          ],
        ],
      ),
    );
  }
}

const Color _nowColor = PasslyBrand.primary;
const Color _nowText = Color(0xFF2E7D32);
const Color _mineColor = Color(0xFFF59E0A);
const Color _mineText = Color(0xFFB45309);
const Color _mineBadgeBg = Color(0xFFFEF3E2);
const Color _favoriteChipBg = Color(0xFFFEF3C7);
const Color _favoriteChipText = Color(0xFF92400E);
const Color _star = Color(0xFFF5B400);

class _ComingCard extends StatelessWidget {
  final _ComingItem item;

  const _ComingCard({required this.item});

  static const List<String> _weekdays = ['月', '火', '水', '木', '金', '土', '日'];

  String get _dateText {
    final d = item.startAt;
    final date = '${d.month}/${d.day}（${_weekdays[d.weekday - 1]}）';
    if (item.kind != _ComingKind.now) return date;
    final time = '${d.hour}:${d.minute.toString().padLeft(2, '0')}〜';
    return '$date$time';
  }

  void _open(BuildContext context) {
    if (item.url.isNotEmpty) {
      _openUrl(item.url);
    } else if (item.event != null) {
      _openEvent(context, item.event!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final kind = item.kind;
    final isFavorite = kind == _ComingKind.favorite;
    final dateColor = switch (kind) {
      _ComingKind.now => _nowText,
      _ComingKind.mine => _mineText,
      _ComingKind.favorite => PasslyText.secondary,
    };
    final content = Padding(
      padding: EdgeInsets.fromLTRB(isFavorite ? 16 : 14, 11, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isFavorite) ...[
                const _SmallLabel(
                  text: '★ お気に入り',
                  color: _favoriteChipText,
                  background: _favoriteChipBg,
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  _dateText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: PasslyFont.family,
                    fontSize: 11,
                    fontWeight: PasslyFont.bold,
                    color: dateColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _StatusBadge(kind: kind),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: PasslyFont.family,
              fontSize: 15,
              fontWeight: PasslyFont.bold,
              color: PasslyText.primary,
            ),
          ),
          if (_whoText() case final who?) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                _AvatarStack(users: _whoAvatars(), max: 3, size: 18, step: 12),
                const SizedBox(width: 6),
                if (item.favorites.isNotEmpty) ...[
                  const Icon(Icons.star_rounded, size: 14, color: _star),
                  const SizedBox(width: 2),
                ],
                Expanded(
                  child: Text(
                    who,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: PasslyFont.family,
                      fontSize: 11,
                      fontWeight: PasslyFont.medium,
                      color: PasslyText.secondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );

    final Widget card;
    if (isFavorite) {
      card = CustomPaint(
        painter: const _DashedBorderPainter(
          color: Color(0xFFD1D5DB),
          radius: 14,
        ),
        child: content,
      );
    } else {
      card = Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: PasslyBg.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: _cardShadow,
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 6,
                color: kind == _ComingKind.now ? _nowColor : _mineColor,
              ),
              Expanded(child: content),
            ],
          ),
        ),
      );
    }

    final canOpen = item.url.isNotEmpty || item.event != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: canOpen ? () => _open(context) : null,
      child: PressFeedback(child: card),
    );
  }

  /// 参加中は出会った人数，ほかは参加予定のお気に入りの人。
  String? _whoText() {
    if (item.kind == _ComingKind.now && item.favorites.isEmpty) {
      return '${item.event?.metUsers.length ?? 0}人と出会った';
    }
    if (item.favorites.isEmpty) return null;
    final names = item.favorites
        .map((u) => '${u.name.isEmpty ? '名前未設定' : u.name}さん')
        .join('，');
    return '$namesが参加予定';
  }

  List<EventMetUser> _whoAvatars() {
    if (item.kind == _ComingKind.now && item.favorites.isEmpty) {
      return item.event?.metUsers ?? const [];
    }
    return [
      for (final u in item.favorites)
        EventMetUser(id: u.id, iconUrl: u.iconUrl),
    ];
  }
}

/// 右上のラベル（参加中／参加予定／参加してみる）。
class _StatusBadge extends StatelessWidget {
  final _ComingKind kind;

  const _StatusBadge({required this.kind});

  @override
  Widget build(BuildContext context) {
    final (text, fg, bg, outline) = switch (kind) {
      _ComingKind.now => ('参加中', Colors.white, _nowColor, null),
      _ComingKind.mine => ('参加予定', _mineText, _mineBadgeBg, null),
      _ComingKind.favorite => ('参加してみる', _nowText, null, _nowColor),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: outline == null ? null : Border.all(color: outline),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: PasslyFont.family,
          fontSize: 11,
          fontWeight: PasslyFont.bold,
          color: fg,
        ),
      ),
    );
  }
}

class _SmallLabel extends StatelessWidget {
  final String text;
  final Color color;
  final Color background;

  const _SmallLabel({
    required this.text,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: PasslyFont.family,
          fontSize: 10,
          fontWeight: PasslyFont.bold,
          color: color,
        ),
      ),
    );
  }
}

/// 点線の角丸の枠（お気に入りの人の予定のカード）。
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;

  const _DashedBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    ).deflate(0.75);
    canvas.drawRRect(rrect, Paint()..color = PasslyBg.surface);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      for (double d = 0; d < metric.length; d += 9) {
        canvas.drawPath(metric.extractPath(d, d + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

Future<void> _openUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: PasslyFont.family,
        fontSize: 15,
        fontWeight: PasslyFont.bold,
        color: PasslyText.primary,
      ),
    );
  }
}

/// イベントの画像。なければグラデーション。
class _EventImage extends StatelessWidget {
  final EventSummary event;
  final int index;
  final double height;

  const _EventImage({
    required this.event,
    required this.index,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _fallbackGradients[index % _fallbackGradients.length];
    final fallback = DecoratedBox(
      decoration: BoxDecoration(gradient: LinearGradient(colors: colors)),
    );
    return SizedBox(
      height: height,
      width: double.infinity,
      child: event.imageUrl.isEmpty
          ? fallback
          : Image.network(
              event.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback,
            ),
    );
  }
}

/// 出会った人のアイコンを重ねて並べる。
class _AvatarStack extends StatelessWidget {
  final List<EventMetUser> users;
  final int max;
  final double size;
  final double step;

  const _AvatarStack({
    required this.users,
    required this.max,
    required this.size,
    required this.step,
  });

  @override
  Widget build(BuildContext context) {
    final shown = users.take(max).toList();
    if (shown.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      width: size + step * (shown.length - 1),
      height: size,
      child: Stack(
        children: [
          for (final (i, u) in shown.indexed)
            Positioned(
              left: step * i,
              child: _Avatar(url: u.iconUrl, size: size),
            ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String url;
  final double size;

  const _Avatar({required this.url, required this.size});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: PasslyBg.elevated,
      alignment: Alignment.center,
      child: Icon(Icons.person, size: size * 0.6, color: PasslyText.tertiary),
    );
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: PasslyBg.surface, width: 2),
      ),
      child: ClipOval(
        child: url.isEmpty
            ? fallback
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              ),
      ),
    );
  }
}

class _SameTagChip extends StatelessWidget {
  final int count;
  final double fontSize;

  const _SameTagChip({required this.count, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _sameTagBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '共通タグ $count人',
        style: TextStyle(
          fontFamily: PasslyFont.family,
          fontSize: fontSize,
          fontWeight: PasslyFont.bold,
          color: _sameTagText,
        ),
      ),
    );
  }
}

/// 参加したイベントの 2 列表示。
class _EventGrid extends StatelessWidget {
  final List<EventSummary> events;

  const _EventGrid({required this.events});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        final width = (constraints.maxWidth - gap) / 2;
        // 高さは固定せず中身に合わせる（文字サイズを大きくしてもはみ出さない）
        return Column(
          children: [
            for (var i = 0; i < events.length; i += 2) ...[
              if (i > 0) const SizedBox(height: gap),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: width,
                    child: _SmallEventCard(event: events[i], index: i),
                  ),
                  const SizedBox(width: gap),
                  SizedBox(
                    width: width,
                    child: i + 1 < events.length
                        ? _SmallEventCard(event: events[i + 1], index: i + 1)
                        : null,
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

class _SmallEventCard extends StatelessWidget {
  final EventSummary event;
  final int index;

  const _SmallEventCard({required this.event, required this.index});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openEvent(context, event),
      child: PressFeedback(
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: PasslyBg.surface,
            borderRadius: BorderRadius.circular(14),
            boxShadow: _cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _EventImage(event: event, index: index, height: 96),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: PasslyFont.family,
                        fontSize: 13,
                        fontWeight: PasslyFont.bold,
                        color: PasslyText.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      EventAlbumScreen.dateLabel(event.startAt),
                      style: const TextStyle(
                        fontFamily: PasslyFont.family,
                        fontSize: 11,
                        color: PasslyText.secondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _AvatarStack(
                          users: event.metUsers,
                          max: 3,
                          size: 22,
                          step: 15,
                        ),
                        if (event.metUsers.isNotEmpty) const SizedBox(width: 6),
                        Text(
                          '${event.metUsers.length}人',
                          style: const TextStyle(
                            fontFamily: PasslyFont.family,
                            fontSize: 11,
                            fontWeight: PasslyFont.medium,
                            color: PasslyText.secondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (event.sameTagCount > 0)
                      _SameTagChip(count: event.sameTagCount, fontSize: 10)
                    else
                      const Text(
                        '共通タグの人なし',
                        style: TextStyle(
                          fontFamily: PasslyFont.family,
                          fontSize: 10,
                          color: PasslyText.tertiary,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final String text;

  const _Message({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            fontFamily: PasslyFont.family,
            fontSize: 13,
            color: PasslyText.secondary,
          ),
        ),
      ),
    );
  }
}
