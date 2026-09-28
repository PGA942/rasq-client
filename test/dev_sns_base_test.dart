import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

/// 開発 / デモ用の SNS の接続先の差し替え (D-359)。
void main() {
  test('「ホスト=基底 URL」を読む(壊れた項目は飛ばす)/ 指定が無ければ https のまま', () {
    final m = parseDevSnsBase(' Misskey.rasq.test=http://127.0.0.1:9101 , mstdn.rasq.test=http://10.0.0.5:9102/x,bad,=http://a,b=ftp://c');
    expect(m.keys, ['misskey.rasq.test', 'mstdn.rasq.test']);
    expect(m['misskey.rasq.test'].toString(), 'http://127.0.0.1:9101');
    // このテストは dart-define を付けずに走るので、差し替えは空。
    expect(devSnsBaseFor('misskey.io'), isNull);
    expect(snsUri('misskey.io', '/api/i').toString(), 'https://misskey.io/api/i');
    expect(snsUri('misskey.io', '/miauth/x', {'name': 'RASQ'}).toString(), 'https://misskey.io/miauth/x?name=RASQ');
  });
}
