import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../session/session_providers.dart';

/// アクションリスト(2026-08-25 ワイヤー「アクションリスト化」):
/// 複数アクションを 1 ボタンに束ねる名前付きリスト。バーではリストが
/// 1 ボタンとして出て、タップでメンバーのドロップダウンが開く。
@immutable
class ActionListDef {
  const ActionListDef({required this.id, required this.name, required this.memberIds, this.icon});

  /// 同じ id を 2 回入れない (D-211: 重複キーで設定 FOW が壊れた)。
  static List<String> uniq(Iterable<String> ids) {
    final seen = <String>{};
    return [for (final id in ids) if (seen.add(id)) id];
  }

  final String id;
  final String name;
  final List<String> memberIds;

  /// バンドルのアイコン (D-210): `member:<actionId>`(バンドル内のアイコンを使い回す)/ `material:<name>`
  /// (Material Icon の名前)/ `file:<path>`(写真)。null = 既定(apps)。
  final String? icon;

  ActionListDef copyWith({String? name, List<String>? memberIds, String? icon, bool clearIcon = false}) =>
      ActionListDef(id: id, name: name ?? this.name, memberIds: uniq(memberIds ?? this.memberIds), icon: clearIcon ? null : (icon ?? this.icon));

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'memberIds': memberIds, if (icon != null) 'icon': icon};

  factory ActionListDef.fromJson(Map<String, Object?> json) => ActionListDef(
        id: json['id'] as String,
        name: json['name'] as String,
        memberIds: uniq([for (final m in (json['memberIds'] as List? ?? const [])) m as String]),
        icon: json['icon'] as String?,
      );
}

/// バーの 1 枠: 単体アクション or アクションリスト。
sealed class ActionBarEntry {
  const ActionBarEntry();
}

class SingleActionEntry extends ActionBarEntry {
  const SingleActionEntry(this.action);
  final ActionDescriptor action;
}

class ActionListEntry extends ActionBarEntry {
  const ActionListEntry(this.list, this.members);
  final ActionListDef list;
  final List<ActionDescriptor> members;
}

/// アクションバーのユーザー構成。
///
/// プラグインが登録した `ActionDescriptor` はそのままに、**ホスト側の構成**
/// として並び順・表示/非表示・リスト束ねを持つ(プラグイン無変更)。
/// [order] にはアクション id と `list:{listId}` が並ぶ。永続化はホストの
/// ストレージ(v1 は投稿タイル面のみ・全アカウント共通)。
@immutable
class ActionBarConfig {
  const ActionBarConfig({this.order = const [], this.hidden = const {}, this.lists = const []});

  final List<String> order;
  final Set<String> hidden;
  final List<ActionListDef> lists;

  bool get dirty => order.isNotEmpty || lists.isNotEmpty;

  static String listKey(String listId) => 'list:$listId';

  /// リストに入っているアクション id。
  Set<String> get listedIds => {for (final l in lists) ...l.memberIds};

  /// 構成を適用: リスト束ね + 並び替え。非表示は廃止 (D-208): 保存済みの [hidden] は無視する
  /// (プラグインボタンの有効 / 無効はスロット設定側)。
  List<ActionBarEntry> apply(List<ActionDescriptor> actions) {
    final byId = {for (final a in actions) a.id: a};
    final listById = {for (final l in lists) l.id: l};
    final consumed = <String>{...listedIds};

    ActionBarEntry? entryFor(String key) {
      if (key.startsWith('list:')) {
        final list = listById[key.substring(5)];
        if (list == null) return null;
        final members = [for (final id in list.memberIds) if (byId.containsKey(id)) byId[id]!];
        return members.isEmpty ? null : ActionListEntry(list, members);
      }
      final a = byId[key];
      return a == null || consumed.contains(key) ? null : SingleActionEntry(a);
    }

    final out = <ActionBarEntry>[];
    final placed = <String>{};
    for (final key in order) {
      final e = entryFor(key);
      if (e != null && placed.add(key)) out.add(e);
    }
    // order に無いリスト → 末尾へ。
    for (final l in lists) {
      final key = listKey(l.id);
      if (!placed.contains(key)) {
        final e = entryFor(key);
        if (e != null && placed.add(key)) out.add(e);
      }
    }
    // order に無い単体アクション(登録順)。
    for (final a in actions) {
      if (!placed.contains(a.id) && !consumed.contains(a.id)) {
        out.add(SingleActionEntry(a));
        placed.add(a.id);
      }
    }
    return out;
  }

  ActionBarConfig copyWith({List<String>? order, Set<String>? hidden, List<ActionListDef>? lists}) =>
      ActionBarConfig(order: order ?? this.order, hidden: hidden ?? this.hidden, lists: lists ?? this.lists);

  Map<String, Object?> toJson() => {
        'order': order,
        'hidden': hidden.toList(),
        'lists': [for (final l in lists) l.toJson()],
      };

  factory ActionBarConfig.fromJson(Map<String, Object?> json) => ActionBarConfig(
        order: [for (final o in (json['order'] as List? ?? const [])) o as String],
        hidden: {for (final h in (json['hidden'] as List? ?? const [])) h as String},
        lists: [for (final l in (json['lists'] as List? ?? const [])) ActionListDef.fromJson((l as Map).cast<String, Object?>())],
      );
}

/// 投稿タイル面の構成。ホストのストレージに **アカウントごと** に永続化 (D-200: キー `actionBar.post.v1.<accountKey>`。
/// 旧来の共通キー `actionBar.post.v1` は初回の復元で引き継ぐ)。複数サービスの投稿が 1 本の TL に流れるときは、
/// 投稿が流れてきたアカウントの構成でバーを出す。
class ActionBarConfigStore extends Notifier<ActionBarConfig> {
  ActionBarConfigStore(this.arg);
  static const storageKey = 'actionBar.post.v1';

  /// アカウントの key('' = 旧来の共通構成)。
  final String arg;
  bool _loaded = false;

  /// 全画面ビューワーのバー (D-210) は `viewer:<accountKey>` で別の構成を持つ。
  String get _key => arg.isEmpty ? storageKey : '$storageKey.$arg';

  static String viewerKey(String accountKey) => 'viewer:$accountKey';

  @override
  ActionBarConfig build() {
    _restore();
    return const ActionBarConfig();
  }

  Future<void> _restore() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final storage = ref.read(sessionStorageProvider);
      final raw = await storage.read(_key) ?? (arg.isEmpty || arg.startsWith('viewer:') ? null : await storage.read(storageKey));
      if (raw != null) state = ActionBarConfig.fromJson((jsonDecode(raw) as Map).cast<String, Object?>());
    } catch (_) {
      // 壊れた保存値は既定にフォールバック(次の set で上書きされる)。
    }
  }

  void set(ActionBarConfig next) {
    state = next;
    ref.read(sessionStorageProvider).write(_key, jsonEncode(next.toJson()));
  }

  void reset() => set(const ActionBarConfig());
}

/// アカウント(`AccountId.key`)ごとの構成。'' は旧来の共通構成。
final actionBarConfigProvider = NotifierProvider.family<ActionBarConfigStore, ActionBarConfig, String>(ActionBarConfigStore.new);
