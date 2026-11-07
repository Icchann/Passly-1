import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:passly/core/config/feature_flags.dart';
import 'package:passly/core/network/dio_client.dart';
import 'package:passly/demo/demo_people.dart';
import 'package:passly/features/user/domain/user_model.dart';

/// 認証リポジトリのプロバイダー
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.read(dioProvider), ref.read(secureStorageProvider));
});

/// 認証関連のAPI通信を担当するリポジトリ
class AuthRepository {
  final Dio _dio;
  final FlutterSecureStorage _storage;

  AuthRepository(this._dio, this._storage);

  /// サインアップAPI（POST /signup）
  /// レスポンス仕様がないため返り値は `Future<void>` とし、ボディ処理は行いません
  Future<void> signUp({
    required String id,
    required String name,
    required String email,
    required String password,
    required String iconUrl,
    required String oneWord,
    required String role,
    required String techStack,
    String connpassUrl = '',
  }) async {
    await _dio.post(
      '/signup',
      data: {
        "id": id,
        "name": name,
        "email": email,
        "password": password,
        "icon_url": iconUrl,
        "one_word": oneWord,
        "role": role,
        "tech_stack": techStack,
        "connpass_username": connpassUrl,
      },
      options: Options(contentType: 'application/json'),
    );
  }

  /// パスワードを変更する（PATCH /users/:id/password）。
  Future<void> changePassword({
    required String userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    await _dio.patch(
      '/users/$userId/password',
      data: {'current_password': currentPassword, 'new_password': newPassword},
    );
  }

  /// ログイン通信API（POST /login）
  /// ログイン成功後、返却されたuser_idを保存し、そのIDでプロフィールを取得します
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post(
      '/login',
      data: {"email": email, "password": password},
      options: Options(contentType: 'application/json'),
    );

    final String userId = response.data['user_id'] as String;
    final String? token = response.data['token'] as String?;
    // ユーザーIDをローカルに保存（永続ログイン等に使用）
    await _storage.write(key: 'user_id', value: userId);
    // 認証トークン(JWT)を保存。dio_client.dartのインターセプターが
    // 保護されたAPI呼び出し時にAuthorization: Bearerとして自動付与する。
    if (token != null && token.isNotEmpty) {
      await _storage.write(key: authTokenStorageKey, value: token);
      AuthTokenCache.set(token);
    }

    // 認証成功後、ユーザー情報を取得して返す
    return await _fetchUser(userId);
  }

  /// 保持しているUserIdを使ってセッションを復元（プロフィール取得）
  Future<UserModel> restoreSession(String userId) async {
    return await _fetchUser(userId);
  }

  /// ユーザー情報を取得する（GET /users/:id）
  Future<UserModel> _fetchUser(String id) async {
    try {
      final response = await _dio.get('/users/$id');
      // オフライン起動時のために、最新のプロフィールJSONをローカルにキャッシュ
      await _storage.write(
        key: 'cached_user_profile_$id',
        value: jsonEncode(response.data),
      );
      return UserModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      // ネットワークエラーで取得できない場合、キャッシュがあればそれを返す
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.unknown) {
        final cachedStr = await _storage.read(key: 'cached_user_profile_$id');
        if (cachedStr != null) {
          try {
            final json = jsonDecode(cachedStr) as Map<String, dynamic>;
            return UserModel.fromJson(json);
          } catch (_) {
            // キャッシュが壊れている場合は無視して再スロー
          }
        }
      }
      rethrow; // その他のエラーやキャッシュがない場合はそのまま投げる
    }
  }

  /// 保存済みユーザーIDの有無を確認する
  Future<bool> hasSession() async {
    if (FeatureFlags.demoMode) return true;
    try {
      final userId = await _storage.read(key: 'user_id');
      return userId != null;
    } catch (_) {
      return false; // ネイティブエラー時（Mac環境のKeychain等）は未ログイン扱いにする
    }
  }

  /// 保存されたユーザーIDを取得する
  Future<String?> getSavedUserId() async {
    if (FeatureFlags.demoMode) return demoMeId;
    try {
      return await _storage.read(key: 'user_id');
    } catch (_) {
      return null;
    }
  }

  /// ログアウト（ユーザーID・認証トークンを削除）
  Future<void> logout() async {
    await _storage.delete(key: 'user_id');
    await _storage.delete(key: authTokenStorageKey);
    AuthTokenCache.clear();
  }
}
