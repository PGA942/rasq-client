import 'dart:typed_data';

/// 画像の埋め込みの契約 (D-293)。返りは L2 正規化済み。読めなかった絵は null。
/// いまは SigLIP2 の画像側。第二期に、MiniLM の空間へ写した CNN 系(mobilenet)へ置き換える予定 —
/// そのときは [name] が変わり、索引は作り直しになる。
abstract class EmojiImageEmbedder {
  String get name;
  Future<List<List<double>?>> embedImages(List<Uint8List> encoded);
}
