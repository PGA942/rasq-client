import 'dart:convert';

import 'miauth.dart';

/// Misskey プラグインの設定第二階層ページ (D-044, rasq.settings-page/1)。
///
/// - `account`  … source: remote — `i` / `i/update` に読み書き(サーバー保存)。プロフィールの文字(名前・
///   自己紹介・場所・誕生日)、公開範囲、フォロー / フォロワー一覧の公開範囲、Bot / Cat (D-482)
/// - `timeline` … ローカル保存 — [MisskeySession.applySettings] で TL 取得
///   パラメーター(withRenotes / withReplies)に反映
/// - `safety`   … ローカル保存 — ホストが投稿タイルの閲覧注意メディア/CW の
///   表示に適用する
/// - `security` … 表示のみ — MiAuth で許可した権限の一覧と web 版への誘導
///   (`on: {"tap": "web.open"}`、`k` = インスタンス上のパス)
List<String> misskeySettingsPages() => [
      jsonEncode(_account),
      jsonEncode(_timeline),
      jsonEncode(_safety),
      jsonEncode(_security),
    ];

Map<String, Object?> _switch(String k, String title, {String? subtitle}) => {
      't': 'SwitchListTile',
      'k': k,
      'p': {'title': title, 'subtitle': ?subtitle, 'value': r'$.settings.' + k},
      'on': {'change': 'settings.set'},
    };

Map<String, Object?> _radio(String k, Object value, String title, {String? subtitle}) => {
      't': 'RadioListTile',
      'k': k,
      'p': {'title': title, 'subtitle': ?subtitle, 'value': value, 'group': r'$.settings.' + k},
      'on': {'change': 'settings.set'},
    };

Map<String, Object?> _webLink(String path, String title, {String? subtitle}) => {
      't': 'ListTile',
      'k': path,
      'p': {'title': title, 'subtitle': ?subtitle},
      'on': {'tap': 'web.open'},
    };

/// 文字の設定(名前・自己紹介など)。「保存」で `settings.set`(payload.text、D-482)。
Map<String, Object?> _input(String k, String label, int maxLength, {bool multiline = false}) => {
      't': 'Input',
      'k': k,
      'p': {'label': label, 'value': r'$.settings.' + k, 'maxLength': maxLength, 'multiline': multiline, 'submitLabel': '保存', 'clearOnSubmit': false, 'allowEmpty': true, 'pad': 16},
      'on': {'submit': 'settings.set'},
    };

const _visibilities = [('public', '公開'), ('followers', 'フォロワーだけ'), ('private', '非公開')];

final Map<String, Object?> _account = {
  'schema': 'rasq.settings-page/1',
  'area': 'account',
  'title': 'アカウント',
  'source': 'remote',
  'defaults': MisskeyAccountSettings.defaults,
  'root': {
    't': 'Column',
    'c': [
      {'t': 'SectionHeader', 'p': {'title': 'プロフィール'}},
      _input('name', '名前', 50),
      _input('description', '自己紹介', 1500, multiline: true),
      _input('location', '場所', 50),
      _input('birthday', '誕生日(例: 2000-01-31)', 10),
      _webLink('settings/profile', 'アイコン・バナー・補足情報', subtitle: 'web 版で編集します'),
      {'t': 'SectionHeader', 'p': {'title': '公開範囲'}},
      _switch('isLocked', 'フォローを承認制にする', subtitle: 'フォローされる前にあなたの承認が必要になります'),
      _switch('autoAcceptFollowed', 'フォロー中の人からのフォローは自動で承認'),
      _switch('isExplorable', 'アカウントを見つけやすくする', subtitle: '「みつける」やユーザー検索に表示されます'),
      _switch('hideOnlineStatus', 'オンライン状態を隠す'),
      _switch('publicReactions', 'リアクション一覧を公開する'),
      _switch('noCrawle', '検索エンジンに載せない', subtitle: '検索エンジンによるインデックスを避けるよう求めます'),
      {'t': 'SectionHeader', 'p': {'title': 'フォローの一覧を見せる相手'}},
      for (final (v, label) in _visibilities) _radio('followingVisibility', v, label),
      {'t': 'SectionHeader', 'p': {'title': 'フォロワーの一覧を見せる相手'}},
      for (final (v, label) in _visibilities) _radio('followersVisibility', v, label),
      {'t': 'SectionHeader', 'p': {'title': 'アカウントの種類'}},
      _switch('isBot', 'Botとして設定'),
      _switch('isCat', 'Catにする', subtitle: '発言が Cat 語になり、猫耳が付きます'),
      {'t': 'Text', 'p': {'text': 'これらの設定は接続先の Misskey サーバーに保存されます。', 'pad': 16}},
    ],
  },
};

/// `account` ページ (source: remote) のキーと値の形(`i` / `i/update`、D-044 / D-482)。
/// 画面のキーはここに無いと書けない(許可リスト)。
abstract final class MisskeyAccountSettings {
  static const boolKeys = ['isLocked', 'autoAcceptFollowed', 'isExplorable', 'hideOnlineStatus', 'publicReactions', 'noCrawle', 'isBot', 'isCat'];
  static const textKeys = ['name', 'description', 'location', 'birthday'];
  static const visibilityKeys = ['followingVisibility', 'followersVisibility'];
  static const visibilities = ['public', 'followers', 'private'];

