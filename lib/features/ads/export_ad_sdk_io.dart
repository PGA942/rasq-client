import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'export_ad.dart';

ExportAdSdk createExportAdSdk() => _AdMobSdk();

/// AdMob (D-327): インラインのアダプティブバナー(幅はそのまま、高さは 250 まで)。
///
/// ネイティブ広告(MediaView)ではなくバナーにしたのは、書き出しの待ち時間の表示が 280px の小型カラムの FOW から
/// 全画面の加工画面まで幅が変わるため(インラインのアダプティブは幅に合わせて大きさを選び、高さに余裕があれば
/// MREC 大の動画の広告も入る)。ネイティブは端末ごとの描き方(ファクトリー / テンプレート)と表示の決まりが要る。
class _AdMobSdk implements ExportAdSdk {
  Future<bool>? _ready;

  /// 初回だけ: 同意 (UMP) の情報を取り直し、広告を頼めるときだけ SDK を初期化する。
  /// 同意の画面は出さない(書き出しの途中に割り込ませない)。同意が要ってまだ無ければ、この起動の間は出さない。
  Future<bool> ready() => _ready ??= _prepare();

  Future<bool> _prepare() async {
    try {
      final consent = ConsentInformation.instance;
      final updated = Completer<void>();
      void done() {
        if (!updated.isCompleted) updated.complete();
      }

      // 取り直せなくても(オフライン等)、前回の同意で頼めるかは分かる。
      consent.requestConsentInfoUpdate(ConsentRequestParameters(), done, (_) => done());
      await updated.future.timeout(const Duration(seconds: 10), onTimeout: () {});
      if (!await consent.canRequestAds()) return false;
      // 子のアカウントには出さない(呼ばれない)。それ以外にも、年齢の幅があるので内容は T(10 代〜)まで。
      await MobileAds.instance.updateRequestConfiguration(RequestConfiguration(maxAdContentRating: MaxAdContentRating.t));
      await MobileAds.instance.initialize();
      return true;
    } catch (e) {
      debugPrint('export ad: admob unavailable: $e');
      return false;
    }
  }

  @override
  Widget buildAd({required ExportAdNetwork network, required ExportAdConfig config, required double width, required VoidCallback onLoaded, required VoidCallback onFailed}) {
    if (network != ExportAdNetwork.admob) {
      scheduleMicrotask(onFailed);
      return const SizedBox.shrink();
    }
    return _AdMobBanner(sdk: this, unitId: config.admobUnitFor(defaultTargetPlatform), width: width, onLoaded: onLoaded, onFailed: onFailed);
  }
}

class _AdMobBanner extends StatefulWidget {
  const _AdMobBanner({required this.sdk, required this.unitId, required this.width, required this.onLoaded, required this.onFailed});
  final _AdMobSdk sdk;
  final String unitId;
  final double width;
  final VoidCallback onLoaded;
  final VoidCallback onFailed;

  @override
  State<_AdMobBanner> createState() => _AdMobBannerState();
}

class _AdMobBannerState extends State<_AdMobBanner> {
  BannerAd? _ad;
  AdSize? _size;
  bool _settled = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _fail() {
    if (_settled) return;
    _settled = true;
    widget.onFailed();
  }

  Future<void> _load() async {
    if (!await widget.sdk.ready()) return _fail();
    if (!mounted) return;
    final ad = BannerAd(
      adUnitId: widget.unitId,
      size: AdSize.getInlineAdaptiveBannerAdSize(widget.width.floor(), 250),
      request: const AdRequest(nonPersonalizedAds: true),
      listener: BannerAdListener(
        onAdLoaded: (ad) async {
          final size = await (ad as BannerAd).getPlatformAdSize();
          if (!mounted || !identical(ad, _ad)) return;
          if (size == null) return _fail();
          setState(() => _size = size);
          if (!_settled) {
            _settled = true;
            widget.onLoaded();
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('export ad: admob failed to load: ${error.code} ${error.message}');
          ad.dispose();
          if (identical(ad, _ad)) _ad = null;
          if (mounted) _fail();
        },
      ),
    );
    _ad = ad;
    unawaited(ad.load());
  }

  @override
  void dispose() {
    _ad?.dispose();
    _ad = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    final size = _size;
    if (ad == null || size == null) return const SizedBox.shrink();
    return SizedBox(width: size.width.toDouble(), height: size.height.toDouble(), child: AdWidget(ad: ad));
  }
}
