import 'package:flutter_test/flutter_test.dart';
import 'package:passly/features/auth/domain/connpass_username.dart';

void main() {
  test('takes the username out of every way people paste it', () {
    for (final input in [
      'passly_taro',
      ' passly_taro ',
      '(passly_taro)',
      '（passly_taro）',
      '@passly_taro',
      'https://connpass.com/user/passly_taro/',
      'connpass.com/user/passly_taro',
      'https://www.connpass.com/user/passly_taro/?ref=x',
    ]) {
      expect(connpassUsernameFrom(input), 'passly_taro', reason: input);
    }
  });

  test('empty stays empty', () {
    expect(connpassUsernameFrom(''), '');
    expect(connpassUsernameFrom('   '), '');
  });
}
