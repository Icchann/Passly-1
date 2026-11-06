import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:passly/common/widgets/encounter_loading_skeleton.dart';
import 'package:passly/common/widgets/info_badge_card.dart';
import 'package:passly/common/widgets/passly_icon.dart';
import 'package:passly/common/widgets/tag_sticker.dart';
import 'package:passly/core/constants/app_colors.dart';
import 'package:passly/core/constants/passly_tokens.dart';
import 'package:passly/features/auth/domain/auth_notifier.dart';
import 'package:passly/features/ble/ble_notifier.dart';
import 'package:passly/features/encounter/domain/encounter_model.dart';
import 'package:passly/features/encounter/domain/encounter_notifier.dart';
import 'package:passly/features/user/domain/common_tags.dart';
import 'package:passly/features/user/domain/user_model.dart';

/// すれ違い結果画面。
///
/// Figma node 1100:1602 に準拠。
/// - 自分と相手のアイコンを重ねて表示
/// - 相手の表示名
/// - 「出会った場所」= イベント名（未取得なら非表示）
/// - 「共通タグ」= 自分と相手の tech_stack の積集合（片方でも空なら非表示）
///   全部チップで出して折り返す。あわせて最初のタグから「話のネタ」を出す。
///
/// TODO(passly): 複数件の見せ方は未確定。
/// 現状は最新（先頭）1 件のみ表示している。
/// PageView や横スワイプ切替 / まとめ表示など、UX が決まったら書き換える。
class EncounterResultScreen extends ConsumerWidget {
  const EncounterResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final encounterState = ref.watch(encounterNotifierProvider);
    final me = ref.watch(authNotifierProvider).value;

