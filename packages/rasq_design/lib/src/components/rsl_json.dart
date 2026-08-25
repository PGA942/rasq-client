import 'package:flutter/foundation.dart';

import 'rich_text.dart';

/// Wire codec for RSL spans (`rasq-sdk-sample/schema/rsl-span.schema.json`).
///
/// A plugin may send the post body pre-parsed as a span array instead of a
/// raw string; this decodes it into [RasqSpan]s for [RasqRichText]. Tap
/// targets are host-owned: the optional callbacks wire link/mention/hashtag
/// interaction (sideloaded content passes none → non-interactive, 旧D2).
List<RasqSpan> rslSpansFromJson(
  List<Object?> json, {
  Map<String, Uri?> emojis = const {},
  void Function(Uri url)? onLink,
  void Function(String handle, String? host)? onMention,
  void Function(String tag)? onHashtag,
}) {
  final out = <RasqSpan>[];
  for (final raw in json) {
    if (raw is! Map) continue;
    final m = raw.cast<String, Object?>();
    switch (m['s']) {
      case 'text':
        out.add(RasqTextSpan(
          '${m['text'] ?? ''}',
          bold: m['bold'] == true,
          italic: m['italic'] == true,
          strike: m['strike'] == true,
          small: m['small'] == true,
          code: m['code'] == true,
        ));
      case 'emoji':
        final code = '${m['shortcode'] ?? ''}';
        final url = m['url'] == null ? emojis[code] : Uri.tryParse('${m['url']}');
        out.add(RasqEmojiSpan(shortcode: code, url: url));
      case 'image':
        final url = Uri.tryParse('${m['url']}');
        if (url != null) out.add(RasqInlineImageSpan(url, height: (m['height'] as num?)?.toDouble() ?? 18, alt: m['alt'] as String?));
      case 'link':
        final url = Uri.tryParse('${m['url']}');
        if (url != null) {
          out.add(RasqLinkSpan('${m['text'] ?? m['url']}', url: url, onTap: onLink == null ? null : () => onLink(url)));
        }
      case 'mention':
        final handle = '${m['handle'] ?? ''}';
        final host = m['host'] as String?;
        out.add(RasqMentionSpan(host == null ? handle : '$handle@$host', onTap: onMention == null ? null : () => onMention(handle, host)));
      case 'hashtag':
        final tag = '${m['tag'] ?? ''}';
        out.add(RasqHashtagSpan(tag, onTap: onHashtag == null ? null : () => onHashtag(tag)));
      case 'transform':
        out.add(RasqTransformSpan(
          '${m['fn'] ?? 'plain'}',
          args: (m['args'] as Map?)?.cast<String, Object?>() ?? const {},
          children: rslSpansFromJson((m['c'] as List?) ?? const [], emojis: emojis, onLink: onLink, onMention: onMention, onHashtag: onHashtag),
        ));
      default:
        if (kDebugMode) debugPrint('rslSpansFromJson: unknown span kind ${m['s']}');
    }
  }
  return out;
}

/// Inverse of [rslSpansFromJson] — for plugins/tools authored in Dart and
/// for tests. Interaction callbacks are not representable on the wire.
List<Object?> rslSpansToJson(List<RasqSpan> spans) => [
      for (final s in spans)
        switch (s) {
          RasqTextSpan() => {
              's': 'text',
              'text': s.text,
              if (s.bold) 'bold': true,
              if (s.italic) 'italic': true,
              if (s.strike) 'strike': true,
              if (s.small) 'small': true,
              if (s.code) 'code': true,
            },
          RasqEmojiSpan() => {'s': 'emoji', 'shortcode': s.shortcode, if (s.url != null) 'url': s.url.toString()},
          RasqInlineImageSpan() => {'s': 'image', 'url': s.url.toString(), 'height': s.height, if (s.alt != null) 'alt': s.alt},
          RasqLinkSpan() => {'s': 'link', 'text': s.text, 'url': s.url.toString()},
          RasqMentionSpan() => {'s': 'mention', 'handle': s.handle},
          RasqHashtagSpan() => {'s': 'hashtag', 'tag': s.tag},
          RasqTransformSpan() => {'s': 'transform', 'fn': s.fn, if (s.args.isNotEmpty) 'args': s.args, 'c': rslSpansToJson(s.children)},
        },
    ];