  static const Map<String, Object?> defaults = {
    'name': '', 'description': '', 'location': '', 'birthday': '', //
    'isLocked': false, 'autoAcceptFollowed': true, 'isExplorable': true, 'hideOnlineStatus': false,
    'publicReactions': true, 'noCrawle': false, 'followingVisibility': 'public', 'followersVisibility': 'public',
    'isBot': false, 'isCat': false,
  };

  /// `i` → 画面の値。古いサーバー(2023.12 より前)はフォロー / フォロワーの公開範囲を `ffVisibility` 1 つで持つ。
  static Map<String, Object?> read(Map<String, Object?> i) => {
        for (final k in boolKeys) k: i[k] is bool ? i[k] : defaults[k],
        for (final k in textKeys) k: i[k] is String ? i[k] : '',
        for (final k in visibilityKeys) k: i[k] as String? ?? i['ffVisibility'] as String? ?? 'public',
      };

  /// 1 キーを `i/update` の本文に。許可リストに無いキーは [UnsupportedError]、形の違う値は [ArgumentError]。
  static Map<String, Object?> update(String key, Object? value) {
    if (boolKeys.contains(key)) {
      if (value is! bool) throw ArgumentError.value(value, key, '値は true / false です');
      return {key: value};
    }
    if (textKeys.contains(key)) {
      final s = '${value ?? ''}'.trim();
      if (key == 'birthday' && s.isNotEmpty && !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s)) {
        throw ArgumentError.value(value, key, '誕生日は 2000-01-31 の形で入れてください');
      }
      // 名前・場所・誕生日は空 = 消す(null)。
      return {key: s.isEmpty && key != 'description' ? null : s};
    }
    if (visibilityKeys.contains(key)) {
      if (!visibilities.contains(value)) throw ArgumentError.value(value, key, '公開範囲は public / followers / private です');
      return {key: value};
    }
    throw UnsupportedError('unknown remote setting: account.$key');
  }
}

final Map<String, Object?> _timeline = {
  'schema': 'rasq.settings-page/1',
  'area': 'timeline',
  'title': 'タイムライン',
  'defaults': {'withRenotes': true, 'withReplies': false},
  'root': {
    't': 'Column',
    'c': [
      {'t': 'SectionHeader', 'p': {'title': '表示する投稿'}},
      _switch('withRenotes', 'リノートを表示', subtitle: 'オフにすると引用のないリノートを取得しません'),
      _switch('withReplies', '他の人への返信を表示', subtitle: 'フォロー中の人が他の人へ送った返信をTLに含めます'),
    ],
  },
};

final Map<String, Object?> _safety = {
  'schema': 'rasq.settings-page/1',
  'area': 'safety',
  'title': 'プライバシーとセーフモード',
  'defaults': {'sensitiveMedia': 'blur', 'openCw': false},
  'root': {
    't': 'Column',
    'c': [
      {'t': 'SectionHeader', 'p': {'title': '閲覧注意(センシティブ)メディア'}},
      _radio('sensitiveMedia', 'blur', 'ぼかして表示', subtitle: 'タップで開きます(標準)'),
      _radio('sensitiveMedia', 'show', 'ぼかさず表示'),
      _radio('sensitiveMedia', 'hide', '表示しない(セーフモード)', subtitle: '閲覧注意メディアをタイルから取り除きます'),
      {'t': 'SectionHeader', 'p': {'title': '注釈(CW)'}},
      _switch('openCw', '注釈付き投稿を自動で開く'),
    ],
  },
};

final Map<String, Object?> _security = {
  'schema': 'rasq.settings-page/1',
  'area': 'security',
  'title': 'セキュリティ',
  'defaults': <String, Object?>{},
  'root': {
    't': 'Column',
    'c': [
      {'t': 'SectionHeader', 'p': {'title': 'このアプリに許可された権限 (MiAuth)'}},
      for (final scope in MiAuthFlow.defaultPermissions)
        {'t': 'ValueListTile', 'p': {'title': _scopeLabels[scope] ?? scope, 'value': scope}},
      {'t': 'SectionHeader', 'p': {'title': 'web で行う設定'}},
      _webLink('settings/api', 'アクセストークンの管理', subtitle: '発行済みトークンの確認と失効'),
      _webLink('settings/security', '二要素認証・ログイン履歴'),
      {'t': 'Text', 'p': {'text': 'パスワードが必要な操作は web 版で行います。アクセストークンは端末内の安全な領域にのみ保存されます。'}},
    ],
  },
};

const _scopeLabels = <String, String>{
  'read:account': 'アカウント情報の読み取り',
  'write:notes': 'ノートの作成・削除',
  'read:notifications': '通知の読み取り',
  'write:notifications': '通知の既読化',
  'read:reactions': 'リアクションの読み取り',
  'write:reactions': 'リアクションの追加・削除',
  'read:following': 'フォローの読み取り',
  'write:following': 'フォロー・解除',
  'read:blocks': 'ブロックの読み取り',
  'write:blocks': 'ブロック・解除',
  'read:mutes': 'ミュートの読み取り',
  'write:mutes': 'ミュート・解除',
  'read:favorites': 'お気に入りの読み取り',
  'write:favorites': 'お気に入りの追加・削除',
  'read:drive': 'ドライブの読み取り',
  'write:drive': 'ドライブへのアップロード',
  'read:messaging': 'ダイレクト投稿の読み取り',
  'write:messaging': 'ダイレクト投稿の送信',
  'read:chat': 'チャットの読み取り',
  'write:chat': 'チャットの送信',
};
