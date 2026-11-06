import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:passly/core/config/feature_flags.dart';
import 'package:passly/demo/demo_api.dart';
import 'package:passly/features/auth/domain/auth_notifier.dart';
import 'package:passly/features/auth/presentation/splash_screen.dart';
import 'package:passly/features/auth/presentation/login_screen.dart';
import 'package:passly/features/auth/presentation/sign_up_screen.dart';
import 'package:passly/features/close_friend/presentation/close_friend_list_screen.dart';
import 'package:passly/features/encounter/presentation/daily_encounter_list_screen.dart';
import 'package:passly/features/encounter/presentation/encounter_result_screen.dart';
import 'package:passly/features/event/presentation/event_album_screen.dart';
import 'package:passly/features/event/presentation/event_detail_screen.dart';
import 'package:passly/features/event/presentation/event_search_screen.dart';
import 'package:passly/features/home/presentation/home_screen.dart';
import 'package:passly/features/plaza/presentation/friend_search_screen.dart';
import 'package:passly/features/plaza/presentation/plaza_screen.dart';
import 'package:passly/features/plaza/presentation/profile_screen.dart';
import 'package:passly/features/calendar/presentation/calendar_screen.dart';
import 'package:passly/features/mypage/presentation/mypage_qr_screen.dart';
import 'package:passly/features/mypage/presentation/mypage_screen.dart';
import 'package:passly/features/mypage/presentation/profile_edit_screen.dart';
import 'package:passly/features/mypage/presentation/qr_scan_screen.dart';
import 'package:passly/features/mypage/presentation/stamp_card_screen.dart';
import 'package:passly/features/settings/presentation/settings_screen.dart';
import 'package:passly/main_screen.dart';
import 'package:passly/core/utils/app_time.dart';

/// GoRouterのリフレッシュ用Notifier
class RouterNotifier extends ChangeNotifier {
  final Ref ref;
  RouterNotifier(this.ref) {
    ref.listen<AsyncValue<dynamic>>(
      authNotifierProvider,
      (previous, next) => notifyListeners(),
    );
  }
}

/// GoRouterの設定を管理するプロバイダー
final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = RouterNotifier(ref);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    debugLogDiagnostics: true, // デバッグ用: ルーティングのログを出力
    // 認証状態に応じたリダイレクト処理
    redirect: (context, state) {
      final authState = ref.read(authNotifierProvider);
      final user = authState.whenOrNull(data: (user) => user);
      final isLoggedIn = user != null;
      final isOnAuthPage =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup' ||
          state.matchedLocation == '/';

      // ログイン済みで認証ページにいる場合 → ホームへ
      // （デモモードでは起動直後をすれ違い画面にする）
      if (isLoggedIn && isOnAuthPage) {
        return FeatureFlags.demoMode && DemoApi.instance.hasPendingEncounter
            ? '/encounter-result'
            : '/home';
      }
      // 未ログインで認証ページ以外にいる場合 → ログインへ
      if (!isLoggedIn && !isOnAuthPage) return '/login';

      return null; // リダイレクトなし
    },

    routes: [
      // スプラッシュ画面（初期画面）
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),

      // すれ違い結果画面（Mii広場風）
      GoRoute(
        path: '/encounter-result',
        builder: (context, state) => const EncounterResultScreen(),
      ),

      // ログイン画面
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),

      // アカウント作成画面
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignUpScreen(),
      ),

      // プロフィール画面
      GoRoute(
        path: '/profile/:id',
        builder: (context, state) {
          final userId = state.pathParameters['id'] ?? '';
          return ProfileScreen(userId: userId);
        },
      ),

      // スタンプカード（実績確認）画面
      GoRoute(
        path: '/stamp-card',
        builder: (context, state) => const StampCardScreen(),
      ),

      // 設定画面 (マイページ右上の歯車ボタンから遷移)
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),

      // マイページヘッダーの「友だち追加 (QR)」ボタンから開く QR 画面
      GoRoute(
        path: '/mypage/qr',
        builder: (context, state) => const MyPageQrScreen(),
      ),

      // マイページの「プロフィールを編集」から開く編集画面
      GoRoute(
        path: '/mypage/edit',
        builder: (context, state) => const ProfileEditScreen(),
      ),

      // QR 表示画面ヘッダーのスキャナアイコンから開く QR コード読み取り画面
      GoRoute(
        path: '/mypage/qr/scan',
        builder: (context, state) => const QrScanScreen(),
      ),

      // 指定日のすれ違い相手一覧画面
      GoRoute(
        path: '/encounters/day/:date',
        builder: (context, state) {
          final raw = state.pathParameters['date'] ?? '';
          final date = DateTime.tryParse(raw) ?? AppTime.nowLocal();
          return DailyEncounterListScreen(date: date);
        },
      ),

      // 親しい友達一覧画面
      GoRoute(
        path: '/close-friends',
        builder: (context, state) => const CloseFriendListScreen(),
      ),

      // 広場ヘッダーの検索アイコンから開く「友達検索」画面
      GoRoute(
        path: '/plaza/search',
        builder: (context, state) => const FriendSearchScreen(),
      ),

      // 月表示のカレンダー画面（週表示から「月表示はこちら」で遷移）
      GoRoute(
        path: '/calendar/month',
        builder: (context, state) => const CalendarScreen(),
      ),

      // イベント検索画面
      // NOTE: /events/:id より前に置くこと。GoRouter は静的パスを優先するが、
      // 順序を入れ替えると混乱するので明示的に上に配置。
      GoRoute(
        path: '/events/search',
        builder: (context, state) => const EventSearchScreen(),
      ),

      // イベント詳細画面
      GoRoute(
        path: '/events/:id',
        builder: (context, state) {
          final raw = state.pathParameters['id'] ?? '';
          final id = int.tryParse(raw) ?? 0;
          return EventDetailScreen(eventId: id);
        },
      ),

      // メイン画面（4タブのBottomNavigationBar）
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainScreen(navigationShell: navigationShell);
        },
        branches: [
          // タブ1: ホーム
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),

          // タブ2: 広場
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/plaza',
                builder: (context, state) => const PlazaScreen(),
              ),
            ],
          ),

          // タブ3: イベント（旧カレンダー。参加したイベントを並べる）
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/calendar',
                builder: (context, state) => const EventAlbumScreen(),
              ),
            ],
          ),

          // タブ4: マイページ
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/mypage',
                builder: (context, state) => const MyPageScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
