import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:passly/common/widgets/loading_card_skeleton.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:passly/core/constants/app_colors.dart';
import 'package:passly/features/auth/domain/auth_notifier.dart';
import 'package:passly/features/calendar/data/calendar_repository.dart';
import 'package:passly/features/calendar/presentation/widgets/avatar_group_section.dart';
import 'package:passly/features/event/domain/event_album_notifier.dart';
import 'package:passly/features/user/domain/common_tags.dart';
import 'package:passly/features/event/data/event_repository.dart';
import 'package:passly/features/event/domain/event_model.dart';
import 'package:passly/core/utils/app_time.dart';

/// イベント詳細画面のプロバイダー。
///
/// eventId をキーに `eventRepositoryProvider.fetchEventDetail()` を叩く。
/// FeatureFlags.useMockEventDetail によりモック / 実 API を切替。
/// イベントの日に出会った人（共通タグのある人を先に並べる）。
final eventMetPeopleProvider =
    FutureProvider.family<List<AvatarItem>, DateTime>((ref, day) async {
      final me = ref.watch(authNotifierProvider).value;
      if (me == null) return const [];
      final data = await ref
          .read(calendarRepositoryProvider)
          .fetchDailyEncounters(userId: me.id, dateString: eventDateParam(day));
      // 実バックエンドは encounter_users、デモは users で返す。
      final users =
          (data['users'] as List? ?? data['encounter_users'] as List? ?? const [])
          .whereType<Map>()
          .toList();
      bool hasCommon(Map u) => commonTechTags(
        me.techStack,
        (u['tech_stack'] ?? u['techStack'])?.toString() ?? '',
      ).isNotEmpty;
      final sorted = [
        ...users.where(hasCommon),
        ...users.where((u) => !hasCommon(u)),
      ];
      return [
        for (final u in sorted)
          if ((u['id']?.toString() ?? '').isNotEmpty)
            AvatarItem(
              userId: u['id'].toString(),
              iconUrl: (u['icon_url'] ?? u['iconUrl'])?.toString() ?? '',
            ),
      ];
    });

final eventDetailProvider = FutureProvider.family<EventModel, int>((
  ref,
  eventId,
) {
  return ref.read(eventRepositoryProvider).fetchEventDetail(eventId);
});

/// イベント詳細画面（スタブ実装）。
///
/// Figma デザインが未提供のため、最小限のレイアウトで
/// EventRepository が返す情報をそのまま並べる。デザイン提供時に
/// 本 PR とは別で作り直す想定。
class EventDetailScreen extends ConsumerWidget {
  final int eventId;

  const EventDetailScreen({super.key, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(eventDetailProvider(eventId));

    return Scaffold(
      backgroundColor: AppColors.backgroundGrey,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundWhite,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'イベント詳細',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: eventAsync.when(
        data: (event) => _buildContent(context, event),
        loading: () => const Padding(
          padding: EdgeInsets.all(16),
          child: LoadingEventCardsSkeleton(),
        ),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'イベント情報の取得に失敗しました\n$error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, EventModel event) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (event.imageUrl.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                event.imageUrl,
                width: double.infinity,
                fit: BoxFit.fitWidth,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 20),
          ],
          Text(
            event.name,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),
          if (event.startAt != null)
            _MetaRow(
              icon: Icons.event,
              label: _formatDateRange(event.startAt!, event.endAt),
            ),
          if (event.location.isNotEmpty)
            _MetaRow(icon: Icons.location_on_outlined, label: event.location),
          _MetaRow(
            icon: Icons.groups,
            label:
                '参加者 ${event.accepted}人${event.limit > 0 ? ' / 定員 ${event.limit}人' : ''}${event.waiting > 0 ? '（キャンセル待ち ${event.waiting}人）' : ''}',
          ),
          if (event.description.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              event.description,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ],
          if (event.eventUrl.isNotEmpty) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _openUrl(context, event.eventUrl),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('イベントページを開く'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
              ),
            ),
          ],
          if (event.startAt != null) ...[
            const SizedBox(height: 32),
            _MetPeopleSection(day: AppTime.toAppLocal(event.startAt!)),
          ],
        ],
      ),
    );
  }

  static String _formatDateRange(DateTime startUtc, DateTime? endUtc) {
    final start = AppTime.toAppLocal(startUtc);
    final end = endUtc != null ? AppTime.toAppLocal(endUtc) : null;
    final startStr =
        '${start.year}/${start.month.toString().padLeft(2, '0')}/${start.day.toString().padLeft(2, '0')} '
        '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
    if (end == null) return startStr;
    final endStr =
        '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
    return '$startStr – $endStr';
  }

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('URL を開けませんでした')));
    }
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 以前のカレンダーの日別表示と同じ「この日に出会った人」。
/// 押すとその日に出会った人の一覧へ。
class _MetPeopleSection extends ConsumerWidget {
  final DateTime day;

  const _MetPeopleSection({required this.day});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = DateTime(day.year, day.month, day.day);
    final people = ref.watch(eventMetPeopleProvider(date)).value ?? const [];
    return AvatarGroupSection(
      title: 'この日に出会った人',
      subtitle: '${people.length}人と出会いました',
      items: people,
      totalCount: people.length,
      onTap: () => context.push('/encounters/day/${eventDateParam(date)}'),
    );
  }
}
