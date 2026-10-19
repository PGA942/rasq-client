import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';
import 'package:test/test.dart';

/// マニフェストの文の言語 (D-484 / 契約 v0.24 PROTOCOL §4.6): タグ → 親のタグ → 素の欄。
void main() {
  tearDown(() => RasqUiLocale.tag = RasqUiLocale.defaultTag);

  final json = <String, Object?>{
    'id': 'sample.like',
    'name': 'いいねボタン',
    'version': '1.0.0',
    'kind': 'action',
    'description': '投稿にいいね',
    'termsOfService': '規約',
    'defaultLocale': 'ja',
    'actions': [
      {'id': 'like', 'genreTag': 'Reaction', 'label': 'いいね'},
    ],
    'locales': {
      'en': {
        'name': 'Like button',
        'actions': {
          'like': {'label': 'Like'},
        },
      },
      'zh-Hant': {'name': '按讚按鈕'},
      'zh-Hant-TW': {'description': '台灣的說明'},
    },
  };

  test('既定(ja)は素の欄。locales の無い古いマニフェストは今までどおり', () {
    final m = PluginManifest.fromJson(json);
    expect(m.name, 'いいねボタン');
    expect(m.description, '投稿にいいね');
    expect(m.actions.single.label, 'いいね');
    final old = PluginManifest.fromJson({...json}..remove('locales')..remove('defaultLocale'));
    expect(old.locales.isEmpty, isTrue);
    expect(old.toJson().containsKey('locales'), isFalse);
  });

  test('表示の言語で引く: en-US → en、書いていない欄は素の欄', () {
    final m = PluginManifest.fromJson(json);
    RasqUiLocale.tag = 'en-US';
    expect(m.name, 'Like button');
    expect(m.description, '投稿にいいね');
    expect(m.termsOfService, '規約');
    expect(m.actions.single.label, 'Like');
    expect(m.baseName, 'いいねボタン');
  });

  test('zh-Hant-TW → zh-Hant → zh(大文字小文字と _ は区別しない)', () {
    final m = PluginManifest.fromJson(json);
    RasqUiLocale.tag = 'zh-Hant-TW';
    expect(m.name, '按讚按鈕');
    expect(m.description, '台灣的說明');
    expect(m.locales.field('name', 'ZH_hant_hk'), '按讚按鈕');
    expect(m.locales.field('name', 'zh'), isNull);
    expect(ManifestLocales.candidates('zh-Hant-TW'), ['zh-hant-tw', 'zh-hant', 'zh']);
  });

  test('toJson は素の欄と locales を保つ(読み直しても同じ)', () {
    final again = PluginManifest.fromJson(PluginManifest.fromJson(json).toJson());
    RasqUiLocale.tag = 'en';
    expect(again.name, 'Like button');
    expect(again.toJson()['name'], 'いいねボタン');
  });

  test('assets のラベル', () {
    final l = ManifestLocales.fromManifest({
      'locales': {
        'en': {
          'assets': {
            'cat': {'label': 'Cat'},
          },
        },
      },
    });
    expect(l.assetLabel('cat', 'en-GB'), 'Cat');
    expect(l.assetLabel('cat', 'ja'), isNull);
  });
}
