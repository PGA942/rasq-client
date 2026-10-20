import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';

import '../../../l10n/l10n.dart';
import 'region.dart';

/// 住んでいる地域を選ぶ(D-542)。国を名前で探して選ぶ。アメリカは続けて州を選ぶ。選んだコードを返す(戻ったら null)。
/// 提供していない地域にも印を付けて出す(選べば、呼んだ側が [RegionUnavailableScreen] を出す)。
Future<String?> pickRegion(BuildContext context) =>
    Navigator.of(context).push<String>(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const RegionPickerScreen()));

/// 提供していない地域を選んだとき / 作るときにサーバーが断ったときの画面。作成へは進めない(戻るだけ)。
Future<void> showRegionUnavailable(NavigatorState navigator, String? region) =>
    navigator.push<void>(MaterialPageRoute(builder: (_) => RegionUnavailableScreen(region: region)));

class RegionPickerScreen extends ConsumerStatefulWidget {
  const RegionPickerScreen({super.key});

  @override
  ConsumerState<RegionPickerScreen> createState() => _RegionPickerScreenState();
}

class _RegionPickerScreenState extends ConsumerState<RegionPickerScreen> {
  final _query = TextEditingController();

  /// 州を選んでいる国(アメリカ)。null = 国の一覧。
  RasqCountry? _country;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _choose(RasqCountry c) {
    if (c.code == regionSubdivided && c.available && c.subdivisions.isNotEmpty) {
      setState(() {
        _country = c;
        _query.clear();
      });
      return;
    }
    Navigator.of(context).pop(c.code);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final regions = ref.watch(rasqRegionsProvider);
    final country = _country;
    final badge = Text(l.regionUnavailableBadge, style: RasqTypography.caption.copyWith(color: scheme.error));
    Widget body;
    if (regions.isLoading && !regions.hasValue) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      final r = regions.value ?? RasqRegions.fallback();
      final q = _query.text;
      final List<Widget> tiles;
      if (country == null) {
        final list = r.countries.where((c) => regionMatches(c.code, q)).toList()..sort((a, b) => regionSortKey(a.code).compareTo(regionSortKey(b.code)));
        tiles = [
          for (final c in list)
            ListTile(
              key: ValueKey('region.country.${c.code}'),
              title: Text(regionName(c.code)),
              trailing: !r.isAvailable(c.code) ? badge : (c.code == regionSubdivided ? const Icon(Icons.chevron_right) : null),
              onTap: () => _choose(c),
            ),
        ];
      } else {
        final list = country.subdivisions.where((s) => regionMatches(s.code, q)).toList()..sort((a, b) => regionSortKey(a.code).compareTo(regionSortKey(b.code)));
        tiles = [
          for (final s in list)
            ListTile(
              key: ValueKey('region.state.${s.code}'),
              title: Text(regionStateName(s.code)),
              trailing: !r.isAvailable(s.code) ? badge : null,
              onTap: () => Navigator.of(context).pop(s.code),
            ),
        ];
      }
      body = tiles.isEmpty
          ? Center(child: Text(l.regionNoMatch, style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant)))
          : ListView(key: const ValueKey('region.list'), children: tiles);
    }
    return PopScope(
      canPop: country == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _country = null);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(country == null ? l.regionPickerTitle : l.regionStatePickerTitle),
          leading: country == null ? null : BackButton(onPressed: () => setState(() => _country = null)),
        ),
        body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, RasqSpacing.xs),
            child: TextField(
              key: const ValueKey('region.search'),
              controller: _query,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: country == null ? l.regionSearchHint : l.regionStateSearchHint),
            ),
          ),
          Expanded(child: body),
        ]),
      ),
    );
  }
}

/// 「お住まいの地域では、いまは RASQ を提供していません」。理由には触れない短い説明だけで、作成へ進む手段は出さない
/// (戻る / アプリを閉じることはできる)。
class RegionUnavailableScreen extends StatelessWidget {
  const RegionUnavailableScreen({super.key, this.region});

  /// 選んだ地域のコード(わからなければ null)。
  final String? region;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final region = this.region;
    return Scaffold(
      key: const ValueKey('region.unavailable'),
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(RasqSpacing.page),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Icon(Icons.public_off_outlined, size: 48, color: scheme.onSurfaceVariant),
                const SizedBox(height: RasqSpacing.md),
                Text(l.regionUnavailableTitle, textAlign: TextAlign.center, style: RasqTypography.title),
                const SizedBox(height: RasqSpacing.sm),
                Text(
                  region == null ? l.regionUnavailableBody : l.regionUnavailableBodyWith(regionName(region)),
                  textAlign: TextAlign.center,
                  style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: RasqSpacing.lg),
                OutlinedButton(
                  key: const ValueKey('region.unavailable.back'),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l.regionUnavailableBack),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
