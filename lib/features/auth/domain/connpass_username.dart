/// connpass の欄に入力されたものから，ユーザー名だけを取り出す。
///
/// 「passly_taro」「(passly_taro)」「@passly_taro」
/// 「https://connpass.com/user/passly_taro/」のどれでも「passly_taro」を返す。
String connpassUsernameFrom(String raw) {
  var v = raw.trim();
  if (v.isEmpty) return '';
  v = v.replaceFirst(RegExp(r'^https?://', caseSensitive: false), '');
  v = v.replaceFirst(RegExp(r'^www\.', caseSensitive: false), '');
  final userPath = RegExp(
    r'^connpass\.com/user/([^/?#]+)',
    caseSensitive: false,
  ).firstMatch(v);
  if (userPath != null) return userPath.group(1)!;
  // プロフィールに出ている (passly_taro) をそのまま写した場合
  v = v.replaceAll(RegExp(r'^[(（\s]+|[)）\s]+$'), '');
  if (v.startsWith('@')) v = v.substring(1);
  return v.trim();
}
