import 'package:flutter/material.dart';

import 'package:passly/common/widgets/text_field_context_menu.dart';
import 'package:passly/core/constants/app_colors.dart';
import 'package:passly/core/constants/passly_tokens.dart';

/// ログイン・新規登録で使う入力欄。
///
/// 上に太字のラベル，下に白い角丸の箱。フォーカス中は緑のふちになる。
class AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final String? help;
  final String? prefix;
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final Iterable<String>? autofillHints;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    this.help,
    this.prefix,
    this.obscure = false,
    this.onToggleObscure,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.autofillHints,
  });

  static const _radius = BorderRadius.all(Radius.circular(14));

  OutlineInputBorder _border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: _radius,
        borderSide: BorderSide(color: color, width: width),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: PasslyFont.family,
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          contextMenuBuilder: passlyContextMenuBuilder,
          obscureText: obscure,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          autocorrect: false,
          enableSuggestions: !obscure,
          onChanged: onChanged,
          onFieldSubmitted: onSubmitted,
          validator: validator,
          style: const TextStyle(
            fontFamily: PasslyFont.family,
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              fontFamily: PasslyFont.family,
              color: PasslyText.tertiary,
              fontSize: 15,
              fontWeight: FontWeight.w400,
            ),
            prefixText: prefix,
            prefixStyle: const TextStyle(
              fontFamily: PasslyFont.family,
              color: PasslyText.secondary,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            filled: true,
            fillColor: PasslyBg.surface,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 15,
            ),
            suffixIcon: onToggleObscure == null
                ? null
                : IconButton(
                    tooltip: obscure ? 'パスワードを表示' : 'パスワードを隠す',
                    icon: Icon(
                      obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: PasslyText.tertiary,
                      size: 22,
                    ),
                    onPressed: onToggleObscure,
                  ),
            border: _border(PasslyBorder.defaultBorder),
            enabledBorder: _border(PasslyBorder.defaultBorder),
            focusedBorder: _border(PasslyBrand.primary, 1.5),
            errorBorder: _border(PasslyState.error),
            focusedErrorBorder: _border(PasslyState.error, 1.5),
            errorMaxLines: 2,
          ),
        ),
        if (help != null) ...[
          const SizedBox(height: 6),
          Text(
            help!,
            style: const TextStyle(
              fontFamily: PasslyFont.family,
              color: PasslyText.secondary,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}

/// 緑の丸いボタン（マイページの「プロフィールを編集」と同じ見た目）。
class AuthPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(100),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: PasslyBrand.primary.withValues(alpha: 0.28),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: enabled
            ? PasslyBrand.primaryLight
            : PasslyBrand.primaryLight.withValues(alpha: 0.5),
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          child: SizedBox(
            height: 52,
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      label,
                      style: const TextStyle(
                        fontFamily: PasslyFont.family,
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 赤い枠のエラー表示。× で閉じられる。
class AuthErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onClose;

  const AuthErrorBanner({
    super.key,
    required this.message,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.errorBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontFamily: PasslyFont.family,
                color: AppColors.errorDark,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            tooltip: '閉じる',
            visualDensity: VisualDensity.compact,
            onPressed: onClose,
            icon: const Icon(
              Icons.close,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

/// 「はじめての方は アカウントを作成」のような，文＋緑の太字リンク。
class AuthTextLink extends StatelessWidget {
  final String lead;
  final String action;
  final VoidCallback onTap;

  const AuthTextLink({
    super.key,
    required this.lead,
    required this.action,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: onTap,
        child: Text.rich(
          TextSpan(
            text: lead,
            style: const TextStyle(
              fontFamily: PasslyFont.family,
              color: PasslyText.secondary,
              fontSize: 14,
            ),
            children: [
              TextSpan(
                text: action,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: PasslyBrand.primaryDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
