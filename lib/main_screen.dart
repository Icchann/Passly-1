import 'dart:io';
import 'dart:async';

import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:proximity_sensor/proximity_sensor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:passly/core/config/feature_flags.dart';
import 'package:passly/features/home/presentation/widgets/pocket_mode_button.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:passly/common/widgets/passly_bottom_nav.dart';
import 'package:passly/core/constants/app_colors.dart';
import 'package:passly/core/network/dio_client.dart';
import 'package:passly/core/network/network_activity_provider.dart';
import 'package:passly/features/ble/ble_notifier.dart';
import 'package:passly/features/settings/domain/settings_notifier.dart';
import 'package:passly/features/auth/domain/auth_notifier.dart';
import 'package:passly/features/encounter/domain/encounter_notifier.dart';
import 'package:passly/features/encounter/domain/encounter_model.dart';
import 'package:passly/features/user/domain/user_model.dart';
import 'package:passly/features/ble/domain/power_mode_notifier.dart';

/// メイン画面（4タブのBottomNavigationBar）
/// ログイン後に表示される画面で、BLEすれ違い機能のライフサイクルを管理する
class MainScreen extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainScreen({super.key, required this.navigationShell});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen>
    with WidgetsBindingObserver {
  static const MethodChannel _batteryChannel = MethodChannel(
    'passly/battery_optimization',
  );

  bool _bleStarted = false;
  bool _batteryCheckRunning = false;
  String? _lastBleUserId;

  bool _isNear = false;
  StreamSubscription<int>? _proximitySubscription;

  @override
  void initState() {
    super.initState();
    enableNetworkActivity(ref);
    // アプリのライフサイクルイベントを監視
    WidgetsBinding.instance.addObserver(this);
    // ログイン済みならBLEを自動開始
    _startBleIfLoggedIn();
    _checkBatteryOptimizationOnce();
    // 起動時の電源モード（☀️ 通常 / 🌙 ポケット）に応じて近接センサー監視を初期化
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncProximitySensorWithMode();
    });
  }

  /// 現在の電源モード（☀️ 通常 / 🌙 ポケット）に応じて近接センサー監視を同期する
  ///
  /// - ☀️ 通常使用モード (normal):
  ///   近接センサーの購読を停止 (cancel) し、iOS ネイティブ側の自動画面消灯
  ///   (UIDevice.isProximityMonitoringEnabled) を完全に解除する。
  ///   これにより通話中や通常操作中に画面が真っ黒になる現象を根本から防止する。
  /// - 🌙 ポケット中モード (pocket):
  ///   近接センサーの購読を開始し、UIDevice.isProximityMonitoringEnabled = true を有効化して
  ///   ポケット収納時の省電力暗転（ブラックアウト＆タッチ無効化）を作動させる。
  void _syncProximitySensorWithMode() {
    if (!mounted) return;
    final mode = ref.read(powerModeProvider);
    if (mode == PowerMode.pocket) {
      _startProximitySensor();
    } else {
      _stopProximitySensor();
    }
  }

  /// 近接センサー監視の開始（🌙 ポケット中モード時）
  void _startProximitySensor() {
    if (_proximitySubscription != null) return;
    _proximitySubscription = ProximitySensor.events.listen((int event) {
      if (!mounted) return;
      setState(() {
        _isNear = (event > 0);
      });
    });
    debugPrint('近接センサー監視を開始しました（🌙 ポケット中: isProximityMonitoringEnabled=true）');
  }

  /// 近接センサー監視の停止（☀️ 通常使用モード時: OSの自動消灯を解除）
  void _stopProximitySensor() {
    if (_proximitySubscription == null) return;
    _proximitySubscription?.cancel();
    _proximitySubscription = null;
    if (_isNear) {
      setState(() {
        _isNear = false;
      });
    }
    debugPrint('近接センサー監視を停止しました（☀️ 通常使用: isProximityMonitoringEnabled=false）');
  }

  @override
  void dispose() {
    // アプリ完全終了時にBLEおよび近接センサーを停止
    WidgetsBinding.instance.removeObserver(this);
    _stopProximitySensor();
    WakelockPlus.disable();
    _stopBle();
    super.dispose();
  }

  /// アプリのライフサイクル変化を検知
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // フォアグラウンドに復帰 → BLEが停止していたら再開
        debugPrint('アプリがフォアグラウンドに復帰しました');
        _startBleIfLoggedIn();
        if (Platform.isIOS && _bleStarted) {
          ref.read(bleNotifierProvider.notifier).resumeAdvertising();
        }
        _checkBatteryOptimizationOnce();
        _navigateToEncounterIfPending(reason: 'app_resumed');
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        // バックグラウンド移行時点の未確認データを保存して次回起動比較に使う
        ref.read(encounterNotifierProvider.notifier).saveShutdownSnapshot();
        // バックグラウンドに移行 → iOSの場合はアドバタイズのみ停止（31バイト制限回避のため）
        debugPrint('アプリがバックグラウンドに移行しました（iOSはアドバタイズ停止）');
        if (Platform.isIOS && _bleStarted) {
          ref.read(bleNotifierProvider.notifier).pauseAdvertising();
        }
        break;
      case AppLifecycleState.detached:
        // アプリが完全に終了 → BLEを停止
        ref.read(encounterNotifierProvider.notifier).saveShutdownSnapshot();
        debugPrint('アプリが終了します（BLE停止）');
        _stopBle();
        break;
    }
  }

  /// ログイン済みの場合にBLEすれ違い機能を開始する
  Future<void> _startBleIfLoggedIn() async {
    final user = ref.read(authNotifierProvider).value;
    if (user == null) return;

    // デモモードでは BLE を使わない（すれ違いはホームの長押しで出す）
    if (FeatureFlags.demoMode) return;

    // 設定でOFFになっている場合は自動開始しない
    final isBleEnabled =
        ref.read(settingsNotifierProvider).value?.isBleEnabled ?? true;
    if (!isBleEnabled) return;

    if (_bleStarted && _lastBleUserId == user.id) return;

    if (_bleStarted && _lastBleUserId != user.id) {
      await _stopBle();
    }

    try {
      await ref.read(bleNotifierProvider.notifier).start();
      _bleStarted = true;
      _lastBleUserId = user.id;
      WakelockPlus.enable(); // 常に画面をオン（擬似バックグラウンド用）
      debugPrint('BLEすれ違い機能を自動開始しました（ユーザー: ${user.id}）');
    } catch (e) {
      debugPrint('BLE自動開始エラー: $e');
    }
  }

  Future<void> _checkBatteryOptimizationOnce() async {
    if (!Platform.isAndroid || _batteryCheckRunning) return;

    final user = ref.read(authNotifierProvider).value;
    if (user == null) return;

    _batteryCheckRunning = true;
    try {
      final storage = ref.read(secureStorageProvider);
      final alreadyShown = await storage.read(
        key: 'battery_optimization_prompt_shown',
      );
      if (alreadyShown == '1') return;

      final ignored = await _batteryChannel.invokeMethod<bool>(
        'isIgnoringBatteryOptimizations',
      );
      if (ignored == true) {
        await storage.write(
          key: 'battery_optimization_prompt_shown',
          value: '1',
        );
        return;
      }

      if (!mounted) return;
      final shouldOpenSettings =
          await showDialog<bool>(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: const Text('バッテリー最適化の設定'),
                content: const Text(
                  'Androidの省電力機能により、バックグラウンドでのすれ違い検知が不安定になる場合があります。\n\n'
                  '「許可する」を押すと設定画面を開きます。',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('あとで'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('許可する'),
                  ),
                ],
              );
            },
          ) ??
          false;

      if (shouldOpenSettings) {
        await _batteryChannel.invokeMethod('requestIgnoreBatteryOptimizations');
      }

      await storage.write(key: 'battery_optimization_prompt_shown', value: '1');
    } on PlatformException catch (e) {
      debugPrint('バッテリー最適化チェックエラー: ${e.message}');
    } finally {
      _batteryCheckRunning = false;
    }
  }

  /// BLEすれ違い機能を停止する
  Future<void> _stopBle() async {
    if (!_bleStarted) return;
    try {
      await ref.read(bleNotifierProvider.notifier).stop();
      _bleStarted = false;
      _lastBleUserId = null;
      WakelockPlus.disable();
      debugPrint('BLEすれ違い機能を停止しました');
    } catch (e) {
      debugPrint('BLE停止エラー: $e');
    }
  }

  void _navigateToEncounterIfPending({required String reason}) {
    if (!mounted) return;

    final pending =
        ref.read(encounterNotifierProvider).asData?.value ?? const [];
    if (pending.isEmpty) {
      debugPrint('すれ違い結果遷移スキップ: pending=0 (reason=$reason)');
      return;
    }

    final location = GoRouterState.of(context).matchedLocation;
    if (location == '/encounter-result') {
      debugPrint(
        'すれ違い結果遷移スキップ: 既に表示中 (reason=$reason, pending=${pending.length})',
      );
      return;
    }

    debugPrint(
      'すれ違い結果へ遷移: reason=$reason, pending=${pending.length}, from=$location',
    );
    context.go('/encounter-result');
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<UserModel?>>(authNotifierProvider, (previous, next) {
      final prevId = previous?.asData?.value?.id;
      final nextId = next.asData?.value?.id;

      if (prevId == nextId) return;

      if (nextId == null) {
        _stopBle();
      } else {
        _startBleIfLoggedIn();
      }
    });

    ref.listen<AsyncValue<List<EncounterModel>>>(encounterNotifierProvider, (
      previous,
      next,
    ) {
      final prevCount = previous?.asData?.value.length ?? 0;
      final nextCount = next.asData?.value.length ?? 0;
      final hasNewPending = nextCount > prevCount;
      if (!hasNewPending) return;

      debugPrint('未確認すれ違い増加を検知: $prevCount -> $nextCount');
      _navigateToEncounterIfPending(reason: 'pending_increased');
    });

    ref.listen<BleState>(bleNotifierProvider, (previous, next) {
      final titles = next.newlyUnlockedAchievementTitles;
      if (titles.isEmpty) return;

      final previousTitles =
          previous?.newlyUnlockedAchievementTitles ?? const [];
      if (listEquals(previousTitles, titles)) return;

      final message = titles.length == 1
          ? '実績を解除: ${titles.first}'
          : '実績を${titles.length}件解除: ${titles.join(' / ')}';

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );

      ref
          .read(bleNotifierProvider.notifier)
          .consumeUnlockedAchievementNotifications();
    });

    final pendingState = ref.watch(encounterNotifierProvider);
    final pendingCount = pendingState.asData?.value.length ?? 0;
    // 未確認のすれ違い結果が存在する場合のみ、UI描画後に結果画面へ遷移
    if (pendingCount > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateToEncounterIfPending(reason: 'build_completed');
      });
    }

    // ホーム画面右上の電源モードトグル（☀️ 通常使用 / 🌙 ポケット中）の変更を検知して近接センサー監視を即時切り替え
    ref.listen<PowerMode>(powerModeProvider, (previous, next) {
      if (previous != next) {
        _syncProximitySensorWithMode();
      }
    });

    // ホーム画面右上の電源モードトグル（☀️ 通常使用 / 🌙 ポケット中）の状態を監視
    final powerMode = ref.watch(powerModeProvider);

    // 近接センサーによる省電力暗転（ブラックアウト）の適用判定:
    // - ☀️ 通常使用モード (powerMode == PowerMode.normal):
    //   近接センサーの監視自体が停止されているため暗転せず、通常通り操作可能。
    // - 🌙 ポケット中モード (powerMode == PowerMode.pocket):
    //   近接センサーが反応した時(_isNear == true)のみ、画面を真っ黒にしてタッチを無効化（ポケット誤動作防止・OLED省電力化）する。
    final shouldBlackoutScreen = _isNear && (powerMode == PowerMode.pocket);

    final showPocketModeButton =
        defaultTargetPlatform == TargetPlatform.iOS &&
        widget.navigationShell.currentIndex == 0 &&
        (ref.watch(settingsNotifierProvider).value?.isBleEnabled ?? true);

    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.backgroundWhite,
          extendBody: true, // タブバーの背後まで画面を広げる
          body: widget.navigationShell,
          bottomNavigationBar: _buildBottomNav(context),
        ),
        // ポケットモードの切り替え（iOS のホームだけ。右端から 16、ナビの上端から 16 上）。
        // ナビの Stack の外にはみ出して置くとタップが届かないので、画面全体の Stack に置く。
        if (showPocketModeButton)
          Positioned(
            right: 16,
            bottom: MediaQuery.paddingOf(context).bottom + 15 + 64 + 16,
            child: const PocketModeButton(),
          ),
        if (shouldBlackoutScreen)
          Positioned.fill(
            child: AbsorbPointer(
              absorbing: true,
              child: Container(
                color: Colors.black, // ポケットの中などで真っ暗にする（OLED省電力化）
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    final isBleEnabled =
        ref.watch(settingsNotifierProvider).value?.isBleEnabled ?? true;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            PasslyBottomNav(
              currentIndex: widget.navigationShell.currentIndex,
              onTap: (index) => _onTap(context, index),
            ),
            if (!isBleEnabled)
              Positioned(
                right: 0,
                bottom: 70, // ナビゲーションバーの上に浮かせる
                child: IgnorePointer(
                  // ボタンに干渉しないように
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Text(
                      'すれ違い検知がオフになっているよ！！',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _onTap(BuildContext context, int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }
}
