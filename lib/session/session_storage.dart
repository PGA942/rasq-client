import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Key/value secret storage abstraction (tokens never leave the device).
abstract class SessionStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// RASQ アカウントにログインする前の SNS のセッションを、ログインした先とは別に持っている保存先 (D-461。Web 版の保管庫
/// `CentralVaultSessionStorage`: ログイン前のぶんはメモリにだけある)。
abstract interface class PreLoginSessionsHolder {
  /// 既存の RASQ アカウントへのログインの直前に呼ぶ: ログイン前のぶんのうち [keep](`AccountId.key`)だけを残し、ほかは
  /// 捨てる。残したぶんだけが、ログインした先の保管庫へ預けられる(本人が「加える」を選んだもの)。
  void keepPreLogin(Set<String> keep);
}

class SecureSessionStorage implements SessionStorage {
  SecureSessionStorage([FlutterSecureStorage? storage])
      : _s = storage ??
            const FlutterSecureStorage(
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
              // macOS: the data-protection keychain needs the keychain-access-groups
              // entitlement (= development-certificate signing). Use the legacy
              // file keychain so locally signed dev builds work out of the box.
              mOptions: MacOsOptions(accessibility: KeychainAccessibility.first_unlock_this_device, usesDataProtectionKeychain: false),
            );
  final FlutterSecureStorage _s;

  @override
  Future<String?> read(String key) => _s.read(key: key);
  @override
  Future<void> write(String key, String value) => _s.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _s.delete(key: key);
}

/// In-memory storage for tests / previews.
class MemorySessionStorage implements SessionStorage {
  MemorySessionStorage([Map<String, String>? seed]) : _m = {...?seed};
  final Map<String, String> _m;

  /// テスト用: 保存済みキー一覧。
  Iterable<String> get keys => _m.keys;
  @override
  Future<String?> read(String key) async => _m[key];
  @override
  Future<void> write(String key, String value) async => _m[key] = value;
  @override
  Future<void> delete(String key) async => _m.remove(key);
}
