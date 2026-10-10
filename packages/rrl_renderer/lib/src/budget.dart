import 'package:rrl_core/rrl_core.dart';

import 'registry.dart';

/// 1 つの [RrlRenderer] が組んでよい量 (セキュリティ確認 2026-10-09 の [4])。RRL はプラグインが返すデータで、
/// `ForEach` の入れ子は小さな JSON でも項目数の積だけウィジェットになる(100 項目 × 5 段 = 100^5)。WASM の燃料 / メモリの
/// 上限はゲストが返した後のホストの画面組み立てには効かないので、ウィジェットを作る前に、木全体で 1 つの予算で数える。
class RrlBudget {
  const RrlBudget({this.maxNodes = 10000, this.maxIterations = 10000, this.maxDepth = 64});

  /// 展開した後のノードの数(`ForEach` の項目ごとに子を数え直す。`If` の偽の枝は数えない)。
  final int maxNodes;

  /// `ForEach` の繰り返しの合計(入れ子もすべて足す。子が無くても数える)。
  final int maxIterations;

  /// 入れ子の深さ。
  final int maxDepth;

  /// ふつうの面の予算。ホストが組む設定 / 見本の木もこの中に収まる。
  static const standard = RrlBudget();
}

/// [root] を [scope] で展開したときに [budget] を超えるなら、その理由。収まれば null。
/// 描くときと同じ規則(`ForEach` は `{item, index}`、`Bind` は名前を積む、`If` は偽なら中を見ない)で数え、
/// 超えた時点でやめる(数える手間も予算の分だけ)。
String? rrlExpansionOverBudget(RrlNode root, RrlScope scope, [RrlBudget budget = RrlBudget.standard]) {
  var nodes = 0;
  var iterations = 0;
  String? over;
  void walk(RrlNode node, RrlScope s, int depth) {
    if (over != null) return;
    if (depth > budget.maxDepth) {
      over = 'too deep (> ${budget.maxDepth})';
      return;
    }
    if (++nodes > budget.maxNodes) {
      over = 'too many nodes (> ${budget.maxNodes})';
      return;
    }
    switch (node.t) {
      case 'If':
        if (!rrlTruthy(s.resolveProp(node.p['cond']))) return;
      case 'ForEach':
        final items = rrlList(s.resolveProp(node.p['in']));
        for (var i = 0; i < items.length && over == null; i++) {
          if (++iterations > budget.maxIterations) {
            over = 'too many iterations (> ${budget.maxIterations})';
            return;
          }
          final itemScope = s.push({'item': items[i], 'index': i});
          for (final c in node.c) {
            walk(c, itemScope, depth + 1);
          }
        }
        return;
      case 'Bind':
        final name = rrlString(s.resolveProp(node.p['name']), 'value');
        final childScope = s.push({name: s.resolveProp(node.p['value'])});
        for (final c in node.c) {
          walk(c, childScope, depth + 1);
        }
        return;
    }
    for (final c in node.c) {
      walk(c, s, depth + 1);
    }
  }

  walk(root, scope, 1);
  return over;
}
