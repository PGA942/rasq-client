import 'package:meta/meta.dart';

/// One page of a cursor-paginated list. [nextCursor] is opaque to the host
/// (plugins choose their own encoding, e.g. Misskey `untilId`).
@immutable
class Page<T> {
  const Page({required this.items, this.nextCursor});
  final List<T> items;
  final String? nextCursor;
  bool get hasMore => nextCursor != null;

  Page<R> map<R>(R Function(T) f) => Page(items: items.map(f).toList(), nextCursor: nextCursor);
  static Page<T> empty<T>() => Page<T>(items: const []);
}
