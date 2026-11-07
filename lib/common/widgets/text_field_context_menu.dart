import 'package:flutter/material.dart';

/// 文字入力欄の長押しメニュー（コピー・ペーストなど）。
///
/// Flutter は iOS 16 以降で iOS 純正のメニュー（SystemContextMenu）を使うが，
/// 入力欄をいくつも切り替えて触ると，前の欄のメニューが消えきらないうちに
/// 次の欄のメニューを出そうとして「Attempted to show while another instance
/// was still visible.」で止まることがある。
/// アプリの入力欄はこれを使い，Flutter が描くメニューに統一する。
Widget passlyContextMenuBuilder(
  BuildContext context,
  EditableTextState editableTextState,
) {
  return AdaptiveTextSelectionToolbar.editableText(
    editableTextState: editableTextState,
  );
}
