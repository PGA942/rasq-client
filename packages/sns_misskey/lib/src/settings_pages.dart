import 'dart:convert';

import 'miauth.dart';
import 'l10n.dart';

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
      'p': {'label': label, 'value': r'$.settings.' + k, 'maxLength': maxLength, 'multiline': multiline, 'submitLabel': snsMisskeyL10n.misskeySettingsSave, 'clearOnSubmit': false, 'allowEmpty': true, 'pad': 16},
      'on': {'submit': 'settings.set'},
    };

List<(String, String)> get _visibilities => [('public', snsMisskeyL10n.misskeyVisibilityPublic), ('followers', snsMisskeyL10n.misskeyVisibilityFollowers), ('private', snsMisskeyL10n.misskeyVisibilityPrivate)];

Map<String, Object?> get _account => {
  'schema': 'rasq.settings-page/1',
  'area': 'account',
  'title': snsMisskeyL10n.misskeyAccountTitle,
  'source': 'remote',
  'defaults': MisskeyAccountSettings.defaults,
  'root': {
    't': 'Column',
    'c': [
      {'t': 'SectionHeader', 'p': {'title': snsMisskeyL10n.misskeyProfile}},
      _input('name', snsMisskeyL10n.misskeyName, 50),
      _input('description', snsMisskeyL10n.misskeyDescription, 1500, multiline: true),
      _input('location', snsMisskeyL10n.misskeyLocation, 50),
      _input('birthday', snsMisskeyL10n.misskeyBirthday, 10),
      _webLink('settings/profile', snsMisskeyL10n.misskeyProfileWeb, subtitle: snsMisskeyL10n.misskeyProfileWebSubtitle),
      {'t': 'SectionHeader', 'p': {'title': snsMisskeyL10n.misskeyPublicity}},
      _switch('isLocked', snsMisskeyL10n.misskeyIsLocked, subtitle: snsMisskeyL10n.misskeyIsLockedSubtitle),
      _switch('autoAcceptFollowed', snsMisskeyL10n.misskeyAutoAcceptFollowed),
      _switch('isExplorable', snsMisskeyL10n.misskeyIsExplorable, subtitle: snsMisskeyL10n.misskeyIsExplorableSubtitle),
      _switch('hideOnlineStatus', snsMisskeyL10n.misskeyHideOnlineStatus),
      _switch('publicReactions', snsMisskeyL10n.misskeyPublicReactions),
      _switch('noCrawle', snsMisskeyL10n.misskeyNoCrawle, subtitle: snsMisskeyL10n.misskeyNoCrawleSubtitle),
      {'t': 'SectionHeader', 'p': {'title': snsMisskeyL10n.misskeyFollowingVisibility}},
      for (final (v, label) in _visibilities) _radio('followingVisibility', v, label),
      {'t': 'SectionHeader', 'p': {'title': snsMisskeyL10n.misskeyFollowersVisibility}},
      for (final (v, label) in _visibilities) _radio('followersVisibility', v, label),
      {'t': 'SectionHeader', 'p': {'title': snsMisskeyL10n.misskeyAccountKind}},
      _switch('isBot', snsMisskeyL10n.misskeyIsBot),
      _switch('isCat', snsMisskeyL10n.misskeyIsCat, subtitle: snsMisskeyL10n.misskeyIsCatSubtitle),
      {'t': 'Text', 'p': {'text': snsMisskeyL10n.misskeyAccountNote, 'pad': 16}},
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
      if (value is! bool) throw ArgumentError.value(value, key, snsMisskeyL10n.misskeyInvalidBool);
      return {key: value};
    }
    if (textKeys.contains(key)) {
      final s = '${value ?? ''}'.trim();
      if (key == 'birthday' && s.isNotEmpty && !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s)) {
        throw ArgumentError.value(value, key, snsMisskeyL10n.misskeyInvalidBirthday);
      }
      // 名前・場所・誕生日は空 = 消す(null)。
      return {key: s.isEmpty && key != 'description' ? null : s};
    }
    if (visibilityKeys.contains(key)) {
      if (!visibilities.contains(value)) throw ArgumentError.value(value, key, snsMisskeyL10n.misskeyInvalidVisibility);
      return {key: value};
    }
    throw UnsupportedError('unknown remote setting: account.$key');
  }
}

