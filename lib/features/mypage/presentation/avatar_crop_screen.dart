import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// アバター画像の位置・拡大率を調整するための画面。
///
/// 画像を正方形の枠内でピンチ拡大縮小・ドラッグ移動でき、「決定」を押すと
/// その時点で枠内に見えている部分だけを切り出した PNG ファイルのパスを返す。
/// 呼び出し側は `Navigator.push<String>` の戻り値をアップロード対象として扱う。
/// キャンセル(戻る操作)の場合は null が返る。
class AvatarCropScreen extends StatefulWidget {
  final String imagePath;
  const AvatarCropScreen({super.key, required this.imagePath});

  @override
  State<AvatarCropScreen> createState() => _AvatarCropScreenState();
}

class _AvatarCropScreenState extends State<AvatarCropScreen> {
  // 説明テキストや余白など、正方形の調整エリア以外に使うおおよその縦幅。
  static const double _chromeHeight = 96;
  static const double _minViewportSize = 200;

  /// 切り出したアイコン画像の一辺（px）。
  static const double _outputSize = 512;

  final GlobalKey _boundaryKey = GlobalKey();
  final TransformationController _controller = TransformationController();

  Size? _imageSize;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadImageSize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadImageSize() async {
    try {
      final bytes = await File(widget.imagePath).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final width = frame.image.width.toDouble();
      final height = frame.image.height.toDouble();
      frame.image.dispose();
      if (!mounted) return;
      setState(() => _imageSize = Size(width, height));
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = '画像の読み込みに失敗しました: $e');
    }
  }

  /// 調整エリア(正方形)の一辺の長さを、画面サイズいっぱいに使えるように計算する。
  /// 横幅は画面幅ぎりぎりまで、縦は AppBar・説明文などを差し引いた残りの高さまで
  /// 使い、正方形を保つためにそのうち小さい方を採用する。
  double _computeViewportSize(BuildContext context) {
    final media = MediaQuery.of(context);
    final availableHeight =
        media.size.height -
        kToolbarHeight -
        media.padding.top -
        media.padding.bottom -
        _chromeHeight;
    final size = math.min(media.size.width, availableHeight);
    return size.clamp(_minViewportSize, media.size.width);
  }

  Future<void> _confirm() async {
    setState(() => _isSaving = true);
    try {
      final boundary =
          _boundaryKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      // 画面の解像度のまま切り出すと 1700px 四方ほどの PNG になり，写真だと
      // 数 MB になってサーバーに断られる（400）ので，アイコンに十分な大きさにそろえる。
      final viewportSize = boundary.size.width;
      final image = await boundary.toImage(
        pixelRatio: _outputSize / viewportSize,
      );
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) {
        throw Exception('画像データの生成に失敗しました');
      }
      final bytes = byteData.buffer.asUint8List();

      final outPath =
          '${Directory.systemTemp.path}/avatar_crop_${DateTime.now().millisecondsSinceEpoch}.png';
      final outFile = File(outPath);
      await outFile.writeAsBytes(bytes);

      if (!mounted) return;
      Navigator.of(context).pop(outPath);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = '画像の切り抜きに失敗しました: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = _imageSize != null;
    final viewportSize = _computeViewportSize(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('アイコン画像の位置を調整'),
        actions: [
          TextButton(
            onPressed: (!ready || _isSaving) ? null : _confirm,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    '決定',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
      body: Center(
        child: !ready
            ? (_errorMessage != null
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ))
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: viewportSize,
                    height: viewportSize,
                    child: Stack(
                      children: [
                        RepaintBoundary(
                          key: _boundaryKey,
                          child: ClipRect(
                            child: InteractiveViewer(
                              transformationController: _controller,
                              minScale: 1.0,
                              maxScale: 6,
                              boundaryMargin: EdgeInsets.zero,
                              child: SizedBox(
                                width: viewportSize,
                                height: viewportSize,
                                child: Image.file(
                                  File(widget.imagePath),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        ),
                        IgnorePointer(
                          child: CustomPaint(
                            size: Size(viewportSize, viewportSize),
                            painter: _CircleGuidePainter(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'ピンチで拡大縮小、ドラッグで位置を調整できます',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

/// 正方形の枠の中に、実際にアイコンとして円形表示される範囲のガイドを描く。
/// (円の外側を少し暗くし、円周に白線を引くだけの見た目上の補助であり、
/// この描画自体は RepaintBoundary の外側にあるため切り出し画像には含まれない)
class _CircleGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()..color = Colors.black.withValues(alpha: 0.5);
    final fullRectPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final circlePath = Path()
      ..addOval(
        Rect.fromCircle(
          center: size.center(Offset.zero),
          radius: size.width / 2,
        ),
      );
    final overlayPath = Path.combine(
      PathOperation.difference,
      fullRectPath,
      circlePath,
    );
    canvas.drawPath(overlayPath, overlayPaint);

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(size.center(Offset.zero), size.width / 2, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _CircleGuidePainter oldDelegate) => false;
}
