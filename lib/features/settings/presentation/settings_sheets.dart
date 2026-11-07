import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:passly/common/widgets/text_field_context_menu.dart';
import 'package:passly/core/constants/passly_tokens.dart';
import 'package:passly/core/network/password_change_error.dart';
import 'package:passly/features/auth/data/auth_repository.dart';
import 'package:passly/features/auth/domain/auth_notifier.dart';
import 'package:passly/features/mypage/presentation/widgets/profile_images.dart';

/// 設定画面から下に出すシートの共通の出し方。
/// 変更できたら true を返す。
Future<bool?> showSettingsSheet(BuildContext context, Widget sheet) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: PasslyBg.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => sheet,
  );
}

/// シートの上のつまみと，キーボードの分の余白をまとめた枠。
class _SheetFrame extends StatelessWidget {
  final List<Widget> children;

  const _SheetFrame({required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: PasslyBorder.defaultBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// パスワード変更
// ---------------------------------------------------------------------------

/// パスワード変更のシート。
/// 新しいパスワードの条件を下に並べ，満たしたものから緑のチェックを付ける。
/// すべて満たすまで「変更する」は押せない。
class ChangePasswordSheet extends ConsumerStatefulWidget {
  const ChangePasswordSheet({super.key});

  static const int minLength = 6;

  @override
  ConsumerState<ChangePasswordSheet> createState() =>
      _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends ConsumerState<ChangePasswordSheet> {
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirmation = TextEditingController();
  bool _isSaving = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirmation = true;

  @override
  void initState() {
    super.initState();
    for (final c in [_current, _new, _confirmation]) {
      c.addListener(_onChanged);
    }
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    // 閉じるアニメーション中も入力欄が参照するため，State と同時に破棄する。
    _current.dispose();
    _new.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  bool get _isLongEnough =>
      _new.text.characters.length >= ChangePasswordSheet.minLength;
  bool get _isDifferent => _new.text.isNotEmpty && _new.text != _current.text;
  bool get _isSame => _new.text.isNotEmpty && _new.text == _confirmation.text;
  bool get _canSave =>
      _current.text.isNotEmpty &&
      _isLongEnough &&
      _isDifferent &&
      _isSame &&
      !_isSaving;

  Future<void> _save() async {
    final user = ref.read(authNotifierProvider).value;
    if (user == null || !_canSave) return;
    setState(() => _isSaving = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .changePassword(
            userId: user.id,
            currentPassword: _current.text,
            newPassword: _new.text,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is DioException && isIncorrectCurrentPassword(error)
                ? 'いまのパスワードが正しくありません'
                : 'パスワードの変更に失敗しました',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(authNotifierProvider).value?.email ?? '';
    return _SheetFrame(
      children: [
        const Text(
          'パスワードを変更',
          style: TextStyle(
            fontFamily: PasslyFont.family,
            fontWeight: FontWeight.w900,
            fontSize: 20,
            color: PasslyText.primary,
          ),
        ),
        if (email.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'ログイン中：$email',
            style: const TextStyle(
              fontFamily: PasslyFont.family,
              fontSize: 12,
              color: PasslyText.secondary,
            ),
          ),
        ],
        const SizedBox(height: 16),
        _PasswordField(
          label: 'いまのパスワード',
          controller: _current,
          obscure: _obscureCurrent,
          onToggle: () => setState(() => _obscureCurrent = !_obscureCurrent),
        ),
        const SizedBox(height: 14),
        _PasswordField(
          label: '新しいパスワード',
          controller: _new,
          obscure: _obscureNew,
          onToggle: () => setState(() => _obscureNew = !_obscureNew),
        ),
        const SizedBox(height: 14),
        _PasswordField(
          label: '新しいパスワード（もう一度）',
          controller: _confirmation,
          obscure: _obscureConfirmation,
          onToggle: () =>
              setState(() => _obscureConfirmation = !_obscureConfirmation),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: PasslyBrand.primarySurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Rule(
                ok: _isLongEnough,
                text: '${ChangePasswordSheet.minLength}文字以上',
              ),
              const SizedBox(height: 8),
              _Rule(ok: _isDifferent, text: 'いまのパスワードとちがう'),
              const SizedBox(height: 8),
              _Rule(ok: _isSame, text: '2つの新しいパスワードが同じ'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _SheetButton(
          label: '変更する',
          onPressed: _canSave ? _save : null,
          isLoading: _isSaving,
        ),
        const SizedBox(height: 4),
        _CancelButton(enabled: !_isSaving),
      ],
    );
  }
}

class _PasswordField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool obscure;
  final VoidCallback onToggle;

  const _PasswordField({
    required this.label,
    required this.controller,
    required this.obscure,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: PasslyFont.family,
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: PasslyText.secondary,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          contextMenuBuilder: passlyContextMenuBuilder,
          controller: controller,
          obscureText: obscure,
          autocorrect: false,
          enableSuggestions: false,
          style: const TextStyle(
            fontFamily: PasslyFont.family,
            fontSize: 14,
            color: PasslyText.primary,
          ),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: PasslyBg.defaultBg,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            suffixIcon: IconButton(
              onPressed: onToggle,
              tooltip: obscure ? '表示' : '隠す',
              icon: Icon(
                obscure ? Icons.visibility_off : Icons.visibility,
                size: 20,
                color: PasslyText.secondary,
              ),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: PasslyBrand.primary,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Rule extends StatelessWidget {
  final bool ok;
  final String text;

  const _Rule({required this.ok, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          ok ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 18,
          color: ok ? PasslyBrand.primary : PasslyText.tertiary,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontFamily: PasslyFont.family,
            fontWeight: FontWeight.w500,
            fontSize: 13,
            color: ok ? PasslyText.primary : PasslyText.secondary,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// ログアウト・アカウント削除
// ---------------------------------------------------------------------------

/// ログアウトとアカウント削除の確認シート。
/// どのアカウントの操作かが分かるよう，アイコン・名前・メールアドレスを上に出す。
/// 押したら true を返すだけで，実際の処理は呼び出し側で行う。
class AccountActionSheet extends ConsumerWidget {
  final String message;
  final Widget notice;
  final String confirmLabel;
  final bool isDestructive;

  const AccountActionSheet({
    super.key,
    required this.message,
    required this.notice,
    required this.confirmLabel,
    this.isDestructive = false,
  });

  /// ログアウトの確認。
  const AccountActionSheet.logout({super.key})
    : message = 'このアカウントからログアウトします．\n記録は消えないので，またログインすれば続きから使えます．',
      notice = const _WarningNote('ログアウト中は，すれ違いを検知しません'),
      confirmLabel = 'ログアウト',
      isDestructive = false;

  /// アカウント削除の確認。
  const AccountActionSheet.deleteAccount({super.key})
    : message = 'このアカウントを削除します．\n削除すると元に戻せません．',
      notice = const _DeletedItems(),
      confirmLabel = 'アカウントを削除する',
      isDestructive = true;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authNotifierProvider).value;
    return _SheetFrame(
      children: [
        Center(
          child: SizedBox(
            width: 64,
            height: 64,
            child: ProfileAvatarCircle(url: user?.iconUrl ?? ''),
          ),
        ),
        const SizedBox(height: 10),
        if (user != null) ...[
          Text(
            user.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: PasslyFont.family,
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: PasslyText.primary,
            ),
          ),
          if (user.email.isNotEmpty)
            Text(
              user.email,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: PasslyFont.family,
                fontSize: 13,
                color: PasslyText.secondary,
              ),
            ),
          const SizedBox(height: 14),
        ],
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: PasslyFont.family,
            fontSize: 13,
            height: 1.6,
            color: PasslyText.secondary,
          ),
        ),
        const SizedBox(height: 16),
        notice,
        const SizedBox(height: 20),
        _SheetButton(
          label: confirmLabel,
          onPressed: () => Navigator.of(context).pop(true),
          style: isDestructive
              ? _SheetButtonStyle.danger
              : _SheetButtonStyle.outline,
        ),
        const SizedBox(height: 4),
        const _CancelButton(),
      ],
    );
  }
}

class _WarningNote extends StatelessWidget {
  final String text;
  const _WarningNote(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: Color(0xFFD97706),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: PasslyFont.family,
                fontWeight: FontWeight.w500,
                fontSize: 12,
                color: Color(0xFFD97706),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeletedItems extends StatelessWidget {
  const _DeletedItems();

  static const _items = [
    'プロフィール（名前・アイコン・タグ・リンク）',
    'すれ違った記録と親しい友達・スタンプカード',
    'すれ違った人の一覧からも，あなたが消えます',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '消えるもの',
            style: TextStyle(
              fontFamily: PasslyFont.family,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: PasslyState.error,
            ),
          ),
          for (final item in _items) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 7),
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: PasslyState.error,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item,
                    style: const TextStyle(
                      fontFamily: PasslyFont.family,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                      color: PasslyText.primary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ボタン
// ---------------------------------------------------------------------------

enum _SheetButtonStyle { primary, outline, danger }

class _SheetButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final _SheetButtonStyle style;

  const _SheetButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.style = _SheetButtonStyle.primary,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = const TextStyle(
      fontFamily: PasslyFont.family,
      fontWeight: FontWeight.w700,
      fontSize: 15,
    );
    final child = isLoading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: PasslyText.onBrand,
            ),
          )
        : Text(label);
    final shape = const StadiumBorder();
    const padding = EdgeInsets.symmetric(vertical: 14);
    if (style == _SheetButtonStyle.outline) {
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: PasslyText.primary,
          side: const BorderSide(color: PasslyBorder.defaultBorder),
          shape: shape,
          padding: padding,
          textStyle: textStyle,
        ),
        child: child,
      );
    }
    final color = style == _SheetButtonStyle.danger
        ? PasslyState.error
        : PasslyBrand.primary;
    return FilledButton(
      onPressed: isLoading ? () {} : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: PasslyText.onBrand,
        disabledBackgroundColor: PasslyBorder.defaultBorder,
        disabledForegroundColor: PasslyText.tertiary,
        shape: shape,
        padding: padding,
        textStyle: textStyle,
      ),
      child: child,
    );
  }
}

class _CancelButton extends StatelessWidget {
  final bool enabled;
  const _CancelButton({this.enabled = true});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: enabled ? () => Navigator.of(context).pop(false) : null,
      style: TextButton.styleFrom(foregroundColor: PasslyText.secondary),
      child: const Text(
        'キャンセル',
        style: TextStyle(
          fontFamily: PasslyFont.family,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
    );
  }
}