Map<String, Object?> get _timeline => {
  'schema': 'rasq.settings-page/1',
  'area': 'timeline',
  'title': snsMisskeyL10n.misskeyTimelineTitle,
  'defaults': {'withRenotes': true, 'withReplies': false},
  'root': {
    't': 'Column',
    'c': [
      {'t': 'SectionHeader', 'p': {'title': snsMisskeyL10n.misskeyTimelinePosts}},
      _switch('withRenotes', snsMisskeyL10n.misskeyWithRenotes, subtitle: snsMisskeyL10n.misskeyWithRenotesSubtitle),
      _switch('withReplies', snsMisskeyL10n.misskeyWithReplies, subtitle: snsMisskeyL10n.misskeyWithRepliesSubtitle),
    ],
  },
};

Map<String, Object?> get _safety => {
  'schema': 'rasq.settings-page/1',
  'area': 'safety',
  'title': snsMisskeyL10n.misskeySafetyTitle,
  'defaults': {'sensitiveMedia': 'blur', 'openCw': false},
  'root': {
    't': 'Column',
    'c': [
      {'t': 'SectionHeader', 'p': {'title': snsMisskeyL10n.misskeySensitiveMedia}},
      _radio('sensitiveMedia', 'blur', snsMisskeyL10n.misskeySensitiveBlur, subtitle: snsMisskeyL10n.misskeySensitiveBlurSubtitle),
      _radio('sensitiveMedia', 'show', snsMisskeyL10n.misskeySensitiveShow),
      _radio('sensitiveMedia', 'hide', snsMisskeyL10n.misskeySensitiveHide, subtitle: snsMisskeyL10n.misskeySensitiveHideSubtitle),
      {'t': 'SectionHeader', 'p': {'title': snsMisskeyL10n.misskeyCw}},
      _switch('openCw', snsMisskeyL10n.misskeyOpenCw),
    ],
  },
};

Map<String, Object?> get _security => {
  'schema': 'rasq.settings-page/1',
  'area': 'security',
  'title': snsMisskeyL10n.misskeySecurityTitle,
  'defaults': <String, Object?>{},
  'root': {
    't': 'Column',
    'c': [
      {'t': 'SectionHeader', 'p': {'title': snsMisskeyL10n.misskeyPermissions}},
      for (final scope in MiAuthFlow.defaultPermissions)
        {'t': 'ValueListTile', 'p': {'title': _scopeLabel(scope) ?? scope, 'value': scope}},
      {'t': 'SectionHeader', 'p': {'title': snsMisskeyL10n.misskeyWebSettings}},
      _webLink('settings/api', snsMisskeyL10n.misskeyTokens, subtitle: snsMisskeyL10n.misskeyTokensSubtitle),
      _webLink('settings/security', snsMisskeyL10n.misskeyTwoFactor),
      {'t': 'Text', 'p': {'text': snsMisskeyL10n.misskeySecurityNote}},
    ],
  },
};

/// MiAuth の権限 → 説明(表示の言語)。知らない権限は null。
String? _scopeLabel(String scope) {
  final l = snsMisskeyL10n;
  return switch (scope) {
    'read:account' => l.misskeyScopeReadAccount,
    'write:notes' => l.misskeyScopeWriteNotes,
    'read:notifications' => l.misskeyScopeReadNotifications,
    'write:notifications' => l.misskeyScopeWriteNotifications,
    'read:reactions' => l.misskeyScopeReadReactions,
    'write:reactions' => l.misskeyScopeWriteReactions,
    'read:following' => l.misskeyScopeReadFollowing,
    'write:following' => l.misskeyScopeWriteFollowing,
    'read:blocks' => l.misskeyScopeReadBlocks,
    'write:blocks' => l.misskeyScopeWriteBlocks,
    'read:mutes' => l.misskeyScopeReadMutes,
    'write:mutes' => l.misskeyScopeWriteMutes,
    'read:favorites' => l.misskeyScopeReadFavorites,
    'write:favorites' => l.misskeyScopeWriteFavorites,
    'read:drive' => l.misskeyScopeReadDrive,
    'write:drive' => l.misskeyScopeWriteDrive,
    'read:messaging' => l.misskeyScopeReadMessaging,
    'write:messaging' => l.misskeyScopeWriteMessaging,
    'read:chat' => l.misskeyScopeReadChat,
    'write:chat' => l.misskeyScopeWriteChat,
    _ => null,
  };
}
