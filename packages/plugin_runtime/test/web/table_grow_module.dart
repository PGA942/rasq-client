import 'dart:typed_data';

/// `table.grow` を試すゲスト (D-546)。ブラウザのテスト (`wasm_web_table_test.dart`) と、端末版のランタイムで書き換えた後も
/// 正しい wasm かを見る VM のテスト (`wasm_web_guard_test.dart`) の両方で使う(dart:io を使わない)。

// ブラウザ (dart2js) のビット演算は 32 ビットなので、LEB128 は割り算で作る(i64 の値も扱うため)。
List<int> _leb(int v) {
  final out = <int>[];
  do {
    var b = v % 128;
    v = v ~/ 128;
    if (v != 0) b |= 0x80;
    out.add(b);
  } while (v != 0);
  return out;
}

/// 符号付き LEB128(0 以上の値だけ)。
List<int> _sleb(int v) {
  assert(v >= 0);
  final out = <int>[];
  while (true) {
    final b = v % 128;
    v = v ~/ 128;
    if (v == 0 && b < 0x40) {
      out.add(b);
      return out;
    }
    out.add(b | 0x80);
  }
}

List<int> _section(int id, List<int> body) => [id, ..._leb(body.length), ...body];
List<int> _vec(List<List<int>> items) => [..._leb(items.length), for (final i in items) ...i];
List<int> _name(String s) => [..._leb(s.length), ...s.codeUnits];
List<int> _body(List<int> code) => [..._leb(code.length + 1), 0x00, ...code]; // ローカル変数なし

/// 最小の ABI を満たすモジュール。テーブル 1 本(初期 1 要素・**最大なし**)を持ち、`start` で
/// `table.grow(ref.null func, grow)` する。snapshot は失敗(-1)なら "refused"、伸びたら "grown" を返す。
/// (wat: `(table 1 funcref) (start $s) (func $s (global.set $g (table.grow 0 (ref.null func) (i32.const grow))))` …)
Uint8List tableGrowModule(int grow) {
  int packed(int ptr, int len) => ptr * 0x100000000 + len;
  return Uint8List.fromList([
    0x00, 0x61, 0x73, 0x6d, 1, 0, 0, 0,
    ..._section(1, _vec([
      [0x60, 0, 0], // 0: () -> ()
      [0x60, 1, 0x7f, 1, 0x7f], // 1: (i32) -> i32
      [0x60, 2, 0x7f, 0x7f, 0], // 2: (i32, i32) -> ()
      [0x60, 0, 1, 0x7e], // 3: () -> i64
      [0x60, 6, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 1, 0x7e], // 4: (i32 x 6) -> i64
    ])),
    ..._section(3, _vec([[0], [1], [2], [3], [3], [4]])), // start / alloc / dealloc / snapshot / patch / call
    ..._section(4, _vec([[0x70, 0x00, 1]])), // (table 1 funcref)
    ..._section(5, _vec([[0x00, 1]])), // (memory 1)
    ..._section(6, _vec([[0x7f, 0x01, 0x41, 0x00, 0x0b]])), // (global $g (mut i32) (i32.const 0))
    ..._section(7, _vec([
      [..._name('memory'), 0x02, 0],
      [..._name('alloc'), 0x00, 1],
      [..._name('dealloc'), 0x00, 2],
      [..._name('snapshot'), 0x00, 3],
      [..._name('patch'), 0x00, 4],
      [..._name('call'), 0x00, 5],
    ])),
    ..._section(8, _leb(0)), // (start $s)
    ..._section(10, _vec([
      // $s: global.set $g (table.grow 0 (ref.null func) (i32.const grow))
      _body([0xd0, 0x70, 0x41, ..._sleb(grow), 0xfc, 0x0f, 0, 0x24, 0, 0x0b]),
      _body([0x41, ..._sleb(1024), 0x0b]), // alloc
      _body([0x0b]), // dealloc
      // snapshot: (if (result i64) (i32.eq (global.get $g) (i32.const -1)) "refused" "grown")
      _body([0x23, 0, 0x41, 0x7f, 0x46, 0x04, 0x7e, 0x42, ..._sleb(packed(16, 7)), 0x05, 0x42, ..._sleb(packed(32, 5)), 0x0b, 0x0b]),
      _body([0x10, 3, 0x0b]), // patch = snapshot
      _body([0x42, 0, 0x0b]), // call
    ])),
    ..._section(11, _vec([
      [0x00, 0x41, 16, 0x0b, ..._name('refused')],
      [0x00, 0x41, 32, 0x0b, ..._name('grown')],
    ])),
  ]);
}
