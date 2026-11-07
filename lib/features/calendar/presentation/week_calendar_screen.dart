import 'package:flutter/material.dart';
import 'package:passly/features/event/domain/event_album_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:passly/common/widgets/passly_header.dart';
import 'package:passly/core/constants/app_colors.dart';
import 'package:passly/features/calendar/domain/calendar_notifier.dart';
import 'package:passly/features/calendar/presentation/widgets/avatar_group_section.dart';
import 'package:passly/features/calendar/presentation/widgets/day_event_card.dart';
import 'package:passly/common/widgets/week_day_pill.dart';
import 'package:passly/core/utils/app_time.dart';

/// 週表示のカレンダー画面（新規デフォルト）。
///
/// - ヘッダー：タイトル + 検索アイコン + 自分アバター
/// - 週ナビ：「YYYY年M月」+ 前後移動 + 「月表示はこちら」リンク
/// - 週の日付ピル（7 日）
/// - その日のイベントカード → /events/:id
/// - 「この日に出会った人」 → /encounters/day/:date
class WeekCalendarScreen extends ConsumerStatefulWidget {
  const WeekCalendarScreen({super.key});

  @override
  ConsumerState<WeekCalendarScreen> createState() => _WeekCalendarScreenState();
}

class _WeekCalendarScreenState extends ConsumerState<WeekCalendarScreen> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = AppTime.nowLocal();
    _selectedDate = DateTime(now.year, now.month, now.day);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(calendarNotifierProvider.notifier)
          .fetchMonthData(_monthOf(_selectedDate));
    });
  }

  DateTime _monthOf(DateTime date) => DateTime(date.year, date.month);

  void _goToPreviousMonth() {
    final prev = DateTime(_selectedDate.year, _selectedDate.month - 1, 1);
    setState(() => _selectedDate = prev);
    ref.read(calendarNotifierProvider.notifier).fetchMonthData(prev);
  }

  void _goToNextMonth() {
    final next = DateTime(_selectedDate.year, _selectedDate.month + 1, 1);
    setState(() => _selectedDate = next);
    ref.read(calendarNotifierProvider.notifier).fetchMonthData(next);
  }

  void _onDayTap(DateTime date) {
    if (date.month != _selectedDate.month) {
      ref
          .read(calendarNotifierProvider.notifier)
          .fetchMonthData(_monthOf(date));
    }
    setState(() => _selectedDate = date);
  }

  /// 検索アイコンタップ → イベント検索画面 → 選択日を受け取って反映
  Future<void> _openEventSearch() async {
    final picked = await context.push<EventSummary>('/events/search');
    if (picked == null || !mounted) return;
    final selected = picked.day;

    final nextMonth = _monthOf(selected);
    final currentMonth = _monthOf(_selectedDate);
    if (nextMonth.year != currentMonth.year ||
        nextMonth.month != currentMonth.month) {
      ref.read(calendarNotifierProvider.notifier).fetchMonthData(nextMonth);
    }
    setState(() => _selectedDate = selected);
  }

  @override
  Widget build(BuildContext context) {
    final calendarState = ref.watch(calendarNotifierProvider);

    final dayData = _findDayData(calendarState.encounterDays, _selectedDate);

    return Scaffold(
      backgroundColor: AppColors.backgroundGrey,
      // PasslyHeader 自身が SafeArea を処理するため wrap しない (背景を上端まで延ばす)。
      body: Column(
        children: [
          PasslyHeader.calendar(onSearchTap: _openEventSearch),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(15, 24, 15, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _MonthNavigation(
                    month: _selectedDate,
                    onPrev: _goToPreviousMonth,
                    onNext: _goToNextMonth,
                    onOpenMonthView: () => context.push('/calendar/month'),
                  ),
                  const SizedBox(height: 8),
                  _WeekStrip(selectedDate: _selectedDate, onSelect: _onDayTap),
                  const SizedBox(height: 24),
                  _EventCardSection(
                    dayData: dayData,
                    selectedDate: _selectedDate,
                  ),
                  const SizedBox(height: 24),
                  _EncounterSection(
                    selectedDate: _selectedDate,
                    dayData: dayData,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic>? _findDayData(
    Map<DateTime, Map<String, dynamic>> encounterDays,
    DateTime date,
  ) {
    for (final entry in encounterDays.entries) {
      if (entry.key.year == date.year &&
          entry.key.month == date.month &&
          entry.key.day == date.day) {
        return entry.value;
      }
    }
    return null;
  }
}

class _MonthNavigation extends StatelessWidget {
  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onOpenMonthView;

  const _MonthNavigation({
    required this.month,
    required this.onPrev,
    required this.onNext,
    required this.onOpenMonthView,
  });

  @override
  Widget build(BuildContext context) {
    // Figma 1305:2149 準拠: 左 chevron + 月テキスト + 右 chevron + 「月表示はこちら」
    // すべて左寄せ + gap 4px でインライン配置。
    return Row(
      children: [
        _NavChevronButton(icon: Icons.chevron_left, onTap: onPrev),
        const SizedBox(width: 4),
        Text(
          '${month.year}年${month.month}月',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            height: 24 / 20,
          ),
        ),
        const SizedBox(width: 4),
        _NavChevronButton(icon: Icons.chevron_right, onTap: onNext),
        const SizedBox(width: 4),
        InkWell(
          onTap: onOpenMonthView,
          borderRadius: BorderRadius.circular(4),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Text(
              '月表示はこちら',
              style: TextStyle(
                color: AppColors.iconBlue,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 14.4 / 12,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Figma の月ナビ chevron に相当する小さめのタップ領域付きアイコン。
/// 22.843x22.843 の透明タップ領域に 18px のアイコンを配置。
class _NavChevronButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _NavChevronButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: SizedBox(
        width: 23,
        height: 23,
        child: Icon(icon, color: AppColors.textPrimary, size: 18),
      ),
    );
  }
}

/// 選択日を含む週の 7 日を横並びで表示。
/// 週の起点は月曜（DateTime.weekday の 1）。
///
/// 横にスワイプすると前後の週へ移動し、選択日は同じ曜日のまま 7 日ずれる。
/// 月ナビや検索で選択日が別の週へ飛んだときは、その週のページへ移る。
class _WeekStrip extends ConsumerStatefulWidget {
  final DateTime selectedDate;
  final void Function(DateTime date) onSelect;

  const _WeekStrip({required this.selectedDate, required this.onSelect});

  @override
  ConsumerState<_WeekStrip> createState() => _WeekStripState();
}

class _WeekStripState extends ConsumerState<_WeekStrip> {
  /// 前後どちらにも十分スワイプできるよう、真ん中あたりのページから始める。
  static const int _basePage = 10000;

  late final DateTime _baseWeekStart;
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    _baseWeekStart = _startOfWeek(widget.selectedDate);
    _controller = PageController(initialPage: _basePage);
  }

  @override
  void didUpdateWidget(covariant _WeekStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    final target = _pageOf(widget.selectedDate);
    if (_controller.hasClients && _controller.page?.round() != target) {
      _controller.jumpToPage(target);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  DateTime _weekStartOf(int page) => DateTime(
    _baseWeekStart.year,
    _baseWeekStart.month,
    _baseWeekStart.day + (page - _basePage) * 7,
  );

  int _pageOf(DateTime date) {
    final days = _startOfWeek(date).difference(_baseWeekStart).inHours / 24;
    return _basePage + (days / 7).round();
  }

  void _onPageChanged(int page) {
    final weekStart = _weekStartOf(page);
    final offset = widget.selectedDate.weekday - DateTime.monday;
    final date = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day + offset,
    );
    if (!_isSameDay(date, widget.selectedDate)) widget.onSelect(date);
  }

  @override
  Widget build(BuildContext context) {
    final eventDates =
        ref.watch(calendarEventDatesProvider).value ?? const <DateTime>{};
    final now = AppTime.nowLocal();
    final today = DateTime(now.year, now.month, now.day);

    // 目印が右上に少しはみ出すので、その分だけ上と右に余白を取る
    return SizedBox(
      height: 80,
      child: PageView.builder(
        controller: _controller,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, page) {
          final weekStart = _weekStartOf(page);
          return Padding(
            padding: const EdgeInsets.only(top: 4, right: 3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (index) {
                final date = DateTime(
                  weekStart.year,
                  weekStart.month,
                  weekStart.day + index,
                );
                return WeekDayPill(
                  date: date,
                  isSelected: _isSameDay(date, widget.selectedDate),
                  onTap: () => widget.onSelect(date),
                  badgeColor: !eventDates.contains(date)
                      ? null
                      : date.isAfter(today)
                      ? WeekDayPill.upcomingEventBadge
                      : WeekDayPill.pastEventBadge,
                );
              }),
            ),
          );
        },
      ),
    );
  }

  DateTime _startOfWeek(DateTime date) {
    // 月曜始まり: weekday 1 (月) が起点。日曜は 7。
    final delta = date.weekday - DateTime.monday;
    return DateTime(date.year, date.month, date.day - delta);
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _EventCardSection extends StatelessWidget {
  final Map<String, dynamic>? dayData;
  final DateTime selectedDate;

  const _EventCardSection({required this.dayData, required this.selectedDate});

  @override
  Widget build(BuildContext context) {
    final eventName = (dayData?['event'] as String?)?.trim() ?? '';
    if (eventName.isEmpty) {
      return _EmptyEventCard();
    }

    final location = (dayData?['event_location'] as String?)?.trim() ?? '';
    // 参加者数は daily API の participant_count か、GET /events の accepted。
    // どちらもなければ 0 表示。
    final count = (dayData?['participant_count'] as int?) ?? 0;
    final eventIdRaw = dayData?['event_id'];
    final eventId = eventIdRaw is int
        ? eventIdRaw
        : int.tryParse('$eventIdRaw');

    return DayEventCard(
      eventName: eventName,
      date: selectedDate,
      location: location,
      participantCount: count,
      imageUrl: dayData?['event_image_url'] as String?,
      onTap: () {
        if (eventId != null) {
          context.push('/events/$eventId');
        } else {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text('イベント ID が未取得のため詳細を開けません'),
                behavior: SnackBarBehavior.floating,
              ),
            );
        }
      },
    );
  }
}

class _EmptyEventCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider, width: 1),
      ),
      alignment: Alignment.center,
      child: const Text(
        'この日のイベントはありません',
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _EncounterSection extends StatelessWidget {
  final DateTime selectedDate;
  final Map<String, dynamic>? dayData;

  const _EncounterSection({required this.selectedDate, required this.dayData});

  @override
  Widget build(BuildContext context) {
    final count = (dayData?['count'] as int?) ?? 0;
    final rawUsers = dayData?['users'];
    final users = rawUsers is List
        ? rawUsers
              .whereType<Map>()
              .map((raw) {
                final map = Map<String, dynamic>.from(raw);
                return AvatarItem(
                  userId: map['id']?.toString() ?? '',
                  iconUrl: map['iconUrl']?.toString() ?? '',
                );
              })
              .where((u) => u.userId.isNotEmpty)
              .toList()
        : const <AvatarItem>[];

    return AvatarGroupSection(
      title: 'この日に出会った人',
      subtitle: '$count人と出会いました',
      items: users,
      totalCount: count > 0 ? count : users.length,
      onTap: () {
        final dateParam =
            '${selectedDate.year.toString().padLeft(4, '0')}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
        context.push('/encounters/day/$dateParam');
      },
    );
  }
}
