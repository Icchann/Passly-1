import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:passly/common/widgets/passly_header.dart';
import 'package:passly/core/constants/app_colors.dart';
import 'package:passly/core/constants/passly_tokens.dart';
import 'package:passly/core/network/password_change_error.dart';
import 'package:passly/features/auth/domain/auth_notifier.dart';
import 'package:passly/features/auth/data/auth_repository.dart';
import 'package:passly/features/ble/ble_notifier.dart';
import 'package:passly/features/user/data/user_repository.dart';
import 'package:passly/features/settings/domain/settings_notifier.dart';
import 'package:passly/features/ble/domain/power_mode_notifier.dart';

class _ChangePasswordDialog extends ConsumerStatefulWidget {
  const _ChangePasswordDialog();

  @override
  ConsumerState<_ChangePasswordDialog> createState() =>
      _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<_ChangePasswordDialog> {
  final formKey = GlobalKey<FormState>();
  final currentController = TextEditingController();
  final newController = TextEditingController();
  final confirmationController = TextEditingController();
  bool isSaving = false;
  bool obscureCurrent = true;
  bool obscureNew = true;
  bool obscureConfirmation = true;

  @override
  void dispose() {
    // 閉じるアニメーション中も入力欄が参照するため、Stateと同時に破棄する。
    currentController.dispose();
    newController.dispose();
    confirmationController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!formKey.currentState!.validate()) return;
    final user = ref.read(authNotifierProvider).value;
    if (user == null) return;
    setState(() => isSaving = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .changePassword(
            userId: user.id,
            currentPassword: currentController.text,
            newPassword: newController.text,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is DioException && isIncorrectCurrentPassword(error)
                ? '現在のパスワードが正しくありません'
                : 'パスワードの変更に失敗しました',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('パスワードを変更'),
      content: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _passwordField(
                controller: currentController,
                label: '現在のパスワード',
                obscure: obscureCurrent,
                onToggle: () =>
                    setState(() => obscureCurrent = !obscureCurrent),
              ),
              const SizedBox(height: 12),
              _passwordField(
                controller: newController,
                label: '新しいパスワード（6文字以上）',
                obscure: obscureNew,
                onToggle: () => setState(() => obscureNew = !obscureNew),
                validator: (value) {
                  if (value == null || value.length < 6) {
                    return '6文字以上で入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _passwordField(
                controller: confirmationController,
                label: '確認用パスワード',
                obscure: obscureConfirmation,
                onToggle: () =>
                    setState(() => obscureConfirmation = !obscureConfirmation),
                validator: (value) {
                  if (value != newController.text) {
                    return 'パスワードが一致しません';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: isSaving ? null : _save,
          child: isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('変更する'),
        ),
      ],
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator:
          validator ??
          (value) => value == null || value.isEmpty ? '入力してください' : null,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
        ),
      ),
    );
  }
}

/// アプリの設定画面。マイページ右上の歯車ボタンから遷移する。
///
/// 内容 (上から):
/// - すれ違いがうまくいかないときのチェック (Bluetooth・権限・iPhone の画面オフ)
/// - すれ違い: 検知の ON/OFF，ポケットモード
/// - アカウント: メールアドレス，パスワード変更
/// - アプリについて: 利用規約 / プライバシーポリシー (外部リンク)
/// - ログアウト (ボタン) / アカウント削除 (一番下の小さい赤字)
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const String _termsUrl = 'https://example.com/terms';
  static const String _privacyUrl = 'https://example.com/privacy';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsState = ref.watch(settingsNotifierProvider).value;
    final bleActive = settingsState?.isBleEnabled ?? true;
    final email = ref.watch(authNotifierProvider).value?.email ?? '';

    return Scaffold(
      backgroundColor: PasslyBg.defaultBg,
      body: Column(
        children: [
          PasslyHeader(
            leading: PasslyBackButton(
              onTap: () {
                if (context.canPop()) context.pop();
              },
            ),
            title: '設定',
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(15, 24, 15, 120),
              children: [
                const _SectionLabel('すれ違いがうまくいかないとき'),
                const _TroubleshootCard(),
                const SizedBox(height: PasslySpace.s24),
                const _SectionLabel('すれ違い'),
                _SettingsCard(
                  children: [
                    _ToggleRow(
                      icon: Icons.bluetooth,
                      title: 'すれ違いを検知する',
                      subtitle: 'オフにすると，すれ違っても記録されません',
                      value: bleActive,
                      onChanged: (val) => _toggleBle(context, ref, val),
                    ),
                    const _Divider(),
                    Consumer(
                      builder: (context, ref, child) {
                        final powerMode = ref.watch(powerModeProvider);
                        final isPocket = powerMode == PowerMode.pocket;

                        return _ToggleRow(
                          icon: Icons.smartphone,
                          title: 'ポケットモード',
                          subtitle: '画面を暗くして，アプリを開いたまま省電力ですれ違いを続けます',
                          value: isPocket,
                          onChanged: (val) {
                            // ホーム画面のトグル状態 (☀️ / 🌙) を更新
                            ref
                                .read(powerModeProvider.notifier)
                                .set(val ? PowerMode.pocket : PowerMode.normal);
                            // 設定値の永続化
                            ref
                                .read(settingsNotifierProvider.notifier)
                                .setPocketModeEnabled(val);
                          },
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: PasslySpace.s24),
                const _SectionLabel('アカウント'),
                _SettingsCard(
                  children: [
                    if (email.isNotEmpty) ...[
                      _InfoRow(
                        icon: Icons.mail_outline,
                        label: 'メールアドレス',
                        value: email,
                      ),
                      const _Divider(),
                    ],
                    _LinkRow(
                      icon: Icons.lock_outline,
                      label: 'パスワードを変更',
                      onTap: () => _showChangePasswordDialog(context, ref),
                    ),
                  ],
                ),
                const SizedBox(height: PasslySpace.s24),
                const _SectionLabel('アプリについて'),
                _SettingsCard(
                  children: [
                    _LinkRow(
                      icon: Icons.description_outlined,
                      label: '利用規約',
                      onTap: () => _launchUrl(_termsUrl),
                    ),
                    const _Divider(),
                    _LinkRow(
                      icon: Icons.privacy_tip_outlined,
                      label: 'プライバシーポリシー',
                      onTap: () => _launchUrl(_privacyUrl),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                _LogoutButton(onTap: () => _confirmAndLogout(context, ref)),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: () => _confirmAndDeleteAccount(context, ref),
                    style: TextButton.styleFrom(
                      foregroundColor: PasslyState.error,
                    ),
                    child: const Text(
                      'アカウントを削除する',
                      style: TextStyle(
                        fontFamily: PasslyFont.family,
                        fontSize: 13,
                        fontWeight: PasslyFont.medium,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleBle(
    BuildContext context,
    WidgetRef ref,
    bool next,
  ) async {
    final notifier = ref.read(bleNotifierProvider.notifier);
    try {
      if (next) {
        // 事前権限チェック (ONにする直前)
        bool granted = true;
        if (Platform.isAndroid) {
          final scan = await Permission.bluetoothScan.request();
          final advertise = await Permission.bluetoothAdvertise.request();
          final connect = await Permission.bluetoothConnect.request();
          // Android 11以下の場合は location 等も必要になるが、主力のBLE権限で弾く
          if (!scan.isGranted || !advertise.isGranted || !connect.isGranted) {
            granted = false;
          }
        } else {
          final bt = await Permission.bluetooth.request();
          if (!bt.isGranted) granted = false;
        }

        if (!granted) {
          if (context.mounted) _showPermissionDialog(context);
          return; // 権限がない場合は処理を中断（ONにならない）
        }

        await notifier.start();
        // 成功した場合のみ状態を保存
        await ref.read(settingsNotifierProvider.notifier).setBleEnabled(true);
      } else {
        await notifier.stop();
        // 成功した場合のみ状態を保存
        await ref.read(settingsNotifierProvider.notifier).setBleEnabled(false);
      }
    } catch (e) {
      if (context.mounted) {
        final errorMsg = e.toString();
        if (next && errorMsg.contains('権限')) {
          _showPermissionDialog(context);
        } else {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(
                  next ? 'すれ違い検知の開始に失敗しました: $e' : 'すれ違い検知の停止に失敗しました: $e',
                ),
                backgroundColor: PasslyState.error,
              ),
            );
        }
      }
    }
  }

  Future<void> _showChangePasswordDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => const _ChangePasswordDialog(),
    );
    if (changed == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('パスワードを変更しました')));
    }
  }

  void _showPermissionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bluetooth等の権限が必要です'),
        content: const Text(
          'すれ違い通信をオンにするには、設定画面からBluetooth（または位置情報）へのアクセスを許可してください。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('設定を開く'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _confirmAndLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await _showConfirmDialog(
      context: context,
      title: 'ログアウトしますか？',
      confirmLabel: 'ログアウト',
      isDestructive: false,
    );
    if (confirmed != true) return;
    await ref.read(authNotifierProvider.notifier).logout();
    if (context.mounted) context.go('/login');
  }

  Future<void> _confirmAndDeleteAccount(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await _showConfirmDialog(
      context: context,
      title: '本当にアカウントを削除しますか？',
      message: 'この操作は取り消せません。すれ違い履歴や親しい友達などの情報が全て消えます。',
      confirmLabel: '削除する',
      isDestructive: true,
    );
    if (confirmed != true) return;

    final user = ref.read(authNotifierProvider).value;
    if (user == null) return;
    try {
      await ref.read(userRepositoryProvider).deleteUser(user.id);
      await ref.read(authNotifierProvider.notifier).logout();
      if (context.mounted) context.go('/login');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('アカウント削除に失敗しました: $e'),
              backgroundColor: PasslyState.error,
            ),
          );
      }
    }
  }

  Future<bool?> _showConfirmDialog({
    required BuildContext context,
    required String title,
    String? message,
    required String confirmLabel,
    required bool isDestructive,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: message == null ? null : Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: isDestructive
                    ? PasslyState.error
                    : PasslyBrand.primary,
              ),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: PasslyFont.family,
          color: PasslyText.secondary,
          fontSize: 12,
          fontWeight: PasslyFont.semibold,
          height: 14.4 / 12,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: PasslyBg.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PasslyBorder.divider, width: 1),
      ),
      child: Column(children: children),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Divider(color: PasslyBorder.divider, height: 1, thickness: 1),
    );
  }
}

class _LinkRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _LinkRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const fg = AppColors.textPrimary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: fg, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: PasslyFont.family,
                  color: fg,
                  fontSize: 14,
                  fontWeight: PasslyFont.medium,
                  height: 16.8 / 14,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: PasslyText.tertiary, size: 20),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, color: AppColors.textPrimary, size: 20),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: PasslyFont.family,
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: PasslyFont.medium,
                    height: 16.8 / 14,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontFamily: PasslyFont.family,
                      color: PasslyText.secondary,
                      fontSize: 12,
                      fontWeight: PasslyFont.regular,
                      height: 14.4 / 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: PasslyBrand.primary,
          ),
        ],
      ),
    );
  }
}

