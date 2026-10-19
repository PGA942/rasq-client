/// mfm.js(misskey-dev/mfm.js 0.27)のノード (D-509)。
///
/// 形は mfm.js の `MfmNode` と同じ(`{type, props?, children?}`)。[toJson] は mfm.js の `parse()` が返す JSON と
/// そのまま比べられる(テストは mfm.js の出力と突き合わせる)。
///
/// ブロック: `quote` / `search` / `blockCode` / `mathBlock` / `center`。
/// インライン: `unicodeEmoji` / `emojiCode` / `bold` / `small` / `italic` / `strike` / `inlineCode` / `mathInline` /
/// `mention` / `hashtag` / `url` / `link` / `fn` / `plain` / `text`。
class MfmNode {
  const MfmNode(this.type, {this.props, this.children});

  final String type;
  final Map<String, Object?>? props;
  final List<MfmNode>? children;

  static const blockTypes = {'quote', 'search', 'blockCode', 'mathBlock', 'center'};
  bool get isBlock => blockTypes.contains(type);

  // ── mfm.js の組み立て関数と同じ形 ──
  static MfmNode quote(List<MfmNode> children) => MfmNode('quote', children: children);
  static MfmNode search(String query, String content) => MfmNode('search', props: {'query': query, 'content': content});
  static MfmNode codeBlock(String code, String? lang) => MfmNode('blockCode', props: {'code': code, 'lang': lang});
  static MfmNode mathBlock(String formula) => MfmNode('mathBlock', props: {'formula': formula});
  static MfmNode center(List<MfmNode> children) => MfmNode('center', children: children);
  static MfmNode unicodeEmoji(String emoji) => MfmNode('unicodeEmoji', props: {'emoji': emoji});
  static MfmNode emojiCode(String name) => MfmNode('emojiCode', props: {'name': name});
  static MfmNode bold(List<MfmNode> children) => MfmNode('bold', children: children);
  static MfmNode small(List<MfmNode> children) => MfmNode('small', children: children);
  static MfmNode italic(List<MfmNode> children) => MfmNode('italic', children: children);
  static MfmNode strike(List<MfmNode> children) => MfmNode('strike', children: children);
  static MfmNode inlineCode(String code) => MfmNode('inlineCode', props: {'code': code});
  static MfmNode mathInline(String formula) => MfmNode('mathInline', props: {'formula': formula});
  static MfmNode mention(String username, String? host, String acct) => MfmNode('mention', props: {'username': username, 'host': host, 'acct': acct});
  static MfmNode hashtag(String value) => MfmNode('hashtag', props: {'hashtag': value});
  static MfmNode url(String value, {bool brackets = false}) => MfmNode('url', props: {'url': value, if (brackets) 'brackets': true});
  static MfmNode link(bool silent, String url, List<MfmNode> children) => MfmNode('link', props: {'silent': silent, 'url': url}, children: children);
  static MfmNode fn(String name, Map<String, Object> args, List<MfmNode> children) => MfmNode('fn', props: {'name': name, 'args': args}, children: children);
  static MfmNode plain(String text) => MfmNode('plain', children: [MfmNode.ofText(text)]);
  static MfmNode ofText(String value) => MfmNode('text', props: {'text': value});

  // ── よく使う中身 ──
  String get text => props?['text'] as String? ?? '';
  String get fnName => props?['name'] as String? ?? '';

  /// `fn` の引数(値は文字列、値なしは `true`。mfm.js と同じ)。
  Map<String, Object> get fnArgs => (props?['args'] as Map?)?.cast<String, Object>() ?? const {};

  Map<String, Object?> toJson() => {
        'type': type,
        if (props != null) 'props': props,
        if (children != null) 'children': [for (final c in children!) c.toJson()],
      };

  @override
  String toString() => toJson().toString();
}
