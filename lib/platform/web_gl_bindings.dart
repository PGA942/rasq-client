// three_js が Web で描くのに要る JS(`web/vendor/flutter_angle/gles_bindings.js`)が読み込まれているか (D-304)。端末では常に false(使わない)。
export 'web_gl_bindings_io.dart' if (dart.library.js_interop) 'web_gl_bindings_web.dart';
