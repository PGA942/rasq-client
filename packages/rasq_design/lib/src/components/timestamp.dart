import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/design_l10n.dart';

enum RasqTimestampMode {
  /// "3分前" / "2時間前" / "3日前" / "2017年2月".
  relative,

  /// "残り 12分" — counts down to [RasqTimestamp.time].
  remaining,

  /// "2026/08/22 14:30".
  absolute,
}

/// L2 atomic `Timestamp`. Relative / remaining modes re-render every minute.
class RasqTimestamp extends StatefulWidget {
  const RasqTimestamp(this.time, {super.key, this.mode = RasqTimestampMode.relative, this.style, this.now});

  final DateTime time;
  final RasqTimestampMode mode;
  final TextStyle? style;

  /// Injectable clock for tests.
  final DateTime Function()? now;

  /// 文言と日付の書式は、いまの表示の言語([RasqUiLocale]、D-484)。
  static String format(DateTime time, {RasqTimestampMode mode = RasqTimestampMode.relative, DateTime? now}) {
    final n = now ?? DateTime.now();
    switch (mode) {
      case RasqTimestampMode.absolute:
        return '${time.year}/${_two(time.month)}/${_two(time.day)} ${_two(time.hour)}:${_two(time.minute)}';
      case RasqTimestampMode.remaining:
        final l = rasqDesignL10n;
        final d = time.difference(n);
        if (d.isNegative) return l.designTimeEnded;
        if (d.inDays >= 1) return l.designTimeRemainingDays(d.inDays);
        if (d.inHours >= 1) return l.designTimeRemainingHours(d.inHours);
        if (d.inMinutes >= 1) return l.designTimeRemainingMinutes(d.inMinutes);
        return l.designTimeRemainingSeconds(d.inSeconds);
      case RasqTimestampMode.relative:
        final l = rasqDesignL10n;
        final d = n.difference(time);
        if (d.inSeconds < 60) return l.designTimeJustNow;
        if (d.inMinutes < 60) return l.designTimeMinutesAgo(d.inMinutes);
        if (d.inHours < 24) return l.designTimeHoursAgo(d.inHours);
        if (d.inDays < 30) return l.designTimeDaysAgo(d.inDays);
        // 日付は表示の言語の書式 (D-484): 日本語は `8月31日` / `2017年2月`。
        if (time.year == n.year) return RasqDateFormat.monthDay(time);
        return RasqDateFormat.yearMonth(time);
    }
  }

  static String _two(int v) => v.toString().padLeft(2, '0');

  @override
  State<RasqTimestamp> createState() => _RasqTimestampState();
}

class _RasqTimestampState extends State<RasqTimestamp> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.mode != RasqTimestampMode.absolute) {
      _timer = Timer.periodic(const Duration(minutes: 1), (_) => setState(() {}));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style ?? Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    return Text(
      RasqTimestamp.format(widget.time, mode: widget.mode, now: widget.now?.call()),
      style: style,
      semanticsLabel: RasqTimestamp.format(widget.time, mode: RasqTimestampMode.absolute),
    );
  }
}
