import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:zxing2/qrcode.dart';

import '../../backend/link_match_api.dart' show LinkMatchAccount;
import '../../backend/orgate_client.dart';
import '../../backend/rasq_account.dart' show orgateAccountProvider;
import '../../backend/rasq_account_page_api.dart' show rasqAccountPageApiProvider;
import '../../l10n/l10n.dart';
import '../../shell/headers.dart';
import 'export_discover_screen.dart' show LinkMatchAccountCard;
import 'sns_discover_screen.dart' show discoverCameraSupported, discoverImagePickerProvider;

/// 友だちの QR から探す (D-553)。
///
/// - **自分の QR**: 自分の RASQ アカウントの Web のページ(Central の `/@<handle>`。端末のカメラで読むと「アプリで開く」のページ)。
/// - **友だちの QR を読む**: カメラで撮るか、画像を選ぶ → **端末で読む**(純 Dart の zxing2。画像はどこにも送らない)→
///   RASQ アカウントの QR(`<Central>/@<handle>` か `rasq://account/<handle>`)なら、その人を出す。
/// カメラの映像をその場で読むスキャナーは入れていない(ネイティブの依存を増やさないため。1 枚撮って読む)。

/// RASQ アカウントの Web のページ(QR の中身)。Central の起点のパス(`/api/v1` など)は捨てる。
String centralAccountUrl(Uri central, String handle) => Uri(scheme: central.scheme, host: central.host, port: central.hasPort ? central.port : null, path: '/@$handle').toString();

final _qrHandle = RegExp(r'^[A-Za-z0-9_.-]{1,64}$');

/// QR の文字 → RASQ のハンドル。`rasq://account/<handle>` か、この Central の `/@<handle>`(ほかのサイトの `/@name` は RASQ ではない)。
String? rasqHandleOfQr(String text, Uri? central) {
  final u = Uri.tryParse(text.trim());
  if (u == null) return null;
  final segs = u.pathSegments.where((s) => s.isNotEmpty).toList();
  String? handle;
  if (u.scheme == 'rasq' && u.host == 'account' && segs.isNotEmpty) {
    handle = segs.first.replaceFirst(RegExp(r'^@'), '');
  } else if ((u.scheme == 'https' || u.scheme == 'http') && central != null && u.host.toLowerCase() == central.host.toLowerCase() && segs.length == 1 && segs.first.startsWith('@')) {
    handle = segs.first.substring(1);
  }
  return handle != null && _qrHandle.hasMatch(handle) ? handle : null;
}

/// 画像の中の QR を読む(読めなければ null)。大きい画像は縮めてから。明るさの決め方を 2 通り試す。
String? decodeQrText(Uint8List bytes) {
  img.Image? image;
  try {
    image = img.decodeImage(bytes);
  } catch (_) {}
  if (image == null) return null;
  image = img.bakeOrientation(image);
  final long = image.width > image.height ? image.width : image.height;
  if (long > 1200) image = img.copyResize(image, width: image.width >= image.height ? 1200 : null, height: image.height > image.width ? 1200 : null);
  final pixels = image.convert(numChannels: 4).getBytes(order: img.ChannelOrder.abgr).buffer.asInt32List();
  final source = RGBLuminanceSource(image.width, image.height, pixels);
  for (final bitmap in [BinaryBitmap(HybridBinarizer(source)), BinaryBitmap(GlobalHistogramBinarizer(source))]) {
    try {
      return QRCodeReader().decode(bitmap).text;
    } catch (_) {}
  }
  return null;
}

/// QR を読む口(テストで差し替える)。端末では別の isolate で。
final qrDecoderProvider = Provider<Future<String?> Function(Uint8List)>((ref) => (bytes) => kIsWeb ? Future.value(decodeQrText(bytes)) : compute(decodeQrText, bytes));

class DiscoverQrScreen extends ConsumerStatefulWidget {
  const DiscoverQrScreen({super.key});
  @override
  ConsumerState<DiscoverQrScreen> createState() => _DiscoverQrScreenState();
}

