import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:passly/common/widgets/tag_sticker.dart';
import 'package:passly/core/constants/app_colors.dart';
import 'package:passly/core/constants/passly_tokens.dart';
import 'package:passly/features/auth/domain/auth_notifier.dart';
import 'package:passly/features/mypage/presentation/avatar_crop_screen.dart';
import 'package:passly/features/mypage/presentation/widgets/profile_images.dart';
import 'package:passly/features/user/data/tech_tag_catalog.dart';
import 'package:passly/features/user/data/user_repository.dart';
import 'package:passly/features/user/domain/user_model.dart';

/// プロフィール編集画面 (Figma「編集 確定案B改」)。
///
/// マイページの「プロフィールを編集」から開く。
/// - 入力欄は「基本 / 自己紹介 / TECH TAG / LINK」のカードにまとめる
/// - 名前・ひとこと・自己紹介は文字数を出し，上限を超えたら保存できない
/// - TECH TAG は検索を一番上に置き，カテゴリはその場で開く
/// - 保存は右上。変更があるときだけ緑になる
/// - 変更したまま戻ろうとすると確認を出す
///
/// アイコンとカバー画像は選んだ時点でアップロードする (今までどおり)。
class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

/// 文字数の上限 (Figma の案と同じ)。
const int _nameMax = 20;
const int _aboutMax = 150;

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _name = TextEditingController();

  /// ひとことは画面に出さなくなったが，保存で消さないように今の値をそのまま送る。
  final _oneWord = TextEditingController();
  final _affiliation = TextEditingController();
  final _about = TextEditingController();
  final _twitter = TextEditingController();
  final _github = TextEditingController();
  final _portfolio = TextEditingController();
  final _connpass = TextEditingController();
  final _search = TextEditingController();

  List<String> _tags = [];
  Map<String, String> _initial = const {};

  bool _isSaving = false;
  bool _isUploadingAvatar = false;
  bool _isUploadingCover = false;
  String? _localAvatarPath;
  String? _localCoverPath;

  /// 開いているカテゴリ (同時に 1 つだけ)。
  String? _openCategory;

  List<TextEditingController> get _fields => [
    _name,
    _oneWord,
    _affiliation,
    _about,
    _twitter,
    _github,
    _portfolio,
    _connpass,
  ];

  @override
  void initState() {
    super.initState();
    final user = ref.read(authNotifierProvider).value;
    if (user != null) {
      _load(user);
    } else {
      // まだ読み込み中なら，届いたときに 1 回だけ入れる (入力中の内容は上書きしない)。
      _initial = _snapshot();
      ref.listenManual(authNotifierProvider, (_, next) {
        final loaded = next.value;
        if (loaded != null && !_isDirty && _initial['name']!.isEmpty) {
          setState(() => _load(loaded));
        }
      });
    }
    for (final c in [..._fields, _search]) {
      c.addListener(_onChanged);
    }
  }

  void _load(UserModel user) {
    _name.text = user.name;
    _oneWord.text = user.oneWord;
    _affiliation.text = user.affiliation;
    _about.text = user.about;
    _twitter.text = _handleFrom(user.twitterUrl, const [
      'x.com/',
      'twitter.com/',
    ]);
    _github.text = _handleFrom(user.githubUrl, const ['github.com/']);
    _portfolio.text = user.portfolioUrl;
    _connpass.text = _handleFrom(user.connpassUrl, const [
      'connpass.com/user/',
    ]);
    _tags = TechTagCatalog.parse(user.techStack);
    _initial = _snapshot();
  }

  /// 「https://x.com/abc」のような URL を「abc」に直す。合わなければそのまま。
  static String _handleFrom(String raw, List<String> hosts) {
    var v = raw.trim();
    v = v.replaceFirst(RegExp(r'^https?://'), '').replaceFirst('www.', '');
    for (final host in hosts) {
      if (v.startsWith(host)) {
        v = v.substring(host.length);
        if (v.endsWith('/')) v = v.substring(0, v.length - 1);
        return v;
      }
    }
    return raw.trim().startsWith('@') ? raw.trim().substring(1) : raw.trim();
  }

  Map<String, String> _snapshot() => {
    'name': _name.text,
    'one_word': _oneWord.text,
    'affiliation': _affiliation.text,
    'about': _about.text,
    'tech_stack': TechTagCatalog.join(_tags),
    'twitter_url': _twitter.text.trim(),
    'github_url': _github.text.trim(),
    'portfolio_url': _portfolio.text.trim(),
    'connpass_username': _connpass.text.trim(),
  };

  bool get _isDirty {
    final now = _snapshot();
    return now.keys.any((k) => now[k] != _initial[k]);
  }

  bool get _isOverLimit =>
      _name.text.characters.length > _nameMax ||
      _about.text.characters.length > _aboutMax;

  bool get _canSave => _isDirty && !_isOverLimit && !_isSaving;

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    for (final c in [..._fields, _search]) {
      c.dispose();
    }
    super.dispose();
  }

  void _toggleTag(String tag) {
    setState(() {
      final normalized = TechTagCatalog.normalize(tag);
      if (_tags.contains(normalized)) {
        _tags = [..._tags]..remove(normalized);
      } else {
        _tags = [..._tags, normalized];
      }
    });
  }

  Future<void> _save() async {
    final user = ref.read(authNotifierProvider).value;
    if (user == null || !_canSave) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);
    try {
      final body = _snapshot();
      if (body['name']!.trim().isEmpty) body['name'] = '未設定';
      await ref.read(userRepositoryProvider).updateUser(user.id, body);
      await ref.read(authNotifierProvider.notifier).refresh();
      if (!mounted) return;
      _initial = _snapshot();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('プロフィールを保存しました'),
            duration: Duration(seconds: 1),
          ),
        );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('保存に失敗しました: $e'),
            backgroundColor: PasslyState.error,
          ),
        );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// 変更があるときは「保存せずに戻りますか？」を出す。
  Future<void> _close() async {
    if (!_isDirty) {
      context.pop();
      return;
    }
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('保存せずに戻りますか？'),
        content: const Text('変更した内容は消えます．'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('編集を続ける'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: PasslyState.error),
            child: const Text('保存せずに戻る'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) context.pop();
  }

  Future<void> _pickAndUploadAvatar() async {
    final user = ref.read(authNotifierProvider).value;
    if (user == null) return;
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;

    // 縦横比が違う画像でも，アイコンにしたい部分を選べるように調整画面を挟む。
    final croppedPath = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => AvatarCropScreen(imagePath: picked.path),
      ),
    );
    if (croppedPath == null || !mounted) return;

    setState(() {
      _localAvatarPath = croppedPath;
      _isUploadingAvatar = true;
    });
    try {
      await ref.read(userRepositoryProvider).uploadAvatar(user.id, croppedPath);
      await ref.read(authNotifierProvider.notifier).refresh();
    } catch (e) {
      _showError('画像のアップロードに失敗しました: $e');
    } finally {
      if (mounted) {
        setState(() {
          _localAvatarPath = null;
          _isUploadingAvatar = false;
        });
      }
    }
  }

  Future<void> _pickAndUploadCover() async {
    final user = ref.read(authNotifierProvider).value;
    if (user == null) return;
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;

    setState(() {
      _localCoverPath = picked.path;
      _isUploadingCover = true;
    });
    try {
      await ref.read(userRepositoryProvider).uploadCover(user.id, picked.path);
      await ref.read(authNotifierProvider.notifier).refresh();
    } catch (e) {
      _showError('カバー画像のアップロードに失敗しました: $e');
    } finally {
      if (mounted) {
        setState(() {
          _localCoverPath = null;
          _isUploadingCover = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), backgroundColor: PasslyState.error),
      );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).value;

    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: PasslyBg.defaultBg,
        body: Column(
          children: [
            _EditHeader(
              canSave: _canSave,
              isSaving: _isSaving,
              onCancel: _close,
              onSave: _save,
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  40 + MediaQuery.of(context).padding.bottom,
                ),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  _ImageEditor(
                    coverUrl: user?.coverUrl ?? '',
                    iconUrl: user?.iconUrl ?? '',
                    localCoverPath: _localCoverPath,
                    localAvatarPath: _localAvatarPath,
                    isUploadingCover: _isUploadingCover,
                    isUploadingAvatar: _isUploadingAvatar,
                    onEditCover: _pickAndUploadCover,
                    onEditAvatar: _pickAndUploadAvatar,
                  ),
                  const SizedBox(height: 12),
                  const _Heading('基本'),
                  _Card(
                    children: [
                      _LabeledField(
                        label: '名前',
                        controller: _name,
                        max: _nameMax,
                      ),
                      _LabeledField(
                        label: '所属',
                        controller: _affiliation,
                        hint: '例：愛知工業大学',
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const _Heading('自己紹介'),
                  _Card(
                    children: [
                      _LabeledField(
                        label: 'ABOUT',
                        controller: _about,
                        max: _aboutMax,
                        maxLines: 5,
                        hint: '好きな技術や，話しかけてほしいことなど',
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _Heading('TECH TAG', sub: '選んだタグ ${_tags.length}'),
                  _Card(
                    children: [
                      _TagSearchField(controller: _search),
                      if (_search.text.trim().isNotEmpty)
                        _SearchResults(
                          query: _search.text,
                          selected: _tags,
                          onToggle: _toggleTag,
                        ),
                      _SelectedTags(tags: _tags, onRemove: _toggleTag),
                      if (_search.text.trim().isEmpty)
                        _CategoryAccordion(
                          selected: _tags,
                          openCategory: _openCategory,
                          onOpen: (label) => setState(
                            () => _openCategory = _openCategory == label
                                ? null
                                : label,
                          ),
                          onToggle: _toggleTag,
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const _Heading('LINK'),
                  _Card(
                    children: [
                      _LabeledField(
                        label: 'X',
                        controller: _twitter,
                        prefix: 'x.com/',
                        hint: 'ユーザー名',
                      ),
                      _LabeledField(
                        label: 'GitHub',
                        controller: _github,
                        prefix: 'github.com/',
                        hint: 'ユーザー名',
                      ),
                      _LabeledField(
                        label: 'ポートフォリオ',
                        controller: _portfolio,
                        hint: 'https://',
                        keyboardType: TextInputType.url,
                      ),
                      _LabeledField(
                        label: 'connpass',
                        controller: _connpass,
                        prefix: 'connpass.com/user/',
                        hint: 'ユーザー名',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 上のバー: キャンセル / タイトル / 保存。
class _EditHeader extends StatelessWidget {
  final bool canSave;
  final bool isSaving;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  const _EditHeader({
    required this.canSave,
    required this.isSaving,
    required this.onCancel,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: PasslyBg.surface,
        border: Border(bottom: BorderSide(color: PasslyBorder.defaultBorder)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
          child: Row(
            children: [
              TextButton(
                onPressed: onCancel,
                style: TextButton.styleFrom(
                  foregroundColor: PasslyText.secondary,
                ),
                child: const Text(
                  'キャンセル',
                  style: TextStyle(
                    fontFamily: PasslyFont.family,
                    fontSize: 14,
                    fontWeight: PasslyFont.medium,
                  ),
                ),
              ),
              const Expanded(
                child: Text(
                  'プロフィールを編集',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: PasslyFont.family,
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              SizedBox(
                width: 72,
                height: 36,
                child: FilledButton(
                  onPressed: canSave ? onSave : null,
                  style: FilledButton.styleFrom(
                    padding: EdgeInsets.zero,
                    backgroundColor: PasslyBrand.primary,
                    disabledBackgroundColor: PasslyBorder.defaultBorder,
                    disabledForegroundColor: PasslyText.tertiary,
                    shape: const StadiumBorder(),
                  ),
                  child: Text(
                    isSaving ? '保存中' : '保存',
                    style: const TextStyle(
                      fontFamily: PasslyFont.family,
                      fontSize: 13,
                      fontWeight: PasslyFont.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// カバー画像 (右上に「カバーを変える」) + 半分重なるアイコン (右下にカメラ)。
class _ImageEditor extends StatelessWidget {
  final String coverUrl;
  final String iconUrl;
  final String? localCoverPath;
  final String? localAvatarPath;
  final bool isUploadingCover;
  final bool isUploadingAvatar;
  final VoidCallback onEditCover;
  final VoidCallback onEditAvatar;

  const _ImageEditor({
    required this.coverUrl,
    required this.iconUrl,
    required this.localCoverPath,
    required this.localAvatarPath,
    required this.isUploadingCover,
    required this.isUploadingAvatar,
    required this.onEditCover,
    required this.onEditAvatar,
  });

  static const double _coverHeight = 130;
  static const double _avatarSize = 92;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _coverHeight + _avatarSize / 2 + 10,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: _coverHeight,
            child: GestureDetector(
              onTap: onEditCover,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ProfileCoverImage(url: coverUrl, localPath: localCoverPath),
                    if (isUploadingCover) const _UploadingOverlay(),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: GestureDetector(
              onTap: onEditCover,
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.camera_alt, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'カバーを変える',
                      style: TextStyle(
                        fontFamily: PasslyFont.family,
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: PasslyFont.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: _coverHeight - _avatarSize / 2,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: onEditAvatar,
                child: SizedBox(
                  width: _avatarSize,
                  height: _avatarSize,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: ProfileAvatarCircle(
                          url: iconUrl,
                          localPath: localAvatarPath,
                        ),
                      ),
                      if (isUploadingAvatar)
                        const Positioned.fill(
                          child: ClipOval(child: _UploadingOverlay()),
                        ),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: PasslyBrand.primary,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UploadingOverlay extends StatelessWidget {
  const _UploadingOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black26,
      alignment: Alignment.center,
      child: const SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      ),
    );
  }
}

/// カードの上の見出し (「基本」「TECH TAG 選んだタグ 4」など)。
class _Heading extends StatelessWidget {
  final String text;
  final String? sub;

  const _Heading(this.text, {this.sub});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            text,
            style: const TextStyle(
              fontFamily: PasslyFont.family,
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (sub != null) ...[
            const SizedBox(width: 8),
            Text(
              sub!,
              style: const TextStyle(
                fontFamily: PasslyFont.family,
                color: PasslyBrand.primary,
                fontSize: 11,
                fontWeight: PasslyFont.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 白い角丸カード。中身の間は 14 空ける。
class _Card extends StatelessWidget {
  final List<Widget> children;

  const _Card({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PasslyBg.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: PasslyBorder.defaultBorder, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// ラベル (+ 文字数) つきの入力欄。前に「x.com/」などを付けられる。
class _LabeledField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final int? max;
  final String? hint;
  final String? prefix;
  final int maxLines;
  final TextInputType? keyboardType;

  const _LabeledField({
    required this.label,
    required this.controller,
    this.max,
    this.hint,
    this.prefix,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    final length = controller.text.characters.length;
    final over = max != null && length > max!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: PasslyFont.family,
                  color: Color(0xFF374151),
                  fontSize: 12,
                  fontWeight: PasslyFont.bold,
                ),
              ),
            ),
            if (max != null)
              Text(
                '$length / $max',
                style: TextStyle(
                  fontFamily: PasslyFont.family,
                  color: over ? PasslyState.error : PasslyText.tertiary,
                  fontSize: 11,
                  fontWeight: over ? PasslyFont.bold : PasslyFont.regular,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          minLines: maxLines > 1 ? 3 : 1,
          keyboardType:
              keyboardType ??
              (maxLines > 1 ? TextInputType.multiline : TextInputType.text),
          style: const TextStyle(
            fontFamily: PasslyFont.family,
            color: AppColors.textPrimary,
            fontSize: 14,
            height: 1.6,
          ),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: PasslyBg.defaultBg,
            hintText: hint,
            hintStyle: const TextStyle(
              fontFamily: PasslyFont.family,
              color: PasslyText.tertiary,
              fontSize: 14,
            ),
            // prefixText は入力中しか出ないので，常に見えるよう prefixIcon で置く。
            prefixIcon: prefix == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(left: 14, right: 2),
                    child: Text(
                      prefix!,
                      style: const TextStyle(
                        fontFamily: PasslyFont.family,
                        color: PasslyText.tertiary,
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                  ),
            prefixIconConstraints: const BoxConstraints(),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: over
                  ? const BorderSide(color: PasslyState.error)
                  : BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: over ? PasslyState.error : PasslyBrand.primary,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// タグの検索欄。入力中は枠が緑になり，右に消すボタンが出る。
class _TagSearchField extends StatelessWidget {
  final TextEditingController controller;

  const _TagSearchField({required this.controller});

  @override
  Widget build(BuildContext context) {
    final hasText = controller.text.isNotEmpty;
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      style: const TextStyle(
        fontFamily: PasslyFont.family,
        color: AppColors.textPrimary,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: hasText ? PasslyBg.surface : PasslyBg.defaultBg,
        hintText: 'タグを探す（例：React，Go）',
        hintStyle: const TextStyle(
          fontFamily: PasslyFont.family,
          color: PasslyText.tertiary,
          fontSize: 14,
        ),
        prefixIcon: Icon(
          Icons.search,
          size: 20,
          color: hasText ? PasslyBrand.primary : PasslyText.tertiary,
        ),
        suffixIcon: hasText
            ? IconButton(
                onPressed: controller.clear,
                icon: const Icon(Icons.close, size: 18),
                color: PasslyText.tertiary,
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: hasText
              ? const BorderSide(color: PasslyBrand.primary, width: 1.5)
              : BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: PasslyBrand.primary, width: 1.5),
        ),
      ),
    );
  }
}

/// 検索結果。タグ名・カテゴリ・「＋追加」か「選択済み」。
class _SearchResults extends StatelessWidget {
  final String query;
  final List<String> selected;
  final ValueChanged<String> onToggle;

  const _SearchResults({
    required this.query,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final results = TechTagCatalog.search(query);
    if (results.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          '見つかりませんでした．別の書き方でも探してみてください',
          style: TextStyle(
            fontFamily: PasslyFont.family,
            color: PasslyText.secondary,
            fontSize: 12,
          ),
        ),
      );
    }
    return Column(
      children: [
        for (int i = 0; i < results.length; i++)
          _ResultRow(
            tag: results[i],
            category: TechTagCatalog.categoryOf(results[i]) ?? '',
            isSelected: selected.contains(results[i]),
            showDivider: i < results.length - 1,
            onTap: () => onToggle(results[i]),
          ),
      ],
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String tag;
  final String category;
  final bool isSelected;
  final bool showDivider;
  final VoidCallback onTap;

  const _ResultRow({
    required this.tag,
    required this.category,
    required this.isSelected,
    required this.showDivider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: showDivider
              ? const Border(bottom: BorderSide(color: PasslyBorder.divider))
              : null,
        ),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, right: 14),
              child: TagSticker(tag: tag, size: 30, tilt: false),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tag,
                    style: const TextStyle(
                      fontFamily: PasslyFont.family,
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: PasslyFont.bold,
                    ),
                  ),
                  if (category.isNotEmpty)
                    Text(
                      category,
                      style: const TextStyle(
                        fontFamily: PasslyFont.family,
                        color: PasslyText.tertiary,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
              decoration: BoxDecoration(
                color: isSelected ? PasslyBrand.primary : PasslyBg.surface,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: PasslyBrand.primary, width: 1.2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isSelected ? Icons.check : Icons.add,
                    size: 14,
                    color: isSelected ? Colors.white : PasslyBrand.primaryDark,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isSelected ? '選択済み' : '追加',
                    style: TextStyle(
                      fontFamily: PasslyFont.family,
                      color: isSelected
                          ? Colors.white
                          : PasslyBrand.primaryDark,
                      fontSize: 12,
                      fontWeight: PasslyFont.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 選んだタグ。ステッカーで並べ，右上の×で外す。
class _SelectedTags extends StatelessWidget {
  final List<String> tags;
  final ValueChanged<String> onRemove;

  const _SelectedTags({required this.tags, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) {
      return const Text(
        'まだタグがありません．検索かカテゴリから選んでください',
        style: TextStyle(
          fontFamily: PasslyFont.family,
          color: PasslyText.secondary,
          fontSize: 12,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6, left: 2),
          child: Wrap(
            spacing: 6,
            runSpacing: 12,
            children: [
              for (final tag in tags)
                LabeledTagSticker(
                  key: ValueKey(tag),
                  tag: tag,
                  onRemove: () => onRemove(tag),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '右上の×で外せます．',
          style: TextStyle(
            fontFamily: PasslyFont.family,
            color: PasslyText.secondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

/// カテゴリから選ぶ。押すとその場で開き，中のタグを選べる。
/// 閉じているときは，そのカテゴリで選んでいるタグを右に緑で出す。
class _CategoryAccordion extends StatelessWidget {
  final List<String> selected;
  final String? openCategory;
  final ValueChanged<String> onOpen;
  final ValueChanged<String> onToggle;

  const _CategoryAccordion({
    required this.selected,
    required this.openCategory,
    required this.onOpen,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    const categories = TechTagCatalog.categories;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'カテゴリから選ぶ',
          style: TextStyle(
            fontFamily: PasslyFont.family,
            color: Color(0xFF374151),
            fontSize: 12,
            fontWeight: PasslyFont.bold,
          ),
        ),
        for (int i = 0; i < categories.length; i++)
          _CategoryRow(
            category: categories[i],
            selected: selected,
            isOpen: openCategory == categories[i].label,
            showDivider: i < categories.length - 1,
            onOpen: () => onOpen(categories[i].label),
            onToggle: onToggle,
          ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final TechTagCategory category;
  final List<String> selected;
  final bool isOpen;
  final bool showDivider;
  final VoidCallback onOpen;
  final ValueChanged<String> onToggle;

  const _CategoryRow({
    required this.category,
    required this.selected,
    required this.isOpen,
    required this.showDivider,
    required this.onOpen,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final picked = category.tags.where(selected.contains).toList();
    return Container(
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: PasslyBorder.divider))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Text(
                    category.label,
                    style: const TextStyle(
                      fontFamily: PasslyFont.family,
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: PasslyFont.medium,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      picked.join('，'),
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: PasslyFont.family,
                        color: PasslyBrand.primary,
                        fontSize: 12,
                        fontWeight: PasslyFont.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    isOpen ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: PasslyText.tertiary,
                  ),
                ],
              ),
            ),
          ),
          if (isOpen)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.only(top: 6, left: 2),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 12,
                  children: [
                    for (final tag in category.tags)
                      LabeledTagSticker(
                        tag: tag,
                        size: 40,
                        same: selected.contains(tag),
                        dimmed: !selected.contains(tag),
                        onTap: () => onToggle(tag),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
