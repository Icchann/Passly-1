import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:passly/core/network/dio_client.dart';
import 'package:passly/features/user/domain/user_model.dart';

/// ユーザーリポジトリのプロバイダー
final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(ref.read(dioProvider));
});

/// 指定ユーザーのプロフィール（GET /users/:id）。
/// 相手プロフィール画面と共通タグの計算で同じ結果を使い回す。
final userByIdProvider = FutureProvider.family<UserModel, String>((ref, id) {
  return ref.read(userRepositoryProvider).getUser(id);
});

/// ユーザー情報のAPI通信を担当するリポジトリ
/// バックエンドの GET /users/:id に合わせた実装
class UserRepository {
  final Dio _dio;

  UserRepository(this._dio);

  /// ユーザー情報を取得する（GET /users/:id）
  Future<UserModel> getUser(String id) async {
    try {
      final response = await _dio.get('/users/$id');
      debugPrint('User response data: ${response.data}');
      return UserModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      debugPrint('DioException: ${e.message}, ${e.response?.data}');
      throw Exception('ユーザー情報の取得に失敗しました: ${e.message}');
    } catch (e) {
      debugPrint('Error parsing user data: $e');
      throw Exception('ユーザー情報の解析に失敗しました: $e');
    }
  }

  /// ユーザー情報を更新する（PATCH /users/:id）
  Future<UserModel> updateUser(String id, Map<String, dynamic> data) async {
    try {
      debugPrint('PATCH /users/$id with data: $data');
      final response = await _dio.patch('/users/$id', data: data);
      debugPrint('Update response status: ${response.statusCode}');
      debugPrint('Update response data: ${response.data}');

      // レスポンスがユーザーデータを含む場合はそのまま返す
      if (response.data is Map &&
          response.data.containsKey('id') &&
          response.data.containsKey('name')) {
        return UserModel.fromJson(response.data as Map<String, dynamic>);
      }

      // messageのみのレスポンス（更新成功）の場合は、最新データを再取得
      return await getUser(id);
    } on DioException catch (e) {
      debugPrint('DioException: ${e.message}, ${e.response?.data}');
      throw Exception('ユーザー情報の更新に失敗しました: ${e.message}');
    } catch (e) {
      debugPrint('Error updating user: $e');
      throw Exception('ユーザー情報の更新に失敗しました: $e');
    }
  }

  /// ユーザーアカウントを削除する（DELETE /users/:id）
  Future<void> deleteUser(String id) async {
    try {
      await _dio.delete('/users/$id');
      debugPrint('User deleted: $id');
    } on DioException catch (e) {
      debugPrint('DioException: ${e.message}, ${e.response?.data}');
      throw Exception('アカウントの削除に失敗しました: ${e.message}');
    } catch (e) {
      debugPrint('Error deleting user: $e');
      throw Exception('アカウントの削除に失敗しました: $e');
    }
  }

  /// アバター画像をアップロード（POST /users/:id/avatar）
  /// Firebase Storageへアップロードされ、icon_urlが返される
  Future<String> uploadAvatar(String id, String imagePath) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        throw Exception('ファイルが見つかりません: $imagePath');
      }

      // マルチパートフォームデータを作成
      final formData = FormData.fromMap({
        'avatar': await MultipartFile.fromFile(
          imagePath,
          filename: imagePath.split('/').last,
        ),
      });

      final response = await _dio.post('/users/$id/avatar', data: formData);

      if (response.statusCode == 200) {
        return response.data['icon_url'] as String;
      } else {
        throw Exception('アップロードに失敗しました');
      }
    } on DioException catch (e) {
      // サーバーが返した理由（ファイルが大きすぎる など）も残す
      throw Exception(
        'アバター画像のアップロードに失敗しました: '
        '${e.response?.statusCode} ${e.response?.data ?? e.message}',
      );
    }
  }

  /// カバー画像をアップロード（POST /users/:id/cover）
  /// マイページの背景画像。アバターと同じ multipart 形式で送信し、
  /// レスポンスの `cover_url` を返す。
  ///
  /// TODO(passly): バックエンド側にこのエンドポイントは未実装。
  /// matsuki-yuki さんに /users/:id/cover を追加してもらう必要がある
  /// (avatar と同じ Firebase Storage フローで OK)。
  Future<String> uploadCover(String id, String imagePath) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        throw Exception('ファイルが見つかりません: $imagePath');
      }

      final formData = FormData.fromMap({
        'cover': await MultipartFile.fromFile(
          imagePath,
          filename: imagePath.split('/').last,
        ),
      });

      final response = await _dio.post('/users/$id/cover', data: formData);

      if (response.statusCode == 200) {
        return response.data['cover_url'] as String;
      } else {
        throw Exception('アップロードに失敗しました');
      }
    } on DioException catch (e) {
      throw Exception(
        'カバー画像のアップロードに失敗しました: '
        '${e.response?.statusCode} ${e.response?.data ?? e.message}',
      );
    }
  }
}
