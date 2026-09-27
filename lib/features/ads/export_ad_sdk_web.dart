import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import 'export_ad.dart';

ExportAdSdk createExportAdSdk() => _AdSenseSdk();

/// AdSense (D-327): `<ins class="adsbygoogle">` を platform view に置く。AdSense は動画を保証しないので、表示広告になる。
///
/// スクリプト(`adsbygoogle.js`)は最初の枠を出すときに 1 回だけ読み込む(読み込めなければ = 広告ブロック等、枠を消す)。
/// 埋まらなかった(`data-ad-status="unfilled"`)/ 決まらないまま時間が過ぎたら、枠を消す。個人に合わせない広告だけを頼む。
/// 同意は AdSense 側(プライバシーとメッセージ)の CMP に任せる。デバッグのビルドは `data-adtest="on"`。
class _AdSenseSdk implements ExportAdSdk {
  static const _viewType = 'rasq-export-ad';
  static const _height = 250.0;
  Future<bool>? _script;
  bool _registered = false;

  Future<bool> _loadScript(String client) => _script ??= () {
        final done = Completer<bool>();
        final script = web.HTMLScriptElement()
          ..async = true
          ..crossOrigin = 'anonymous'
          ..src = 'https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=${Uri.encodeQueryComponent(client)}';
        void settle(bool ok) {
          if (!done.isCompleted) done.complete(ok);
        }

        script.addEventListener('load', ((web.Event _) => settle(true)).toJS);
        script.addEventListener('error', ((web.Event _) => settle(false)).toJS);
        web.document.head?.append(script);
        return done.future.timeout(const Duration(seconds: 15), onTimeout: () => false);
      }();

  void _register(ExportAdConfig config) {
    if (_registered) return;
    _registered = true;
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId, {Object? params}) {
      final p = params! as _ViewParams;
      final ins = web.HTMLModElement.ins()
        ..className = 'adsbygoogle'
        ..setAttribute('data-ad-client', config.adsenseClient)
        ..setAttribute('data-ad-slot', config.adsenseSlot)
        ..setAttribute('data-ad-format', 'rectangle, horizontal')
        ..setAttribute('style', 'display:block;width:100%;height:100%');
      if (kDebugMode) ins.setAttribute('data-adtest', 'on');
      final box = web.HTMLDivElement()..setAttribute('style', 'width:100%;height:100%;overflow:hidden');
      box.append(ins);
      _fill(ins, p);
      return box;
    });
  }

  /// 画面に付いてから頼み、結果(`data-ad-status`)を見る。
  void _fill(web.HTMLElement ins, _ViewParams p) {
    var tries = 0;
    Timer.periodic(const Duration(milliseconds: 100), (t) {
      tries++;
      if (!ins.isConnected) {
        if (tries > 50) {
          t.cancel();
          p.onFailed();
        }
        return;
      }
      t.cancel();
      try {
        var queue = globalContext['adsbygoogle'];
        if (queue == null) {
          queue = JSArray<JSAny?>();
          globalContext['adsbygoogle'] = queue;
        }
        final q = queue as JSObject;
        q['requestNonPersonalizedAds'] = 1.toJS;
        q.callMethod('push'.toJS, JSObject());
      } catch (e) {
        debugPrint('export ad: adsense push failed: $e');
        return p.onFailed();
      }
      var waited = 0;
      Timer.periodic(const Duration(milliseconds: 500), (w) {
        waited++;
        final status = ins.getAttribute('data-ad-status');
        if (status == 'filled') {
          w.cancel();
          p.onLoaded();
        } else if (status == 'unfilled' || waited > 30) {
          w.cancel();
          p.onFailed();
        }
      });
    });
  }

  @override
  Widget buildAd({required ExportAdNetwork network, required ExportAdConfig config, required double width, required VoidCallback onLoaded, required VoidCallback onFailed}) {
    if (network != ExportAdNetwork.adsense || !config.hasAdsense) {
      scheduleMicrotask(onFailed);
      return const SizedBox.shrink();
    }
    return _AdSenseView(sdk: this, config: config, width: width, onLoaded: onLoaded, onFailed: onFailed);
  }
}

class _ViewParams {
  _ViewParams(this.onLoaded, this.onFailed);
  final VoidCallback onLoaded;
  final VoidCallback onFailed;
}

class _AdSenseView extends StatefulWidget {
  const _AdSenseView({required this.sdk, required this.config, required this.width, required this.onLoaded, required this.onFailed});
  final _AdSenseSdk sdk;
  final ExportAdConfig config;
  final double width;
  final VoidCallback onLoaded;
  final VoidCallback onFailed;

  @override
  State<_AdSenseView> createState() => _AdSenseViewState();
}

class _AdSenseViewState extends State<_AdSenseView> {
  bool _ready = false;
  bool _settled = false;
  late final _params = _ViewParams(() => _settle(widget.onLoaded), () => _settle(widget.onFailed));

  void _settle(VoidCallback f) {
    if (_settled || !mounted) return;
    _settled = true;
    f();
  }

  @override
  void initState() {
    super.initState();
    widget.sdk._loadScript(widget.config.adsenseClient).then((ok) {
      if (!mounted) return;
      if (!ok) return _settle(widget.onFailed);
      widget.sdk._register(widget.config);
      setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const SizedBox.shrink();
    return SizedBox(width: widget.width, height: _AdSenseSdk._height, child: HtmlElementView(viewType: _AdSenseSdk._viewType, creationParams: _params));
  }
}