/// メールアドレスなど，押せない情報の行。
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textPrimary, size: 20),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontFamily: PasslyFont.family,
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: PasslyFont.medium,
              height: 16.8 / 14,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: PasslyFont.family,
                color: PasslyText.tertiary,
                fontSize: 13,
                fontWeight: PasslyFont.regular,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ログアウトボタン (白地に枠線，全幅)。
class _LogoutButton extends StatelessWidget {
  final VoidCallback onTap;
  const _LogoutButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.logout, size: 20),
      label: const Text(
        'ログアウト',
        style: TextStyle(
          fontFamily: PasslyFont.family,
          fontSize: 15,
          fontWeight: PasslyFont.bold,
        ),
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        foregroundColor: AppColors.textPrimary,
        backgroundColor: PasslyBg.surface,
        side: const BorderSide(color: PasslyBorder.strong),
        shape: const StadiumBorder(),
      ),
    );
  }
}

/// 「すれ違いがうまくいかないとき」のチェック。
///
/// 体験会などで「すれ違わない」と言われたときに，その場で原因を確かめられるようにする。
/// - Bluetooth がオンか (flutter_blue_plus の adapterState)
/// - Bluetooth の使用を許可しているか (permission_handler。押すと OS の設定を開く)
/// - iPhone は画面を消すとすれ違いが止まる (ポケットモードの案内)
class _TroubleshootCard extends StatelessWidget {
  const _TroubleshootCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: PasslyBg.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PasslyBorder.divider, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StreamBuilder<BluetoothAdapterState>(
            stream: _adapterState(),
            builder: (context, snapshot) {
              final state = snapshot.data;
              if (state == null) {
                return const _CheckItem(
                  status: _CheckStatus.unknown,
                  title: 'Bluetoothの状態を確認しています',
                );
              }
              final on = state == BluetoothAdapterState.on;
              return _CheckItem(
                status: on ? _CheckStatus.ok : _CheckStatus.warning,
                title: on ? 'Bluetoothがオン' : 'Bluetoothがオフです',
                subtitle: on ? null : '端末の設定でBluetoothをオンにしてください',
              );
            },
          ),
          const SizedBox(height: 10),
          FutureBuilder<bool>(
            future: _bluetoothPermissionGranted(),
            builder: (context, snapshot) {
              final granted = snapshot.data;
              if (granted == null) {
                return const _CheckItem(
                  status: _CheckStatus.unknown,
                  title: 'Bluetoothの使用許可を確認しています',
                );
              }
              return _CheckItem(
                status: granted ? _CheckStatus.ok : _CheckStatus.warning,
                title: granted ? 'Bluetoothの使用を許可済み' : 'Bluetoothの使用が許可されていません',
                subtitle: granted ? null : 'ここを押して，設定からPasslyを許可してください',
                onTap: granted ? null : openAppSettings,
              );
            },
          ),
          if (Platform.isIOS) ...[
            const SizedBox(height: 10),
            const _CheckItem(
              status: _CheckStatus.warning,
              title: '画面を消すと，すれ違いが止まります',
              subtitle: 'ポケットモードを使うと，画面を暗くしたまま続けられます',
            ),
          ],
        ],
      ),
    );
  }

  /// プラグインが使えない環境 (テストなど) では何も流さない。
  static Stream<BluetoothAdapterState> _adapterState() {
    try {
      return FlutterBluePlus.adapterState.handleError((Object _) {});
    } catch (_) {
      return const Stream.empty();
    }
  }

  static Future<bool> _bluetoothPermissionGranted() async {
    try {
      if (Platform.isAndroid) {
        final scan = await Permission.bluetoothScan.status;
        final advertise = await Permission.bluetoothAdvertise.status;
        final connect = await Permission.bluetoothConnect.status;
        return scan.isGranted && advertise.isGranted && connect.isGranted;
      }
      return (await Permission.bluetooth.status).isGranted;
    } catch (_) {
      // 確認できないときは警告を出さない
      return true;
    }
  }
}

enum _CheckStatus { ok, warning, unknown }

class _CheckItem extends StatelessWidget {
  final _CheckStatus status;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  const _CheckItem({
    required this.status,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color) = switch (status) {
      _CheckStatus.ok => (Icons.check_circle, PasslyState.success),
      _CheckStatus.warning => (Icons.warning_rounded, PasslyState.warning),
      _CheckStatus.unknown => (Icons.more_horiz, PasslyText.tertiary),
    };
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: PasslyFont.family,
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: PasslyFont.medium,
                  height: 20 / 14,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontFamily: PasslyFont.family,
                    color: PasslyText.secondary,
                    fontSize: 11,
                    fontWeight: PasslyFont.regular,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}
