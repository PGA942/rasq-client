import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/backend/rasq_account_page_api.dart';
import 'package:rasq_client/features/compose/composer_sheet.dart';
import 'package:rasq_client/features/compose/kana_romaji.dart';

/// メンション (D-285)。
void main() {
  test('打っている途中のメンションを、キャレットの位置から拾う', () {
    expect(mentionQueryAt('こんにちは @ta', 9), (6, 'ta'));
    expect(mentionQueryAt('@taro', 5), (0, 'taro'));
    // 別のサーバーの人(host を打っている途中)も、まとめて 1 つ。検索には user の部分を使う。
    expect(mentionQueryAt('やあ @taro@mk.ex', 14), (3, 'taro'));
    // メールアドレスの途中 / 打ち終わったあと(空白のあと)は、拾わない。
    expect(mentionQueryAt('mail a@exa', 10), isNull);
    expect(mentionQueryAt('@taro ', 6), isNull);
    // 日本語でも反応する (D-289): 表示名で探せるように。日本語の文の途中(空白なし)でも拾う。
    expect(mentionQueryAt('@たろ', 3), (0, 'たろ'));
    expect(mentionQueryAt('こんにちは@花子', 8), (5, '花子'));
    expect(mentionQueryAt('やあ @タロウ', 7), (3, 'タロウ'));
    // 英数字や . の直後の @ は、メールアドレスの途中なので拾わない。
    expect(mentionQueryAt('info.taro@たろ', 12), isNull);
    // キャレットが途中にあるときは、そこまでを見る。
    expect(mentionQueryAt('@taro と @hanako', 3), (0, 'ta'));
  });

  test('本文のうち、実在するアカウントのメンションだけを区切る', () {
    expect(splitMentions('やあ @Taro と @nobody、a@taro.example', ['taro']), [('やあ ', null), ('@Taro', 'Taro'), (' と @nobody、a@taro.example', null)]);
    expect(splitMentions('@taro@mk.example は他の SNS', ['taro']), [('@taro@mk.example は他の SNS', null)]);
    expect(splitMentions('メンションなし', const []), [('メンションなし', null)]);
  });

  test('投稿の mentions / 通知を読む', () {
    final p = RasqAccountPost.fromJson({'id': 'p1', 'body': '@taro', 'mentions': [{'id': 'a', 'handle': 'taro', 'displayName': 'タロ'}]});
    expect(p.mentions.single.handle, 'taro');
    final n = RasqNotice.fromJson({'id': 'n1', 'kind': 'post.mention', 'title': 'メンションされました', 'body': 'x', 'payload': {'postId': 'p1', 'actor': {'id': 'b', 'handle': 'hanako', 'displayName': 'ハナコ'}}, 'createdAt': '2026-09-20T00:00:00Z'});
    expect((n.postId, n.actor?.handle), ('p1', 'hanako'));
  });

  test('かな → ローマ字: 日本語で打っても、ハンドルに届く (D-289)', () {
    expect(kanaToRomaji('たろう'), 'tarou');
    expect(kanaToRomaji('タロー'), 'taro');
    expect(kanaToRomaji('しゅんすけ'), 'shunsuke');
    expect(kanaToRomaji('きっと'), 'kitto');
    expect(kanaToRomaji('ちゃーりー'), 'chari');
    expect(kanaToRomaji('ふぁん太'), 'fan太'); // 漢字は読みが決まらないので、そのまま
    // かなが無ければ、読み替えない(そのままの文字だけで引く)。
    expect(kanaToRomaji('taro'), isNull);
    expect(kanaToRomaji('花子'), isNull);
  });
}
