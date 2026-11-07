import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passly/core/network/dio_client.dart';

class _CountingStorage extends FlutterSecureStorage {
  int reads = 0;
  String? value = 'saved-token';

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    reads++;
    return value;
  }
}

void main() {
  test('reads the storage once and then uses the copy in memory', () async {
    AuthTokenCache.forget();
    final storage = _CountingStorage();
    expect(await AuthTokenCache.read(storage), 'saved-token');
    expect(await AuthTokenCache.read(storage), 'saved-token');
    expect(storage.reads, 1);
  });

  test('login and logout update the copy without reading storage', () async {
    AuthTokenCache.forget();
    final storage = _CountingStorage();
    AuthTokenCache.set('new-token');
    expect(await AuthTokenCache.read(storage), 'new-token');
    AuthTokenCache.clear();
    expect(await AuthTokenCache.read(storage), isNull);
    expect(storage.reads, 0);
  });
}
