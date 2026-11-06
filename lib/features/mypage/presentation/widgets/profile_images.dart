import 'dart:io';

import 'package:flutter/material.dart';

import 'package:passly/core/constants/passly_tokens.dart';

/// プロフィールのカバー画像。
///
/// [localPath] があればアップロード直後のローカル画像を優先して出す。
/// どちらもなければ緑のグラデーションに画像アイコン。
class ProfileCoverImage extends StatelessWidget {
  final String url;
  final String? localPath;

  const ProfileCoverImage({super.key, required this.url, this.localPath});

  @override
  Widget build(BuildContext context) {
    if (localPath != null && localPath!.isNotEmpty) {
      return Image.file(
        File(localPath!),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const _CoverFallback(),
      );
    }
    if (url.isEmpty) return const _CoverFallback();
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const _CoverFallback(),
    );
  }
}

class _CoverFallback extends StatelessWidget {
  const _CoverFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            PasslyBrand.primary.withValues(alpha: 0.6),
            PasslyBrand.primary.withValues(alpha: 0.9),
          ],
        ),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.image_outlined, color: Colors.white, size: 48),
    );
  }
}

/// 白い縁と影のついた丸いアイコン画像。
class ProfileAvatarCircle extends StatelessWidget {
  final String url;
  final String? localPath;

  const ProfileAvatarCircle({super.key, required this.url, this.localPath});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: PasslyBg.surface,
        border: Border.all(color: PasslyBg.surface, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(child: _buildImage()),
    );
  }

  Widget _buildImage() {
    if (localPath != null && localPath!.isNotEmpty) {
      return Image.file(
        File(localPath!),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const _AvatarFallback(),
      );
    }
    if (url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const _AvatarFallback(),
      );
    }
    return const _AvatarFallback();
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: PasslyBg.elevated,
      alignment: Alignment.center,
      child: const Icon(Icons.person, color: PasslyText.tertiary, size: 48),
    );
  }
}
