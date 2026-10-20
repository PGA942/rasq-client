import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';

import '../child_safe/child_safe_providers.dart' show childSafeProvider;
import 'export_ad_sdk.dart';
import '../../l10n/l10n.dart';

/// メディアの書き出し中の広告枠 (D-327)。
///
/// 投稿コンポーザーで動画などを書き出している間(進み具合を出している間)だけ、その表示の中に広告を 1 枠出す。
/// - **Android / iOS** = AdMob(インラインのアダプティブバナー。動画の広告も入る)、**Web** = AdSense(表示広告。
///   AdSense は動画を保証しない)、**それ以外のデスクトップ**(macOS / Windows / Linux)は出さない。
/// - **チャイルドセーフの子のアカウント**(見守られている端末)では出さない。見守りの状態を読み終えるまでも出さない。
/// - 書き出しは広告を待たない(枠は進み具合の表示の一部で、書き出しが終わって表示が消えると一緒に閉じる)。
///   読み込めなかったら、何も言わずに枠を消す。
/// - 個人に合わせない広告だけを頼む(AdMob は `npa`、AdSense は `requestNonPersonalizedAds`)。同意 (UMP) が要る地域で
///   まだ同意が無ければ、AdMob は頼まない(書き出しの途中に同意の画面は出さない)。iOS の ATT は求めない(IDFA を使わない)。
///
/// ID は `--dart-define` で渡す(本物の ID はまだ無い)。既定は Google の公式のテスト ID。Web は AdSense の ID が無ければ出さない:
/// - `RASQ_ADMOB_BANNER_ANDROID` / `RASQ_ADMOB_BANNER_IOS`: 広告ユニット ID(既定 = テスト用のアダプティブバナー)
/// - `RASQ_ADMOB_INTERSTITIAL_ANDROID` / `RASQ_ADMOB_INTERSTITIAL_IOS`: 全画面(動画)の広告ユニット ID(D-445 の Swing。既定 = テスト用)
/// - `RASQ_ADSENSE_CLIENT`(`ca-pub-…`)/ `RASQ_ADSENSE_SLOT`(広告ユニットの `data-ad-slot`)
/// - App ID は端末の設定(Android = `RASQ_ADMOB_APP_ID_ANDROID` を gradle が dart-define から読む、iOS = `ios/Flutter/Ads.xcconfig`)。
enum ExportAdNetwork { admob, adsense }

/// 広告の ID。
@immutable
class ExportAdConfig {
  const ExportAdConfig({
    this.admobAndroidUnit = admobTestAndroidUnit,
    this.admobIosUnit = admobTestIosUnit,
    this.admobInterstitialAndroidUnit = admobTestInterstitialAndroidUnit,
    this.admobInterstitialIosUnit = admobTestInterstitialIosUnit,
    this.adsenseClient = '',
    this.adsenseSlot = '',
  });

  /// Google の公式のテスト用の広告ユニット(アダプティブバナー)。
  static const admobTestAndroidUnit = 'ca-app-pub-3940256099942544/9214589741';
  static const admobTestIosUnit = 'ca-app-pub-3940256099942544/2435281174';

  /// Google の公式のテスト用の広告ユニット(動画のインタースティシャル = 全画面の広告、D-445 の Swing)。
  static const admobTestInterstitialAndroidUnit = 'ca-app-pub-3940256099942544/8691691433';
  static const admobTestInterstitialIosUnit = 'ca-app-pub-3940256099942544/5135589807';

  /// ビルド時の `--dart-define`。
  static const fromEnvironment = ExportAdConfig(
    admobAndroidUnit: String.fromEnvironment('RASQ_ADMOB_BANNER_ANDROID', defaultValue: admobTestAndroidUnit),
    admobIosUnit: String.fromEnvironment('RASQ_ADMOB_BANNER_IOS', defaultValue: admobTestIosUnit),
    admobInterstitialAndroidUnit: String.fromEnvironment('RASQ_ADMOB_INTERSTITIAL_ANDROID', defaultValue: admobTestInterstitialAndroidUnit),
    admobInterstitialIosUnit: String.fromEnvironment('RASQ_ADMOB_INTERSTITIAL_IOS', defaultValue: admobTestInterstitialIosUnit),
    adsenseClient: String.fromEnvironment('RASQ_ADSENSE_CLIENT'),
    adsenseSlot: String.fromEnvironment('RASQ_ADSENSE_SLOT'),
  );

  final String admobAndroidUnit;
  final String admobIosUnit;
  final String admobInterstitialAndroidUnit;
  final String admobInterstitialIosUnit;
  final String adsenseClient;
  final String adsenseSlot;

  bool get hasAdsense => adsenseClient.isNotEmpty && adsenseSlot.isNotEmpty;

  String admobUnitFor(TargetPlatform platform) => platform == TargetPlatform.iOS ? admobIosUnit : admobAndroidUnit;

  String admobInterstitialUnitFor(TargetPlatform platform) => platform == TargetPlatform.iOS ? admobInterstitialIosUnit : admobInterstitialAndroidUnit;
}

/// どの広告を出すか。null = 出さない。
ExportAdNetwork? exportAdNetworkFor({required bool web, required TargetPlatform platform, required ExportAdConfig config}) {
  if (web) return config.hasAdsense ? ExportAdNetwork.adsense : null;
  return switch (platform) {
    TargetPlatform.android || TargetPlatform.iOS => ExportAdNetwork.admob,
    _ => null,
  };
}

