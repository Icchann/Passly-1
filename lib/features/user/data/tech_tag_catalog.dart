/// マイページの TECH TAG 編集で提示する事前定義タグ集。
///
/// 自由入力を廃止し、この一覧から選ぶ運用にすると:
/// - 表記揺れ (Flutter / flutter / FLUTTER) が防げる
/// - 将来的に「同じタグを持つ人」検索が組みやすい
/// - ユーザーが「何を書けばいいか」で迷わない
///
/// 将来的に追加要望があればここに足す。
class TechTagCatalog {
  /// カテゴリー付き一覧。表示順はこの順。
  static const List<TechTagCategory> categories = [
    TechTagCategory('言語', [
      'Dart',
      'Go',
      'Python',
      'JavaScript',
      'TypeScript',
      'Kotlin',
      'Swift',
      'Java',
      'Ruby',
      'PHP',
      'Rust',
      'C++',
      'C#',
    ]),
    TechTagCategory('フロントエンド', [
      'React',
      'Vue',
      'Angular',
      'Next.js',
      'Nuxt',
      'Svelte',
      'Tailwind',
    ]),
    TechTagCategory('モバイル', ['Flutter', 'React Native', 'iOS', 'Android']),
    TechTagCategory('バックエンド', [
      'Node.js',
      'Express',
      'Django',
      'Rails',
      'Spring',
      'Laravel',
      'Fastify',
    ]),
    TechTagCategory('インフラ / クラウド', [
      'AWS',
      'GCP',
      'Azure',
      'Firebase',
      'Docker',
      'Kubernetes',
      'Terraform',
    ]),
    TechTagCategory('データベース', [
      'PostgreSQL',
      'MySQL',
      'MongoDB',
      'Redis',
      'SQLite',
    ]),
    TechTagCategory('デザイン', ['Figma', 'Adobe XD', 'Photoshop', 'Illustrator']),
    TechTagCategory('その他', ['Git', 'GitHub', 'GitLab', 'Linux', 'VSCode']),
  ];

  /// フラットな全タグ (ルックアップや正規化用)。
  static final List<String> allTags = [for (final c in categories) ...c.tags];

  /// 保存されている tech_stack の文字列をタグの一覧にする。
  ///
  /// 区切りはカンマ・読点・スラッシュ・中黒。空白は「React Native」のように
  /// カタログに空白入りのタグがあるため，カタログにない語だけ空白でも分ける
  /// (昔の「Go Flutter」のような空白区切りの入力にも対応)。
  /// カタログ内のタグは正式表記に直し，重複は除く。
  static List<String> parse(String raw) {
    if (raw.trim().isEmpty) return const [];
    final result = <String>[];
    for (final piece in raw.split(RegExp(r'[,、/／・]+'))) {
      final trimmed = piece.trim();
      if (trimmed.isEmpty) continue;
      final normalized = normalize(trimmed);
      final words = allTags.contains(normalized)
          ? [normalized]
          : trimmed.split(RegExp(r'\s+')).map(normalize);
      for (final w in words) {
        if (w.isNotEmpty && !result.contains(w)) result.add(w);
      }
    }
    return result;
  }

  /// タグの一覧を tech_stack の文字列に戻す (カンマ区切り)。
  static String join(Iterable<String> tags) => tags.join(', ');

  /// 検索用。名前の一部 (大文字小文字は無視) に合うカタログのタグを返す。
  static List<String> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final starts = <String>[];
    final contains = <String>[];
    for (final tag in allTags) {
      final lower = tag.toLowerCase();
      if (lower.startsWith(q)) {
        starts.add(tag);
      } else if (lower.contains(q)) {
        contains.add(tag);
      }
    }
    return [...starts, ...contains];
  }

  /// タグが入っているカテゴリ名 (カタログにないタグは null)。
  static String? categoryOf(String tag) {
    for (final c in categories) {
      if (c.tags.contains(tag)) return c.label;
    }
    return null;
  }

  /// 大文字小文字を無視して事前定義タグにマッチさせる。
  /// カタログ内での正式表記に正規化して返す (見つからなければそのまま返す)。
  static String normalize(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return trimmed;
    final lower = trimmed.toLowerCase();
    for (final tag in allTags) {
      if (tag.toLowerCase() == lower) return tag;
    }
    return trimmed;
  }
}

class TechTagCategory {
  final String label;
  final List<String> tags;

  const TechTagCategory(this.label, this.tags);
}