class _DiscoverQrScreenState extends ConsumerState<DiscoverQrScreen> {
  bool _busy = false;
  String? _error;
  LinkMatchAccount? _found;

  Future<void> _read({required bool camera}) async {
    final l10n = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
      _found = null;
    });
    try {
      final picked = await ref.read(discoverImagePickerProvider)(camera: camera, limit: 1);
      if (picked.isEmpty) return;
      final text = await ref.read(qrDecoderProvider)(picked.first);
      if (!mounted) return;
      if (text == null) {
        setState(() => _error = l10n.onboardingQrNotFound);
        return;
      }
      final handle = rasqHandleOfQr(text, ref.read(centralBaseUrlProvider));
      if (handle == null) {
        setState(() => _error = l10n.onboardingQrNotRasq);
        return;
      }
      final api = ref.read(rasqAccountPageApiProvider);
      if (api == null) {
        setState(() => _error = l10n.onboardingDiscoverNoCentral);
        return;
      }
      try {
        final p = await api.profile(handle);
        if (mounted) setState(() => _found = LinkMatchAccount(id: p.id, handle: p.handle, displayName: p.displayName, avatarUrl: p.avatarUrl, bio: p.bio));
      } catch (e) {
        debugPrint('qr profile: $e');
        if (mounted) setState(() => _error = l10n.onboardingQrNoAccount(handle));
      }
    } catch (e) {
      debugPrint('qr read: $e');
      if (mounted) setState(() => _error = l10n.onboardingQrReadFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final caption = RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant);
    final bold = RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w700);
    final me = ref.watch(orgateAccountProvider).value;
    final central = ref.watch(centralBaseUrlProvider);
    final myUrl = me == null || central == null ? null : centralAccountUrl(central, me.handle);
    return Scaffold(
      appBar: RasqPageHeader(title: l10n.onboardingQrTitle, showMore: false),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(key: const ValueKey('discover.qr.list'), padding: const EdgeInsets.all(RasqSpacing.page), children: [
              Text(l10n.onboardingQrIntro, style: caption),
              const SizedBox(height: RasqSpacing.md),
              Text(l10n.onboardingQrReadHeading, style: bold),
              const SizedBox(height: RasqSpacing.xs),
              Wrap(spacing: RasqSpacing.xs, runSpacing: RasqSpacing.xs, children: [
                if (discoverCameraSupported)
                  FilledButton.icon(key: const ValueKey('discover.qr.camera'), onPressed: _busy ? null : () => _read(camera: true), icon: const Icon(Icons.photo_camera_outlined, size: 18), label: Text(l10n.onboardingQrCamera)),
                OutlinedButton.icon(key: const ValueKey('discover.qr.image'), onPressed: _busy ? null : () => _read(camera: false), icon: const Icon(Icons.photo_library_outlined, size: 18), label: Text(l10n.onboardingQrImage)),
              ]),
              if (_busy) const Padding(padding: EdgeInsets.all(RasqSpacing.md), child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
              if (_error != null) Padding(padding: const EdgeInsets.only(top: RasqSpacing.sm), child: Text(_error!, key: const ValueKey('discover.qr.error'), style: RasqTypography.bodySmall.copyWith(color: scheme.error))),
              if (_found != null) Padding(padding: const EdgeInsets.only(top: RasqSpacing.sm), child: LinkMatchAccountCard(account: _found!)),
              const SizedBox(height: RasqSpacing.lg),
              Text(l10n.onboardingQrMineHeading, style: bold),
              const SizedBox(height: RasqSpacing.xs),
              if (myUrl == null)
                Text(l10n.onboardingQrMineNone, key: const ValueKey('discover.qr.mine.none'), style: caption)
              else ...[
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(RasqSpacing.sm),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                    child: QrImageView(
                      key: const ValueKey('discover.qr.mine'),
                      data: myUrl,
                      size: 200,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
                      dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
                    ),
                  ),
                ),
                const SizedBox(height: RasqSpacing.xs),
                Center(child: Text('@${me!.handle}', style: RasqTypography.bodySmall)),
                Center(child: Text(l10n.onboardingQrMineHint, style: caption, textAlign: TextAlign.center)),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}
