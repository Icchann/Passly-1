import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:passly/core/constants/passly_tokens.dart';
import 'package:passly/features/auth/domain/auth_notifier.dart';
import 'package:passly/features/auth/domain/connpass_username.dart';
import 'package:passly/features/auth/presentation/widgets/auth_widgets.dart';

/// アカウント作成画面Widget
///
/// 3 ステップに分けて入力する。
/// 1. メールとパスワード 2. すれ違った人に見せる名前 3. connpass（あとからでもよい）
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  static const _stepCount = 3;

  final _formKeys = List.generate(_stepCount, (_) => GlobalKey<FormState>());
  final _idController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmationController = TextEditingController();
  final _connpassController = TextEditingController();
  int _step = 0;
  bool _isPasswordVisible = false;
  bool _isPasswordConfirmationVisible = false;
  String? _errorMessage;

  /// UserModel.role は API 互換のため送信し続ける必要があるが、フロントの
  /// ステップからは撤去 (フロントエンド / バックエンド分類は tech_stack に統合予定)。
  static const String _defaultRole = 'other';

  @override
  void initState() {
    super.initState();
    _connpassController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmationController.dispose();
    _connpassController.dispose();
    super.dispose();
  }

  /// 入力が変更されたらエラーメッセージをクリアする
  void _clearErrorIfNeeded() {
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    }
  }

  /// エラーメッセージを解析してユーザーフレンドリーなメッセージに変換
  String _parseErrorMessage(Object error) {
    final errorStr = error.toString().toLowerCase();
    // ユーザーID重複エラー
    if (errorStr.contains('duplicate') ||
        errorStr.contains('already exists') ||
        errorStr.contains('conflict') ||
        errorStr.contains('409')) {
      return 'このユーザーIDまたはメールアドレスは既に使用されています';
    }
    // メールアドレス関連のエラー
    if (errorStr.contains('email') && errorStr.contains('invalid')) {
      return 'メールアドレスの形式が正しくありません';
    }
    // パスワード関連のエラー
    if (errorStr.contains('password')) {
      return 'パスワードが要件を満たしていません';
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
    return 'アカウント作成に失敗しました。入力内容を確認してください';
  }

  void _next() {
    if (!_formKeys[_step].currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _errorMessage = null;
      _step++;
    });
  }

  void _back() {
    if (_step == 0) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/login');
      }
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _errorMessage = null;
      _step--;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    // サインアップ成功時・エラー時の処理
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

    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: PasslyBg.defaultBg,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StepHeader(step: _step, count: _stepCount, onBack: _back),
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Form(
                    key: _formKeys[_step],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ..._stepTitle(),
                        const SizedBox(height: 20),
                        if (_errorMessage != null) ...[
                          AuthErrorBanner(
                            message: _errorMessage!,
                            onClose: () => setState(() => _errorMessage = null),
                          ),
                          const SizedBox(height: 16),
                        ],
                        ...switch (_step) {
                          0 => _accountFields(),
                          1 => _profileFields(),
                          _ => _connpassFields(),
                        },
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: _bottomButtons(authState.isLoading),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _stepTitle() {
    final (title, sub) = switch (_step) {
      0 => ('メールとパスワード', 'ログインに使います．ほかの人には見えません．'),
      1 => ('すれ違った人に見せる名前', 'あとからマイページで変えられます．'),
      _ => ('connpassとつなぐ', '参加したイベントが自動でイベント画面に入り，お気に入りの人の予定も見られます．'),
    };
    return [
      Text(
        'ステップ ${_step + 1}／$_stepCount',
        style: const TextStyle(
          fontFamily: PasslyFont.family,
          color: PasslyBrand.primaryDark,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        title,
        style: const TextStyle(
          fontFamily: PasslyFont.family,
          color: PasslyText.primary,
          fontSize: 24,
          fontWeight: FontWeight.w900,
          height: 1.3,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        sub,
        style: const TextStyle(
          fontFamily: PasslyFont.family,
          color: PasslyText.secondary,
          fontSize: 13,
          height: 1.5,
        ),
      ),
    ];
  }

  List<Widget> _accountFields() => [
    AuthTextField(
      controller: _emailController,
      label: 'メールアドレス',
      hint: 'example@passly.app',
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.email],
      onChanged: (_) => _clearErrorIfNeeded(),
      validator: (v) {
        if (v == null || v.isEmpty) return 'メールアドレスを入力してください';
        if (!v.contains('@')) return '正しいメールアドレスを入力してください';
        return null;
      },
    ),
    const SizedBox(height: 16),
    AuthTextField(
      controller: _passwordController,
      label: 'パスワード',
      hint: '6文字以上',
      obscure: !_isPasswordVisible,
      onToggleObscure: () =>
          setState(() => _isPasswordVisible = !_isPasswordVisible),
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.newPassword],
      onChanged: (_) => _clearErrorIfNeeded(),
      validator: (v) {
        if (v == null || v.isEmpty) return 'パスワードを入力してください';
        if (v.length < 6) return '6文字以上で入力してください';
        return null;
      },
    ),
    const SizedBox(height: 16),
    AuthTextField(
      controller: _passwordConfirmationController,
      label: 'パスワード（確認）',
      hint: 'もう一度入力',
      obscure: !_isPasswordConfirmationVisible,
      onToggleObscure: () => setState(
        () => _isPasswordConfirmationVisible = !_isPasswordConfirmationVisible,
      ),
      textInputAction: TextInputAction.done,
      onChanged: (_) => _clearErrorIfNeeded(),
      onSubmitted: (_) => _next(),
      validator: (v) {
        if (v == null || v.isEmpty) return '確認用パスワードを入力してください';
        if (v != _passwordController.text) return 'パスワードが一致しません';
        return null;
      },
    ),
  ];

  List<Widget> _profileFields() => [
    AuthTextField(
      controller: _nameController,
      label: '表示名',
      hint: 'パスリー たろう',
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.nickname],
      onChanged: (_) => _clearErrorIfNeeded(),
      validator: (v) => (v == null || v.trim().isEmpty) ? '表示名を入力してください' : null,
    ),
    const SizedBox(height: 16),
    AuthTextField(
      controller: _idController,
      label: 'ユーザーID',
      hint: 'passly_taro',
      prefix: '@ ',
      help: '半角英数字と _ ，3文字以上',
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.newUsername],
      onChanged: (_) => _clearErrorIfNeeded(),
      onSubmitted: (_) => _next(),
      validator: (v) {
        if (v == null || v.isEmpty) return 'ユーザーIDを入力してください';
        if (v.length < 3) return '3文字以上で入力してください';
        if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v)) {
          return '半角英数字とアンダースコアのみ使用できます';
        }
        return null;
      },
    ),
    const SizedBox(height: 20),
    _NamePreview(name: _nameController, id: _idController),
  ];

  List<Widget> _connpassFields() => [
    AuthTextField(
      controller: _connpassController,
      label: 'connpassのユーザー名',
      hint: '例：passly_taro',
      help: '（ ）はいりません．プロフィールのURLを貼っても大丈夫です',
      textInputAction: TextInputAction.done,
      onChanged: (_) => _clearErrorIfNeeded(),
      onSubmitted: (_) => _submit(),
    ),
    const SizedBox(height: 20),
    const _ConnpassGuide(),
  ];

  Widget _bottomButtons(bool loading) {
    if (_step < _stepCount - 1) {
      return AuthPrimaryButton(label: 'つぎへ', onPressed: _next);
    }
    final hasConnpass = _connpassController.text.trim().isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthPrimaryButton(
          label: 'つなげてはじめる',
          loading: loading && hasConnpass,
          onPressed: hasConnpass && !loading ? _submit : null,
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: loading
              ? null
              : () {
                  _connpassController.clear();
                  _submit();
                },
          child: const Text(
            'あとで設定する',
            style: TextStyle(
              fontFamily: PasslyFont.family,
              color: PasslyText.secondary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  void _submit() {
    if (ref.read(authNotifierProvider).isLoading) return;
    FocusScope.of(context).unfocus();
    ref
        .read(authNotifierProvider.notifier)
        .signUp(
          id: _idController.text.trim(),
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
          role: _defaultRole,
          connpassUrl: connpassUsernameFrom(_connpassController.text),
        );
  }
}

/// 戻るボタンと 3 本の進み具合バー。
class _StepHeader extends StatelessWidget {
  final int step;
  final int count;
  final VoidCallback onBack;

  const _StepHeader({
    required this.step,
    required this.count,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 24, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: '戻る',
            onPressed: onBack,
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: PasslyText.primary,
            ),
          ),
          const SizedBox(width: 4),
          for (int i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 6,
                decoration: BoxDecoration(
                  color: i <= step
                      ? PasslyBrand.primary
                      : PasslyBorder.defaultBorder,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 「すれ違った人にはこう見えます」のプレビュー。
class _NamePreview extends StatelessWidget {
  final TextEditingController name;
  final TextEditingController id;

  const _NamePreview({required this.name, required this.id});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: PasslyBrand.primarySurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'すれ違った人にはこう見えます',
            style: TextStyle(
              fontFamily: PasslyFont.family,
              color: PasslyBrand.primaryDark,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          ListenableBuilder(
            listenable: Listenable.merge([name, id]),
            builder: (context, _) {
              final shownName = name.text.trim().isEmpty
                  ? '表示名'
                  : name.text.trim();
              final shownId = id.text.trim().isEmpty
                  ? 'userid'
                  : id.text.trim();
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: PasslyBg.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: PasslyBrand.primaryMuted,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shownName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: PasslyFont.family,
                              color: PasslyText.primary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '@$shownId',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: PasslyFont.family,
                              color: PasslyText.secondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// 「ユーザー名はどこにある？」の手順と画像。
class _ConnpassGuide extends StatelessWidget {
  const _ConnpassGuide();

  static const _steps = [
    'connpassを開いてログインする',
    '右上のアイコンから自分のプロフィールへ',
    '名前の下の（ ）の中がユーザー名です',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: PasslyBg.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PasslyBorder.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              _NumberDot(text: '?', filled: false),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'ユーザー名はどこにある？',
                  style: TextStyle(
                    fontFamily: PasslyFont.family,
                    color: PasslyText.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < _steps.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _NumberDot(text: '${i + 1}', filled: i == _steps.length - 1),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _steps[i],
                    style: TextStyle(
                      fontFamily: PasslyFont.family,
                      color: PasslyText.primary,
                      fontSize: 13,
                      height: 1.5,
                      fontWeight: i == _steps.length - 1
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: PasslyBorder.defaultBorder),
              ),
              child: Image.asset(
                'assets/images/connpass_username_guide.png',
                fit: BoxFit.fitWidth,
                semanticLabel: 'connpassのプロフィール画面．名前の下のかっこの中がユーザー名',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberDot extends StatelessWidget {
  final String text;
  final bool filled;

  const _NumberDot({required this.text, required this.filled});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? PasslyBrand.primary : PasslyBrand.primarySurface,
        shape: BoxShape.circle,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: PasslyFont.family,
          color: filled ? Colors.white : PasslyBrand.primaryDark,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}
