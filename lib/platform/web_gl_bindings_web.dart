import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// `glCanvas` は gles_bindings.js が置く関数。無いまま three_js を作ると、最初のフレームが返らず**アプリごと起動しなくなる** (D-303)。
bool webGlBindingsLoaded() => globalContext.has('glCanvas');
