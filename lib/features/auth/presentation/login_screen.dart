import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:passly/common/widgets/text_field_context_menu.dart';
import 'package:passly/core/constants/app_colors.dart';
import 'package:passly/core/network/network_activity_provider.dart';
import 'package:passly/features/auth/domain/auth_notifier.dart';

/// ログイン画面Widget
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
          // エラーメッセージを解析してユーザーフレンドリーなメッセージに変換
          String message = _parseErrorMessage(error);
          setState(() => _errorMessage = message);
        },
        loading: () {},
      );
    });

    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                const SizedBox(height: 48),
                if (_errorMessage != null) ...[
                  _buildErrorBanner(),
                  const SizedBox(height: 16),
                ],
                _buildEmailField(),
                const SizedBox(height: 16),
                _buildPasswordField(),
                const SizedBox(height: 32),
                _buildLoginButton(authState),
                const SizedBox(height: 16),
                _buildSignUpLink(),
              ],
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

  /// エラーバナーWidget
  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.errorBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(
                color: AppColors.errorDark,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _errorMessage = null),
            child: const Icon(
              Icons.close,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  /// ヘッダー（ロゴとタイトル）
  Widget _buildHeader() {
    return Column(
      children: [
        Image.asset('assets/images/app_icon.png', width: 80, height: 80),
        const SizedBox(height: 16),
        const Text(
          'Passly',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'ログインしてすれ違いを始めよう',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
      ],
    );
  }

  /// メールアドレス入力フィールド
  Widget _buildEmailField() {
    return TextFormField(
      contextMenuBuilder: passlyContextMenuBuilder,
      controller: _emailController,
      style: const TextStyle(color: AppColors.textPrimary),
      keyboardType: TextInputType.emailAddress,
      onChanged: (_) => _clearErrorIfNeeded(),
      decoration: _inputDecoration(
        label: 'メールアドレス',
        icon: Icons.email_outlined,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'メールアドレスを入力してください';
        if (!value.contains('@')) return '正しいメールアドレスを入力してください';
        return null;
      },
    );
  }

  /// パスワード入力フィールド
  Widget _buildPasswordField() {
    return TextFormField(
      contextMenuBuilder: passlyContextMenuBuilder,
      controller: _passwordController,
      obscureText: !_isPasswordVisible,
      style: const TextStyle(color: AppColors.textPrimary),
      onChanged: (_) => _clearErrorIfNeeded(),
      decoration: _inputDecoration(
        label: 'パスワード',
        icon: Icons.lock_outline,
        suffixIcon: IconButton(
          icon: Icon(
            _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
            color: AppColors.textSecondary,
          ),
          onPressed: () =>
              setState(() => _isPasswordVisible = !_isPasswordVisible),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'パスワードを入力してください';
        if (value.length < 6) return 'パスワードは6文字以上で入力してください';
        return null;
      },
    );
  }

  /// ログインボタン
  Widget _buildLoginButton(AsyncValue authState) {
    final isLoading = authState.isLoading;
    return ElevatedButton(
      onPressed: isLoading ? null : _handleLogin,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Text(
              'ログイン',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
    );
  }

  /// アカウント作成画面へのリンク
  Widget _buildSignUpLink() {
    return TextButton(
      onPressed: () => context.push('/signup'),
      child: RichText(
        text: const TextSpan(
          text: 'アカウントをお持ちでない方は',
          style: TextStyle(color: AppColors.textSecondary),
          children: [
            TextSpan(
              text: '新規登録',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ログイン処理の実行
  void _handleLogin() {
    if (!_formKey.currentState!.validate()) return;
    ref
        .read(authNotifierProvider.notifier)
        .login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
  }

  /// 入力フィールドの共通デコレーション
  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      prefixIcon: Icon(icon, color: AppColors.textSecondary),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.backgroundGrey,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }
}