    return Scaffold(
      backgroundColor: AppColors.backgroundGrey,
      body: SafeArea(
        child: encounterState.when(
          data: (encounters) =>
              _EncounterCardStack(encounters: encounters, me: me),
          loading: () => const EncounterLoadingSkeleton(),
          error: (err, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'すれ違い情報の取得に失敗しました\n$err',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EncounterCardStack extends StatefulWidget {
  final List<EncounterModel> encounters;
  final UserModel? me;
  const _EncounterCardStack({required this.encounters, required this.me});

  @override
  State<_EncounterCardStack> createState() => _EncounterCardStackState();
}

class _EncounterCardStackState extends State<_EncounterCardStack> {
  int _currentIndex = 0;

  void _nextCard() {
    if (_currentIndex < widget.encounters.length - 1) {
      setState(() {
        _currentIndex++;
      });
    }
  }

  Future<void> _close(WidgetRef ref) async {
    await ref.read(encounterNotifierProvider.notifier).confirmAll();
    ref.read(bleNotifierProvider.notifier).resetEncounterCount();
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    if (widget.encounters.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/home');
      });
      return const SizedBox.shrink();
    }
    if (_currentIndex >= widget.encounters.length) {
      return const SizedBox.shrink();
    }

    final encounter = widget.encounters[_currentIndex];
    final total = widget.encounters.length;
    final isLast = _currentIndex == total - 1;
    // 今の人を除いた残りの人数
    final remaining = total - _currentIndex - 1;

    // Figma node 1943:1308「スキップ 決定案：C＋進み具合の点」準拠。
    // スキップは下のリンクだと話のネタが埋もれるので、旧案 A（node 1942:1281）の
    // 右上の「すべてスキップ」にしている。
    return Consumer(
      builder: (context, ref, child) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(15, 0, 15, 25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 32,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: remaining >= 2
                      ? Padding(
                          padding: const EdgeInsets.only(right: 1),
                          child: _SkipAllButton(onTap: () => _close(ref)),
                        )
                      : null,
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _HeroSection(
                        myIconUrl: widget.me?.iconUrl ?? '',
                        encounter: encounter,
                        current: _currentIndex,
                        total: total,
                      ),
                      const SizedBox(height: 38),
                      _InfoCards(
                        myTechStack: widget.me?.techStack ?? '',
                        encounter: encounter,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _ActionButtons(
                targetUserId: encounter.encounteredUser.id,
                isLast: isLast,
                nextLabel: '次の人へ　${_currentIndex + 2} / $total',
                onNext: _nextCard,
                onClose: () => _close(ref),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// タイトル / 重ねアバター / 相手名を中央揃えで配置しつつ、
/// 周囲に Figma 準拠の装飾（4 つの丸 + 4 つの回転 pill）を Positioned で配置する。
class _HeroSection extends StatelessWidget {
  final String myIconUrl;
  final EncounterModel encounter;

  /// 何人目か（0 始まり）と全人数。2 人以上のときだけ進み具合の点を出す。
  final int current;
  final int total;

  const _HeroSection({
    required this.myIconUrl,
    required this.encounter,
    required this.current,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // メインコンテンツを自然な高さで配置
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const _TitleSection(),
              // タイトルとアイコンの間は 47。2 人以上なら間に進み具合の点を置く。
              if (total >= 2) ...[
                const SizedBox(height: 30),
                _ProgressDots(current: current, total: total),
                const SizedBox(height: 11),
              ] else
                const SizedBox(height: 47),
              _AvatarPair(myIconUrl: myIconUrl, encounter: encounter),
              const SizedBox(height: 47),
              _EncounteredName(name: encounter.encounteredUser.name),
            ],
          ),
        ),
        // 装飾: 4 つの小さな丸（各コーナー付近）
        const Positioned(
          right: 28,
          top: 20,
          child: _DecoDot(color: Color(0xFFF59E0B)),
        ),
        const Positioned(
          left: 45,
          top: 55,
          child: _DecoDot(color: Color(0xFF3AAA3A)),
        ),
        const Positioned(
          right: 40,
          top: 110,
          child: _DecoDot(color: Color(0xFFEF4444)),
        ),
        const Positioned(
          left: 30,
          top: 140,
          child: _DecoDot(color: Color(0xFF3B82F6)),
        ),
        // 装飾: 4 つの回転した pill（Figma tokens 準拠の色）
        const Positioned(
          right: 20,
          top: 50,
          child: _DecoPill(color: Color(0xFFB7E5B4), rotationDeg: -65),
        ),
        const Positioned(
          left: 10,
          top: 85,
          child: _DecoPill(color: Color(0xFF9CA3AF), rotationDeg: -30),
        ),
        const Positioned(
          right: 5,
          top: 170,
          child: _DecoPill(color: Color(0xFFC9A6FF), rotationDeg: 30),
        ),
        const Positioned(
          left: 15,
          top: 210,
          child: _DecoPill(color: Color(0xFF7CC4FF), rotationDeg: -70),
        ),
      ],
    );
  }
}

/// 装飾の小さな丸（10px）。Figma の Frame461-464 に相当。
class _DecoDot extends StatelessWidget {
  final Color color;

  const _DecoDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// 装飾の回転した pill（20x10）。Figma の rotated rounded rectangle に相当。
class _DecoPill extends StatelessWidget {
  final Color color;
  final double rotationDeg;

  const _DecoPill({required this.color, required this.rotationDeg});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotationDeg * 3.1415926535 / 180.0,
      child: Container(
        width: 20,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(100),
        ),
      ),
    );
  }
}

/// 進み具合の点。今の人は横長の緑、ほかは灰色の丸。
class _ProgressDots extends StatelessWidget {
  final int current;
  final int total;

  const _ProgressDots({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: i == current ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == current ? PasslyBrand.primary : PasslyText.disabled,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      ],
    );
  }
}

class _TitleSection extends StatelessWidget {
  const _TitleSection();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Text(
          'すれ違いました!',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            height: 28.8 / 24,
          ),
        ),
        SizedBox(height: 9),
        Text(
          'やったね!!',
          style: TextStyle(
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

/// 自分と相手のアイコンを 16px 分だけ重ねて表示するペア。
class _AvatarPair extends StatelessWidget {
  final String myIconUrl;
  final EncounterModel encounter;

  const _AvatarPair({required this.myIconUrl, required this.encounter});

  static const double _avatarSize = 100;
  static const double _overlap = 16;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _avatarSize * 2 - _overlap,
      height: _avatarSize,
      child: Stack(
        children: [
          Positioned(left: 0, top: 0, child: _Avatar(iconUrl: myIconUrl)),
          Positioned(
            left: _avatarSize - _overlap,
            top: 0,
            child: _Avatar(iconUrl: encounter.encounteredUser.iconUrl),
          ),
        ],
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
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.backgroundWhite,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 15,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipOval(
        child: iconUrl.isNotEmpty
            ? Image.network(
                iconUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _fallback(),
              )
            : _fallback(),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      color: AppColors.backgroundGrey,
      alignment: Alignment.center,
      child: const Icon(Icons.person, color: AppColors.textLight, size: 48),
    );
  }
}

class _EncounteredName extends StatelessWidget {
  final String name;

  const _EncounteredName({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 64),
      child: SingleChildScrollView(
        child: Text(
          name.isEmpty ? '名前未設定' : name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            height: 24 / 20,
          ),
        ),
      ),
    );
  }
}

class _InfoCards extends StatelessWidget {
  final String myTechStack;
  final EncounterModel encounter;

  const _InfoCards({required this.myTechStack, required this.encounter});

  @override
  Widget build(BuildContext context) {
    final commonTags = commonTechTags(
      myTechStack,
      encounter.encounteredUser.techStack,
    );
    final eventName = encounter.eventName.trim();

    return Column(
      children: [
        if (eventName.isNotEmpty) ...[
          InfoBadgeCard(
            iconAsset: PasslyIcons.location,
            label: '出会った場所',
            value: eventName,
          ),
          const SizedBox(height: 12),
        ],
        if (commonTags.isNotEmpty) ...[
          // 人を切り替えたら畳んだ状態に戻すため、相手ごとに作り直す
          _CommonTagCard(
            key: ValueKey(encounter.encounteredUser.id),
            tags: commonTags,
          ),
          const SizedBox(height: 12),
          InfoBadgeCard(
            icon: Icons.chat_bubble_outline_rounded,
            label: '話のネタ',
            value: '「${commonTags.first}好きなんですよね」',
          ),
        ],
      ],
    );
  }
}

/// 共通タグのカード。共通タグはどれも自分と同じタグなので，
/// 緑のふちのステッカー＋下にタグ名で並べる。
///
/// タグが多いと下の「話のネタ」がボタンに埋もれるので、最初は 1 行に
/// 収まる分だけ出し、残りは「+N すべて見る」にまとめる。押すと全部出す。
/// 1 行に入る数は画面の幅で変わる（小さい Android でもはみ出さない）。
class _CommonTagCard extends StatefulWidget {
  final List<String> tags;

  const _CommonTagCard({super.key, required this.tags});

  @override
  State<_CommonTagCard> createState() => _CommonTagCardState();
}

class _CommonTagCardState extends State<_CommonTagCard> {
  static const double _stickerSize = 44;
  static const double _itemWidth = 62;

  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final tags = widget.tags;
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      decoration: BoxDecoration(
        color: PasslyBg.soft,
        borderRadius: BorderRadius.circular(23.15),
        border: Border.all(color: PasslyBrand.primaryMuted, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 10),
      child: Row(
        children: [
          const InfoBadgeIcon(iconAsset: PasslyIcons.tag),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '共通タグ　${tags.length}つ',
                  style: const TextStyle(
                    color: PasslyBrand.primaryDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 16.8 / 14,
                  ),
                ),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final perRow = math.max(
                      1,
                      (constraints.maxWidth / _itemWidth).floor(),
                    );
                    final collapsed = !_expanded && tags.length > perRow;
                    final visible = collapsed ? tags.take(perRow - 1) : tags;
                    return Wrap(
                      runSpacing: 10,
                      children: [
                        for (final t in visible)
                          LabeledTagSticker(
                            tag: t,
                            size: _stickerSize,
                            width: _itemWidth,
                            same: true,
                          ),
                        if (collapsed)
                          _MoreTagsSticker(
                            count: tags.length - visible.length,
                            size: _stickerSize,
                            width: _itemWidth,
                            onTap: () => setState(() => _expanded = true),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 共通タグの「+N すべて見る」。ステッカーと同じ大きさの枠に残りの数を出す。
class _MoreTagsSticker extends StatelessWidget {
  final int count;
  final double size;
  final double width;
  final VoidCallback onTap;

  const _MoreTagsSticker({
    required this.count,
    required this.size,
    required this.width,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: PasslyBg.surface,
                borderRadius: BorderRadius.circular(size * 0.3),
                border: Border.all(color: PasslyBrand.primary, width: 2),
              ),
              child: Text(
                '+$count',
                style: const TextStyle(
                  color: PasslyBrand.primaryDark,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'すべて見る',
              maxLines: 1,
              style: TextStyle(
                fontFamily: PasslyFont.family,
                color: PasslyText.secondary,
                fontSize: 10,
                fontWeight: PasslyFont.bold,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 右上の「すべてスキップ」。押すと残りを飛ばしてホームへ戻る。
class _SkipAllButton extends StatelessWidget {
  final VoidCallback onTap;

  const _SkipAllButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PasslyBg.surface,
      shape: const StadiumBorder(
        side: BorderSide(color: PasslyBorder.defaultBorder),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: const SizedBox(
          height: 32,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Center(
              widthFactor: 1,
              child: Text(
                'すべてスキップ',
                style: TextStyle(
                  fontFamily: PasslyFont.family,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: PasslyText.secondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final String targetUserId;
  final bool isLast;
  final String nextLabel;
  final VoidCallback onNext;
  final Future<void> Function() onClose;

  const _ActionButtons({
    required this.targetUserId,
    required this.isLast,
    required this.nextLabel,
    required this.onNext,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PillButton(
          backgroundColor: PasslyBrand.primaryLight,
          textColor: Colors.white,
          label: 'プロフィールを見る',
          shadow: BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
          onTap: targetUserId.isEmpty
              ? null
              : () => context.push('/profile/$targetUserId'),
        ),
        const SizedBox(height: 9),
        _PillButton(
          backgroundColor: PasslyBg.surface,
          textColor: isLast ? PasslyText.secondary : PasslyText.primary,
          label: isLast ? 'ホームへ' : nextLabel,
          fontSize: isLast ? 20 : 16,
          onTap: () async {
            if (isLast) {
              await onClose();
            } else {
              onNext();
            }
          },
        ),
      ],
    );
  }
}

class _PillButton extends StatelessWidget {
  final Color backgroundColor;
  final Color textColor;
  final String label;
  final VoidCallback? onTap;
  final BoxShadow? shadow;
  final double fontSize;

  const _PillButton({
    required this.backgroundColor,
    required this.textColor,
    required this.label,
    required this.onTap,
    this.shadow,
    this.fontSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: onTap,
        child: Container(
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(100),
            boxShadow: shadow == null ? null : [shadow!],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: PasslyFont.family,
              color: textColor,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              height: 16.8 / 20,
            ),
          ),
        ),
      ),
    );
  }
}
