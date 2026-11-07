/// バックエンド未実装 API 向けのモック実装切替フラグ。
///
/// サーバー側の実装が完了して疎通確認が取れたら、対応するフラグを false にする。
abstract final class FeatureFlags {
  /// close_friends 3 本の API（追加 / 解除 / 一覧）にモック実装を使う。
  /// 2026-09-14 にバックエンド側の実装が入ったため実 API に切替済み。
  static const bool useMockCloseFriends = false;

  /// GET /events/:id（イベント詳細と参加者一覧）にモック実装を使う。
  /// 2026-11-06 にバックエンドが connpass v2 から 1 件取る実装になったため実 API に切替。
  /// 参加者一覧は connpass から取れないため空で返る。
  static const bool useMockEventDetail = false;

  /// デモ動画用。`--dart-define=DEMO_MODE=true` で起動したときだけ true。
  /// サーバーへは通信せず、lib/demo/ のダミーデータで動く（ログインも不要）。
  static const bool demoMode = bool.fromEnvironment('DEMO_MODE');
}