/// 広告の SDK の差し替え口(テストは偽物)。
abstract interface class ExportAdSdk {
  /// 広告 1 枠。[width] = 使える幅、[maxHeight] = 高さの上限(D-445: Swing の縦長のバナーは画面の高さの 70% まで)。
  /// 出せたら [onLoaded]、読み込めなかった / 頼めなかったら [onFailed](どちらも 1 回だけ、非同期に)。捨てられたら広告も捨てる。
  Widget buildAd({required ExportAdNetwork network, required ExportAdConfig config, required double width, double maxHeight = 250, required VoidCallback onLoaded, required VoidCallback onFailed});

  /// 全画面(動画)の広告を 1 つ読んでおく (D-445)。読めたら true。出せない広告(AdSense)/ 読めなければ false。
  Future<bool> loadFullscreen({required ExportAdNetwork network, required ExportAdConfig config});

  /// 読んでおいた全画面の広告を出し、閉じられるまで待つ。出せたら true(読んでいなければ / 出せなければ false)。
  Future<bool> showFullscreen();
}

final exportAdConfigProvider = Provider<ExportAdConfig>((ref) => ExportAdConfig.fromEnvironment);

/// テスト中(`FLUTTER_TEST`)は出さない(AdMob の同意の確かめがタイマーを残す。D-433 で TL / 検索ホームにも枠を置いたので)。
/// 広告を確かめるテストは、このプロバイダーと [exportAdSdkProvider] を差し替える。
final exportAdNetworkProvider = Provider<ExportAdNetwork?>((ref) {
  if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) return null;
  return exportAdNetworkFor(web: kIsWeb, platform: defaultTargetPlatform, config: ref.watch(exportAdConfigProvider));
});

/// 本物は Android / iOS = AdMob、Web = AdSense(`export_ad_sdk_io.dart` / `export_ad_sdk_web.dart`)。
final exportAdSdkProvider = Provider<ExportAdSdk>((ref) => createExportAdSdk());

/// 広告を出してよいアカウントか: 子のアカウント(見守られている端末)では出さない。見守りの状態が分かるまでも出さない。
final exportAdAllowedProvider = Provider<bool>((ref) {
  final s = ref.watch(childSafeProvider);
  return s.hasValue && !s.requireValue.managed;
});

const exportAdSlotKey = Key('export.ad');

/// 書き出し中の広告枠。出せないとき / 読み込めなかったときは何も出さない。
class ExportAdSlot extends ConsumerStatefulWidget {
  const ExportAdSlot({super.key, this.onDark = false, this.maxHeight = 250, this.onFailed});

  /// 暗い背景(加工画面)の上に置く。
  final bool onDark;

  /// 高さの上限 (D-445: Swing の縦長のバナー)。
  final double maxHeight;

  /// 読み込めなかった(枠を消した)。
  final VoidCallback? onFailed;

  /// 広告の幅の上限 / 下限(これより狭ければ出さない)。
  static const maxWidth = 400.0;
  static const minWidth = 250.0;

  @override
  ConsumerState<ExportAdSlot> createState() => _ExportAdSlotState();
}

class _ExportAdSlotState extends ConsumerState<ExportAdSlot> {
  bool _loaded = false;
  bool _failed = false;

  void _later(VoidCallback f) => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(f);
      });

  @override
  Widget build(BuildContext context) {
    if (_failed) return const SizedBox.shrink();
    final network = ref.watch(exportAdNetworkProvider);
    if (network == null || !ref.watch(exportAdAllowedProvider)) return const SizedBox.shrink();
    final config = ref.watch(exportAdConfigProvider);
    final sdk = ref.watch(exportAdSdkProvider);
    return LayoutBuilder(builder: (context, c) {
      final width = math.min(c.maxWidth, ExportAdSlot.maxWidth);
      if (width < ExportAdSlot.minWidth) return const SizedBox.shrink();
      final muted = widget.onDark ? Colors.white54 : Theme.of(context).colorScheme.onSurfaceVariant;
      return Padding(
        key: exportAdSlotKey,
        padding: const EdgeInsets.only(top: RasqSpacing.sm),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // 広告だと分かるように(読み込めてから出す)。
          if (_loaded) Padding(padding: const EdgeInsets.only(bottom: 2), child: Text(context.l10n.adsLabel, style: RasqTypography.caption.copyWith(color: muted))),
          sdk.buildAd(
            network: network,
            config: config,
            width: width,
            maxHeight: widget.maxHeight,
            // 変わったときだけ描き直す(作り直すたびに読めたと知らせる SDK でも回り続けない)。
            onLoaded: () {
              if (!_loaded) _later(() => _loaded = true);
            },
            onFailed: () => _later(() {
              _failed = true;
              widget.onFailed?.call();
            }),
          ),
        ]),
      );
    });
  }
}

/// 書き出しの進み具合 + 広告の枠 (D-327)。[progress] が null(書き出していない)なら何も出さない = 書き出しが終わると
/// 広告の枠も閉じる。[onDark] = 加工画面(黒)の上: 中央に丸い進み具合と白い文字。
class MediaExportProgress extends StatelessWidget {
  const MediaExportProgress({super.key, required this.progress, required this.label, this.onDark = false, this.labelKey});
  final double? progress;
  final String label;
  final bool onDark;
  final Key? labelKey;

  @override
  Widget build(BuildContext context) {
    final p = progress;
    if (p == null) return const SizedBox.shrink();
    final text = '$label ${(p * 100).round()}%';
    if (onDark) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(value: p),
        Padding(padding: const EdgeInsets.only(top: 16), child: Text(text, key: labelKey, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center)),
        const ExportAdSlot(onDark: true),
      ]);
    }
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [Expanded(child: LinearProgressIndicator(value: p)), const SizedBox(width: RasqSpacing.sm), Text(text, key: labelKey, style: RasqTypography.caption)]),
      const Center(child: ExportAdSlot()),
    ]);
  }
}
