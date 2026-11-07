import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:passly/common/widgets/loading_card_skeleton.dart';
import 'package:go_router/go_router.dart';

import 'package:passly/common/widgets/passly_header.dart';
import 'package:passly/core/constants/app_colors.dart';
import 'package:passly/features/calendar/presentation/widgets/day_event_card.dart';
import 'package:passly/features/event/domain/event_album_notifier.dart';

/// イベント検索画面。
///
/// - 上部: 戻るボタン + 検索フィールド（プレースホルダ「イベント名を入力」）
/// - 本体: 「関連イベント」見出し + フィルタ済みイベントリスト
/// - タップ時: そのイベントを `context.pop<EventSummary>(event)` で呼び出し元へ返す
///
/// 探す対象はイベント画面と同じ「自分の connpass の参加イベント」
/// （[eventAlbumProvider]）。サーバー全体のイベント（GET /events）は
/// 自分と関係ないものや仮のデータが混ざるので使わない。
/// フィルタは name への部分一致（大文字小文字無視）でクライアント側完結。
/// 入力のたびに再フェッチはしない。
class EventSearchScreen extends ConsumerStatefulWidget {
  const EventSearchScreen({super.key});

  @override
  ConsumerState<EventSearchScreen> createState() => _EventSearchScreenState();
}

class _EventSearchScreenState extends ConsumerState<EventSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final next = _controller.text.trim();
      if (next != _query) {
        setState(() => _query = next);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref
        .watch(eventAlbumProvider)
        .whenData(
          (album) => [
            if (album.today != null) album.today!,
            ...album.upcoming,
            ...album.past,
          ],
        );

    return Scaffold(
      backgroundColor: AppColors.backgroundGrey,
      // PasslyHeader 自身が SafeArea を処理するため wrap しない (背景を上端まで延ばす)。
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PasslyHeader.search(
            onBack: () {
              if (context.canPop()) context.pop();
            },
            controller: _controller,
            hintText: 'イベント名を入力',
          ),
          Expanded(
            child: eventsAsync.when(
              data: (events) => _buildResults(_filter(events)),
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: LoadingEventCardsSkeleton(),
              ),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'イベントの取得に失敗しました\n$error',
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

  List<EventSummary> _filter(List<EventSummary> events) {
    if (_query.isEmpty) return events;
    final q = _query.toLowerCase();
    return events.where((e) => e.name.toLowerCase().contains(q)).toList();
  }

  Widget _buildResults(List<EventSummary> events) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(15, 24, 15, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'あなたのイベント',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              height: 24 / 20,
            ),
          ),
          const SizedBox(height: 12),
          if (events.isEmpty)
            const _EmptyState()
          else
            ...events.map(
              (event) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: _ResultCard(event: event),
              ),
            ),
        ],
      ),
    );
  }
}

/// 検索結果カード。`DayEventCard` を薄くラップして pop 動作を追加。
class _ResultCard extends StatelessWidget {
  final EventSummary event;

  const _ResultCard({required this.event});

  @override
  Widget build(BuildContext context) {
    return DayEventCard(
      eventName: event.name,
      imageUrl: event.imageUrl.isEmpty ? null : event.imageUrl,
      date: event.startAt,
      location: event.location,
      participantCount: event.metUsers.length,
      onTap: () => context.pop<EventSummary>(event),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Text(
          '見つかりませんでした',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
