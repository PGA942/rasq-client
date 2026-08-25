/// RRL (RASQ Rendering Language) core — framework-free node model for the
/// `rasq.boundary/1` wire (rasq-sdk-sample/PROTOCOL.md, draft v0.1).
///
/// - [RrlNode]: one node of the tree (`t`/`k`/`tag`/`role`/`p`/`on`/`c`)
/// - [RrlScope]: `$.path` Bind resolution + `{{expr}}` key templates
/// - [RrlDocument]: snapshot + atomic patch batches (rev / baseRev, D-001)
///
/// No Flutter here: the renderer (`rrl_renderer`) and the plugin runtime both
/// consume this, and it can be unit-tested against the JSON schemas in
/// `rasq-sdk-sample/schema/`.
library;

export 'src/bind.dart';
export 'src/document.dart';
export 'src/node.dart';
