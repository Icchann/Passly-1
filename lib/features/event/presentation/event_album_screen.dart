import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:passly/common/widgets/loading_card_skeleton.dart';
import 'package:passly/common/widgets/passly_header.dart';
import 'package:passly/common/widgets/press_feedback.dart';
import 'package:passly/core/constants/passly_tokens.dart';
import 'package:passly/features/event/domain/event_album_notifier.dart';

/// イベント画面（旧カレンダー）。
///
/// Figma「① イベント 2列だけ」(node 2050:2143)。
/// イベントの日は一番上に「今日・すれ違い中」のカード（node 2050:2355）。
/// 上に「これから」のイベント、その下に参加したイベントを新しい順に 2 列で並べる。
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
              onRefresh: () => ref.refresh(eventAlbumProvider.future),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                children: album.when(
                  loading: () => const [LoadingCardsSkeleton()],
                  error: (e, _) => [const _Message(text: 'イベントの取得に失敗しました')],
                  data: (data) => [
                    if (data.today != null) ...[
                      _TodayCard(event: data.today!),
                      const SizedBox(height: 12),
                    ],
                    if (data.upcoming != null) ...[
                      _UpcomingCard(event: data.upcoming!),
                      const SizedBox(height: 20),
                    ],
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

const Color _upcomingAccent = Color(0xFFF59E0A);
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

class _UpcomingCard extends StatelessWidget {
  final EventSummary event;

  const _UpcomingCard({required this.event});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: PasslyBg.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: _cardShadow,
      ),
      child: Row(
        children: [
          Container(width: 6, color: _upcomingAccent),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'これから',
                  style: TextStyle(
                    fontFamily: PasslyFont.family,
                    fontSize: 11,
                    fontWeight: PasslyFont.bold,
                    color: _upcomingAccent,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${EventAlbumScreen.dateLabel(event.startAt)}${event.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: PasslyFont.family,
                    fontSize: 14,
                    fontWeight: PasslyFont.bold,
                    color: PasslyText.primary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.only(left: 8, right: 14),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3E2),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              '予定',
              style: TextStyle(
                fontFamily: PasslyFont.family,
                fontSize: 11,
                fontWeight: PasslyFont.bold,
                color: Color(0xFFB45309),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// イベント当日のカード（Figma node 2050:2355）。
/// 「今日・すれ違い中」と今日出会った人数を出す。押すとそのイベントへ。
class _TodayCard extends StatelessWidget {
  final EventSummary event;

  const _TodayCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final met = event.metUsers.length;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openEvent(context, event),
      child: PressFeedback(
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
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
                Container(width: 6, color: PasslyBrand.primary),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '今日・すれ違い中',
                          style: TextStyle(
                            fontFamily: PasslyFont.family,
                            fontSize: 11,
                            fontWeight: PasslyFont.bold,
                            color: PasslyBrand.primaryDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${EventAlbumScreen.dateLabel(event.startAt)}${event.name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: PasslyFont.family,
                            fontSize: 14,
                            fontWeight: PasslyFont.bold,
                            color: PasslyText.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(left: 8, right: 14),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _sameTagBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$met人と出会った',
                      style: const TextStyle(
                        fontFamily: PasslyFont.family,
                        fontSize: 11,
                        fontWeight: PasslyFont.bold,
                        color: _sameTagText,
                      ),
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
