import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:passly/common/widgets/text_field_context_menu.dart';
import 'package:passly/core/constants/app_colors.dart';
import 'package:passly/features/auth/domain/auth_notifier.dart';

/// アカウント作成画面Widget
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmationController = TextEditingController();
  final _connpassController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isPasswordConfirmationVisible = false;
  String? _errorMessage;

  /// UserModel.role は API 互換のため送信し続ける必要があるが、フロントの
  /// ステップからは撤去 (フロントエンド / バックエンド分類は tech_stack に統合予定)。
  static const String _defaultRole = 'other';

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

  @override
  Widget build(BuildContext context) {
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
          String message = _parseErrorMessage(error);
          setState(() => _errorMessage = message);
        },
        loading: () {},
      );
    });

    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundWhite,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          '新規登録',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(child: _buildBasicInfoStep()),
    );
  }

  /// 基本情報入力 → そのままアカウント作成 (旧ステップ 2 のロール選択は削除)
  Widget _buildBasicInfoStep() {
    final authState = ref.watch(authNotifierProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_errorMessage != null) ...[
              _buildErrorBanner(),
              const SizedBox(height: 16),
            ],
            _buildTextField(
              controller: _idController,
              label: 'ユーザーID（半角英数字）',
              icon: Icons.badge_outlined,
              validator: (v) {
                if (v == null || v.isEmpty) return 'ユーザーIDを入力してください';
                if (v.length < 3) return '3文字以上で入力してください';
                if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v)) {
                  return '半角英数字とアンダースコアのみ使用できます';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _nameController,
              label: '表示名',
              icon: Icons.person_outline,
              validator: (v) =>
                  (v == null || v.isEmpty) ? '表示名を入力してください' : null,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _emailController,
              label: 'メールアドレス',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.isEmpty) return 'メールアドレスを入力してください';
                if (!v.contains('@')) return '正しいメールアドレスを入力してください';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              contextMenuBuilder: passlyContextMenuBuilder,
              controller: _passwordController,
              obscureText: !_isPasswordVisible,
              style: const TextStyle(color: AppColors.textPrimary),
              onChanged: (_) => _clearErrorIfNeeded(),
              decoration: InputDecoration(
                labelText: 'パスワード（6文字以上）',
                labelStyle: const TextStyle(color: AppColors.textSecondary),
                prefixIcon: const Icon(
                  Icons.lock_outline,
                  color: AppColors.textSecondary,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility
                        : Icons.visibility_off,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () =>
                      setState(() => _isPasswordVisible = !_isPasswordVisible),
                ),
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
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'パスワードを入力してください';
                if (v.length < 6) return '6文字以上で入力してください';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              contextMenuBuilder: passlyContextMenuBuilder,
              controller: _passwordConfirmationController,
              obscureText: !_isPasswordConfirmationVisible,
              style: const TextStyle(color: AppColors.textPrimary),
              onChanged: (_) => _clearErrorIfNeeded(),
              decoration: InputDecoration(
                labelText: 'パスワード（確認）',
                labelStyle: const TextStyle(color: AppColors.textSecondary),
                prefixIcon: const Icon(
                  Icons.lock_outline,
                  color: AppColors.textSecondary,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isPasswordConfirmationVisible
                        ? Icons.visibility
                        : Icons.visibility_off,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () => setState(
                    () => _isPasswordConfirmationVisible =
                        !_isPasswordConfirmationVisible,
                  ),
                ),
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
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return '確認用パスワードを入力してください';
                if (v != _passwordController.text) {
                  return 'パスワードが一致しません';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _connpassController,
              label: 'ConnpassユーザーID（任意）',
              icon: Icons.link,
              validator: null, // 任意なのでバリデーションなし
            ),
            const SizedBox(height: 8),
            const Text(
              '※ Connpassアカウントを連携すると、イベント情報を取得できます',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: authState.isLoading
                  ? null
                  : () {
                      if (_formKey.currentState!.validate()) {
                        _handleSignUp();
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.primary.withValues(
                  alpha: 0.5,
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: authState.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'アカウントを作成',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// サインアップ処理を実行する
  void _handleSignUp() {
    ref
        .read(authNotifierProvider.notifier)
        .signUp(
          id: _idController.text.trim(),
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
          role: _defaultRole,
          connpassUrl: _connpassController.text.trim(),
        );
  }

  /// テキストフィールドの共通ビルダー
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      contextMenuBuilder: passlyContextMenuBuilder,
      controller: controller,
      style: const TextStyle(color: AppColors.textPrimary),
      keyboardType: keyboardType,
      onChanged: (_) => _clearErrorIfNeeded(),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        prefixIcon: Icon(icon, color: AppColors.textSecondary),
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
      ),
      validator: validator,
    );
  }
}
