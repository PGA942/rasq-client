import 'dart:async';

import 'package:flutter/material.dart';

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

  static String format(DateTime time, {RasqTimestampMode mode = RasqTimestampMode.relative, DateTime? now}) {
    final n = now ?? DateTime.now();
    switch (mode) {
      case RasqTimestampMode.absolute:
        return '${time.year}/${_two(time.month)}/${_two(time.day)} ${_two(time.hour)}:${_two(time.minute)}';
      case RasqTimestampMode.remaining:
        final d = time.difference(n);
        if (d.isNegative) return '終了';
        if (d.inDays >= 1) return '残り ${d.inDays}日';
        if (d.inHours >= 1) return '残り ${d.inHours}時間';
        if (d.inMinutes >= 1) return '残り ${d.inMinutes}分';
        return '残り ${d.inSeconds}秒';
      case RasqTimestampMode.relative:
        final d = n.difference(time);
        if (d.inSeconds < 60) return 'たった今';
        if (d.inMinutes < 60) return '${d.inMinutes}分前';
        if (d.inHours < 24) return '${d.inHours}時間前';
        if (d.inDays < 30) return '${d.inDays}日前';
        if (time.year == n.year) return '${time.month}月${time.day}日';
        return '${time.year}年${time.month}月';
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
