import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:passly/core/config/feature_flags.dart';
import 'package:passly/demo/demo_api.dart';
import 'package:passly/features/auth/domain/auth_notifier.dart';
import 'package:passly/core/network/network_activity_provider.dart';
import 'package:passly/core/network/password_change_error.dart';

/// セキュアストレージのプロバイダー（ユーザーID・認証トークン保存に使用）
final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

/// 認証トークン(JWT)をセキュアストレージに保存する際のキー。
/// AuthRepository.login()で保存し、このファイルのインターセプターで読み出す。
const authTokenStorageKey = 'auth_token';

/// 認証トークンのメモリ上の控え。
///
/// iOS の Keychain 読み出しは 1 回ごとに時間がかかるので，通信のたびに
/// セキュアストレージを読まないよう，一度読んだ値をここに持っておく。
/// ログイン（保存）・ログアウト（削除）のときに [AuthRepository] が書き換える。
abstract final class AuthTokenCache {
  static String? _token;
  static bool _loaded = false;

  static void set(String? token) {
    _token = token;
    _loaded = true;
  }

  static void clear() => set(null);

  /// 控えを持っていない状態に戻す（テスト用）。
  @visibleForTesting
  static void forget() {
    _token = null;
    _loaded = false;
  }

  /// 控えがあればそれを，なければストレージから読んで控える。
  static Future<String?> read(FlutterSecureStorage storage) async {
    if (_loaded) return _token;
    final token = await storage.read(key: authTokenStorageKey);
    set(token);
    return token;
  }
}

/// Dioインスタンスのプロバイダー
/// 2026-09-18: バックエンドがJWT認証に対応したため、Bearerトークンの自動付与と
/// 401(トークン期限切れ・不正)時の自動ログアウトを行うインターセプターを有効化した。
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      // 実際のRenderデプロイURLに変更
      baseUrl: 'https://passly-backend-rjck.onrender.com',
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  // デモモードではサーバーに通信せず、ダミーデータで応答する
  if (FeatureFlags.demoMode) {
    dio.interceptors.add(DemoApiInterceptor());
  }

  // 認証トークン自動付与 + 401時の自動ログアウト用インターセプター
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        startNetworkActivity(ref);
        final token = await AuthTokenCache.read(
          ref.read(secureStorageProvider),
        );
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onResponse: (response, handler) {
        finishNetworkActivity(ref);
        handler.next(response);
      },
      onError: (error, handler) async {
        finishNetworkActivity(ref);
        if (error.response?.statusCode == 401 &&
            !isIncorrectCurrentPassword(error)) {
          // トークンが無効・期限切れの場合はセッションを破棄してログイン画面へ戻す
          // (AuthNotifier.logout()がストレージ削除+状態更新を行い、
          //  GoRouterのredirectが自動的に/loginへ遷移させる)
          await ref.read(authNotifierProvider.notifier).logout();
        }
        handler.next(error);
      },
    ),
  );

  return dio;
});
