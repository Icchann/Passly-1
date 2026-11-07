import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:passly/common/widgets/tag_sticker.dart';
import 'package:passly/core/constants/passly_tokens.dart';
import 'package:passly/core/network/network_activity_provider.dart';
import 'package:passly/features/auth/domain/auth_notifier.dart';
import 'package:passly/features/auth/presentation/widgets/auth_widgets.dart';

/// ログイン画面Widget
///
/// 上にタグのステッカーを散らしてアプリのロゴを置き，その下にメールとパスワード。
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    enableNetworkActivity(ref);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// 入力が変更されたらエラーメッセージをクリアする
  void _clearErrorIfNeeded() {
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    // ログイン成功時・エラー時の処理
    ref.listen(authNotifierProvider, (_, next) {
      next.when(
        data: (user) {
          if (user != null) {
            setState(() => _errorMessage = null);
            context.go('/home');
          }
        },
        error: (error, _) {
          setState(() => _errorMessage = _parseErrorMessage(error));
        },
        loading: () {},
      );
    });

    return Scaffold(
      backgroundColor: PasslyBg.defaultBg,
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Form(
            key: _formKey,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _StickerHero(),
                  const SizedBox(height: 28),
                  if (_errorMessage != null) ...[
                    AuthErrorBanner(
                      message: _errorMessage!,
                      onClose: () => setState(() => _errorMessage = null),
                    ),
                    const SizedBox(height: 16),
                  ],
                  AuthTextField(
                    controller: _emailController,
                    label: 'メールアドレス',
                    hint: 'example@passly.app',
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    onChanged: (_) => _clearErrorIfNeeded(),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'メールアドレスを入力してください';
                      }
                      if (!value.contains('@')) return '正しいメールアドレスを入力してください';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  AuthTextField(
                    controller: _passwordController,
                    label: 'パスワード',
                    hint: '6文字以上',
                    obscure: !_isPasswordVisible,
                    onToggleObscure: () => setState(
                      () => _isPasswordVisible = !_isPasswordVisible,
                    ),
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    onChanged: (_) => _clearErrorIfNeeded(),
                    onSubmitted: (_) => _handleLogin(),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'パスワードを入力してください';
                      }
                      if (value.length < 6) return 'パスワードは6文字以上で入力してください';
                      return null;
                    },
                  ),
                  const SizedBox(height: 28),
                  AuthPrimaryButton(
                    label: 'ログイン',
                    loading: authState.isLoading,
                    onPressed: _handleLogin,
                  ),
                  const SizedBox(height: 16),
                  AuthTextLink(
                    lead: 'はじめての方は ',
                    action: 'アカウントを作成',
                    onTap: () => context.push('/signup'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// エラーメッセージを解析してユーザーフレンドリーなメッセージに変換
  String _parseErrorMessage(Object error) {
    final errorStr = error.toString().toLowerCase();
    // 認証エラー（401）やパスワード・メール関連のエラー
    if (errorStr.contains('401') ||
        errorStr.contains('unauthorized') ||
        errorStr.contains('invalid') ||
        errorStr.contains('incorrect') ||
        errorStr.contains('password') ||
        errorStr.contains('email') ||
        errorStr.contains('credentials')) {
      return 'メールアドレスまたはパスワードが正しくありません';
    }
    // ネットワークエラー
    if (errorStr.contains('timeout') ||
        errorStr.contains('connection') ||
        errorStr.contains('network') ||
        errorStr.contains('socket')) {
      return 'ネットワークに接続できません。接続を確認してください';
    }
    // サーバーエラー
    if (errorStr.contains('500') || errorStr.contains('server')) {
      return 'サーバーエラーが発生しました。しばらくしてからお試しください';
    }
    // その他のエラー
    return 'ログインに失敗しました。入力内容を確認してください';
  }

  /// ログイン処理の実行
  void _handleLogin() {
    if (ref.read(authNotifierProvider).isLoading) return;
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    ref
        .read(authNotifierProvider.notifier)
        .login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
  }
}

/// ロゴのまわりにタグのステッカーを散らした上の部分。
class _StickerHero extends StatelessWidget {
  const _StickerHero();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 250,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ステッカーは左右の端に寄せて，文字には重ねない
          Positioned(left: 4, top: 40, child: _Deco('Figma', 56)),
          Positioned(right: 0, top: 28, child: _Deco('Flutter', 60)),
          Positioned(left: 0, top: 128, child: _Deco('Swift', 42)),
          Positioned(right: 4, top: 120, child: _Deco('Go', 48)),
          Positioned(left: 0, right: 0, top: 64, child: _Title()),
        ],
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.asset(
            'assets/images/app_icon.png',
            width: 84,
            height: 84,
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'おかえりなさい',
          style: TextStyle(
            fontFamily: PasslyFont.family,
            color: PasslyText.primary,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'すれ違った人のタグが，ステッカーで集まります',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: PasslyFont.family,
              color: PasslyText.secondary,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

class _Deco extends StatelessWidget {
  final String tag;
  final double size;

  const _Deco(this.tag, this.size);

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: TagSticker(tag: tag, size: size),
  );
}
