import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:url_launcher/url_launcher.dart';

/// RAi の返事のリッチテキスト (D-232): 端末内 / サーバーの LLM が返す軽い Markdown(見出し `#`、箇条書き `- ` / `・` /
/// `* `、番号 `1. `、太字 `**x**`、インラインコード `` `x` ``、URL)を枠なしのタイルとして描く。
/// 未知の記法はそのまま文字で出す(壊れない)。
class RaiRichText extends StatelessWidget {
  const RaiRichText(this.text, {super.key, this.color, this.baseStyle, this.onOpenLink});
  final String text;
  final Color? color;
  final TextStyle? baseStyle;

  /// URL を押したとき(既定は外部ブラウザ)。テストで差し替える。
  final void Function(Uri url)? onOpenLink;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = (baseStyle ?? RasqTypography.body).copyWith(color: color ?? scheme.onSurface);
    final blocks = raiParseBlocks(text);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final b in blocks)
        switch (b.kind) {
          RaiBlockKind.heading => Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 2),
              child: Text.rich(_inline(b.text, base.copyWith(fontWeight: FontWeight.w700, fontSize: (base.fontSize ?? 15) + (b.level <= 1 ? 2 : 1)), scheme), key: b.key),
            ),
          // 箇条書き / 番号は印を同じ Text.rich の先頭に(plain text で「1. 本文」と読める)。
          RaiBlockKind.bullet || RaiBlockKind.numbered => Padding(
              padding: const EdgeInsets.only(left: 6, top: 1),
              child: Text.rich(TextSpan(style: base, children: [TextSpan(text: b.kind == RaiBlockKind.bullet ? '• ' : '${b.number}. '), _inline(b.text, base, scheme)]), key: b.key),
            ),
          RaiBlockKind.code => Container(
              margin: const EdgeInsets.symmetric(vertical: 2),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(6)),
              child: Text(b.text, key: b.key, style: base.copyWith(fontFamily: 'monospace', fontSize: (base.fontSize ?? 15) - 2)),
            ),
          RaiBlockKind.paragraph => Text.rich(_inline(b.text, base, scheme), key: b.key),
        },
    ]);
  }

  static final _inlineRe = RegExp(r'\*\*(.+?)\*\*|`([^`]+)`|(https?://[^\s)\]」』>]+)');

  TextSpan _inline(String s, TextStyle base, ColorScheme scheme) {
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in _inlineRe.allMatches(s)) {
      if (m.start > last) spans.add(TextSpan(text: s.substring(last, m.start)));
      if (m.group(1) != null) {
        spans.add(TextSpan(text: m.group(1), style: const TextStyle(fontWeight: FontWeight.w700)));
      } else if (m.group(2) != null) {
        spans.add(TextSpan(text: m.group(2), style: TextStyle(fontFamily: 'monospace', backgroundColor: scheme.surfaceContainerHighest)));
      } else {
        final url = m.group(3)!.replaceAll(RegExp(r'[.,。、]+$'), '');
        final uri = Uri.tryParse(url);
        spans.add(TextSpan(
          text: url,
          style: TextStyle(color: RasqColors.link, decoration: TextDecoration.underline),
          recognizer: uri == null ? null : (TapGestureRecognizer()..onTap = () => (onOpenLink ?? _open)(uri)),
        ));
        if (m.group(3)!.length > url.length) spans.add(TextSpan(text: m.group(3)!.substring(url.length)));
      }
      last = m.end;
    }
    if (last < s.length) spans.add(TextSpan(text: s.substring(last)));
    return TextSpan(style: base, children: spans);
  }

  static void _open(Uri url) => launchUrl(url, mode: LaunchMode.externalApplication);
}

enum RaiBlockKind { paragraph, heading, bullet, numbered, code }

class RaiBlock {
  const RaiBlock(this.kind, this.text, {this.level = 0, this.number = 0, this.key});
  final RaiBlockKind kind;
  final String text;
  final int level;
  final int number;
  final Key? key;
}

/// 行ごとのブロック分解(コードフェンス ``` は複数行を 1 ブロックに)。
List<RaiBlock> raiParseBlocks(String text) {
  final out = <RaiBlock>[];
  final lines = text.split('\n');
  var i = 0;
  var para = <String>[];
  void flush() {
    if (para.isNotEmpty) {
      out.add(RaiBlock(RaiBlockKind.paragraph, para.join('\n')));
      para = [];
    }
  }
  while (i < lines.length) {
    final raw = lines[i];
    final line = raw.trimRight();
    if (line.trim().startsWith('```')) {
      flush();
      final buf = <String>[];
      i++;
      while (i < lines.length && !lines[i].trim().startsWith('```')) {
        buf.add(lines[i]);
        i++;
      }
      out.add(RaiBlock(RaiBlockKind.code, buf.join('\n')));
      i++;
      continue;
    }
    final h = RegExp(r'^(#{1,4})\s+(.*)$').firstMatch(line);
    if (h != null) {
      flush();
      out.add(RaiBlock(RaiBlockKind.heading, h.group(2)!, level: h.group(1)!.length));
      i++;
      continue;
    }
    final b = RegExp(r'^\s*(?:[-*・•]|[‐–])\s+(.*)$').firstMatch(line);
    if (b != null) {
      flush();
      out.add(RaiBlock(RaiBlockKind.bullet, b.group(1)!));
      i++;
      continue;
    }
    final n = RegExp(r'^\s*(\d{1,2})[.．)]\s*(.*)$').firstMatch(line);
    if (n != null && n.group(2)!.isNotEmpty) {
      flush();
      out.add(RaiBlock(RaiBlockKind.numbered, n.group(2)!, number: int.parse(n.group(1)!)));
      i++;
      continue;
    }
    if (line.trim().isEmpty) {
      flush();
      i++;
      continue;
    }
    para.add(line);
    i++;
  }
  flush();
  return out;
}

/// 丸数字 (D-232: インストラクション履歴の行番号)。21 以上は「21.」。
String raiCircled(int n) => n >= 1 && n <= 20 ? String.fromCharCode(0x2460 + n - 1) : '$n.';
