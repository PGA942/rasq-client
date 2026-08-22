import 'package:meta/meta.dart';

/// FOW confirm modes (原典: UI_status「confirmMode」+ 何をやる.md Stickオプション).
enum ConfirmMode { immediate, confirm, saveDiscard, stick }

/// FOW type required to run the action (原典: FOWタイプ 3種).
enum FowType { none, widget, interstitial, system }

/// Where the count shown next to a button comes from (旧D1: countSource).
enum CountSource { self, first, none }

/// Declares one action-bar button the plugin registers (register_action).
///
/// Genre tags group buttons from different plugins into one slot
/// (Repost / Reaction / Reply / Quote / Share / Bookmark …, assigned at review).
@immutable
class ActionDescriptor {
  const ActionDescriptor({
    required this.id,
    required this.genreTag,
    required this.label,
    this.icon,
    this.doneIcon,
    this.confirmMode = ConfirmMode.immediate,
    this.fow = FowType.none,
    this.countSource = CountSource.self,
    this.autoHookForbidden = false,
    this.destructive = false,
  });

  final String id;
  final String genreTag;
  final String label;

  /// Icon names are resolved by the host icon registry (Material name for now).
  final String? icon;

  /// Icon for the "done" state. When absent the button is disabled once done.
  final String? doneIcon;
  final ConfirmMode confirmMode;
  final FowType fow;
  final CountSource countSource;

  /// Forbidden for 自動Hook by SNS terms (旧D5).
  final bool autoHookForbidden;
  final bool destructive;

  /// Derived automation policy (旧D5 C案): immediate → allowed,
  /// confirm/saveDiscard/stick → human gate, forbidden flag wins.
  AutomationPolicy get automation => autoHookForbidden
      ? AutomationPolicy.forbidden
      : confirmMode == ConfirmMode.immediate
          ? AutomationPolicy.allowed
          : AutomationPolicy.humanGate;

  Map<String, Object?> toJson() => {
        'id': id,
        'genreTag': genreTag,
        'label': label,
        if (icon != null) 'icon': icon,
        if (doneIcon != null) 'doneIcon': doneIcon,
        'confirmMode': confirmMode.name,
        'fow': fow.name,
        'countSource': countSource.name,
        'autoHookForbidden': autoHookForbidden,
        'destructive': destructive,
      };

  factory ActionDescriptor.fromJson(Map<String, Object?> j) => ActionDescriptor(
        id: j['id'] as String,
        genreTag: j['genreTag'] as String,
        label: j['label'] as String,
        icon: j['icon'] as String?,
        doneIcon: j['doneIcon'] as String?,
        confirmMode: ConfirmMode.values.byName(j['confirmMode'] as String? ?? 'immediate'),
        fow: FowType.values.byName(j['fow'] as String? ?? 'none'),
        countSource: CountSource.values.byName(j['countSource'] as String? ?? 'self'),
        autoHookForbidden: j['autoHookForbidden'] as bool? ?? false,
        destructive: j['destructive'] as bool? ?? false,
      );
}

enum AutomationPolicy { allowed, humanGate, forbidden }

/// Fully-qualified action reference — `pluginId:accountKey:pluginVersion:fn`
/// (D-003/D-006 【提案】). Including account + version keeps per-account
/// plugin versions and store scopes on one key system.
@immutable
class ActionRef {
  const ActionRef({required this.pluginId, required this.accountKey, required this.pluginVersion, required this.fn});

  final String pluginId;
  final String accountKey;
  final String pluginVersion;
  final String fn;

  String get fq => '$pluginId:$accountKey:$pluginVersion:$fn';

  /// Parses `pluginId:accountKey:pluginVersion:fn`. accountKey itself contains
  /// colons (`kind:instance:handle`), so the format is split from both ends.
  static ActionRef? tryParse(String s) {
    final first = s.indexOf(':');
    final last = s.lastIndexOf(':');
    if (first < 0 || last <= first) return null;
    final pluginId = s.substring(0, first);
    final fn = s.substring(last + 1);
    final middle = s.substring(first + 1, last);
    final v = middle.lastIndexOf(':');
    if (v < 0) return null;
    return ActionRef(pluginId: pluginId, accountKey: middle.substring(0, v), pluginVersion: middle.substring(v + 1), fn: fn);
  }

  @override
  bool operator ==(Object other) => other is ActionRef && other.fq == fq;
  @override
  int get hashCode => fq.hashCode;
  @override
  String toString() => fq;
}

/// Result of performing an action — feeds `ActionStateStore` directly.
@immutable
class ActionResult {
  const ActionResult({required this.done, this.count, this.message});
  final bool done;
  final int? count;
  final String? message;
}
