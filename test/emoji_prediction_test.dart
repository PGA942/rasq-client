import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/features/compose/emoji_prediction.dart';
import 'package:rasq_models/rasq_models.dart';

void main() {
  final u = Uri.parse('https://e/x.webp');
  final custom = [
    EmojiInfo(name: 'otsukare', aliases: const ['おつかれ', '退勤'], url: u),
    EmojiInfo(name: 'miku_dance', aliases: const ['初音ミク'], url: u),
    EmojiInfo(name: 'blobcat', url: u),
  ];

  test('絵文字予測 (D-040): 語句一致 > 履歴 > 既存リアクション の合成', () {
    final out = predictEmojis(
      context: '仕事おわり、退勤!今日もおつかれさま',
      custom: custom,
      history: {'👍': 5, ':blobcat:': 2},
      existingReactions: {'🎉': 3},
      recent: ['😂'],
    );
    // 語句一致した :otsukare: が先頭(退勤・おつかれ両方に一致)。
    expect(out.first, ':otsukare:');
    expect(out, contains('👍'));
    expect(out, contains('🎉'));
    // 一致しない :miku_dance: は入らない。
    expect(out, isNot(contains(':miku_dance:')));
  });

  test('リアクション形式 `:name@.:` は挿入形式 `:name:` に正規化される', () {
    final out = predictEmojis(context: '', existingReactions: {':blobcat@.:': 4});
    expect(out, [':blobcat:']);
  });

  test('シグナルが無ければ空(無理に出さない)', () {
    expect(predictEmojis(context: '今日は良い天気', custom: custom), isEmpty);
  });
}
