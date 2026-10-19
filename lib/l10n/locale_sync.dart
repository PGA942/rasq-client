import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../backend/orgate_client.dart' show orgateClientProvider;
import '../backend/rasq_account.dart' show orgateAccountProvider;
import 'ui_locale.dart';

/// RASQ アカウントの言語を ORGATE に伝える (D-484): ログインしているあいだ、表示の言語が変わったとき / ログインしたとき
/// (アカウントが変わったとき)に `PATCH /api/v1/me {"locale": "<BCP-47>"}`。ORGATE はこれでメールや通知の言語を決める。
///
/// 同じアカウントに同じ言語は 1 度だけ送る。古い ORGATE(`locale` を知らない: 400 など)や、つながらないときは黙って諦める
/// (次に言語かアカウントが変わったときに、また送る)。アプリの一番上([RasqApp])で watch しておく。
final localeSyncProvider = Provider<void>((ref) {
  final tag = ref.watch(uiLocaleTagProvider);
  final accountId = ref.watch(orgateAccountProvider.select((a) => a.value?.id));
  final client = ref.watch(orgateClientProvider);
  if (accountId == null || accountId.isEmpty || client == null) return;
  final sent = ref.read(_localeSyncedProvider);
  final key = '$accountId\n$tag';
  if (sent.contains(key)) return;
  sent.add(key);
  final token = ref.read(orgateAccountProvider.notifier).token;
  // build の中で通信を始めない(次のマイクロタスクへ)。
  Future.microtask(() async {
    try {
      await (token == null ? client : client.withToken(() => token)).patchJson('/me', {'locale': tag});
    } catch (e) {
      // 古いサーバー(未知の項目で 400)/ つながらない: 黙って諦める。次に送れるよう、送った印は外す。
      sent.remove(key);
      debugPrint('locale sync: PATCH /me skipped ($e)');
    }
  });
});

/// 送り終えた(送っている)「アカウント id + 言語」。
final _localeSyncedProvider = Provider<Set<String>>((ref) => <String>{});
