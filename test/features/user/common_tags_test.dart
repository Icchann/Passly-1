import 'package:flutter_test/flutter_test.dart';
import 'package:passly/features/user/domain/common_tags.dart';

void main() {
  group('parseTechTags', () {
    test('カンマ・スラッシュ・中点・空白で区切る', () {
      expect(parseTechTags('Flutter, Go / Figma・AWS  Dart'), [
        'Flutter',
        'Go',
        'Figma',
        'AWS',
        'Dart',
      ]);
    });

    test('React Native のように空白を含むタグは分けない', () {
      expect(parseTechTags('React Native, Flutter, Adobe XD'), [
        'React Native',
        'Flutter',
        'Adobe XD',
      ]);
    });

    test('カタログの表記にそろえ，重複は除く', () {
      expect(parseTechTags('flutter, Flutter, figma'), ['Flutter', 'Figma']);
    });

    test('空文字は空配列', () {
      expect(parseTechTags('  '), isEmpty);
    });
  });

  group('commonTechTags', () {
    test('大文字小文字を無視して相手側の順で返す', () {
      expect(commonTechTags('go,flutter,Figma', 'Figma,Go,Kotlin'), [
        'Figma',
        'Go',
      ]);
    });

    test('どちらかが空なら空', () {
      expect(commonTechTags('', 'Go'), isEmpty);
      expect(commonTechTags('Go', ''), isEmpty);
    });
  });

  group('pickMostCommon', () {
    test('共通タグが一番多い人を選び，同数なら先の人を選ぶ', () {
      final tags = {
        'a': ['Go'],
        'b': ['Go', 'Flutter'],
        'c': ['Figma', 'AWS'],
      };
      expect(pickMostCommon(['a', 'b', 'c'], (id) => tags[id]!), 'b');
    });

    test('誰も共通タグがなければ null', () {
      expect(pickMostCommon(['a'], (_) => const <String>[]), isNull);
    });
  });
}
