#!/usr/bin/env python3
"""int8 の重みの ONNX を uint8 の重みに直す (D-522)。

RASQ の MiniLM / MobileNet(D-390)の配布版は、ConvInteger / MatMulInteger の重みが int8。
端末の onnxruntime 1.15 は ConvInteger(int8 の重み)の実装が無く読めないので、重みを uint8 に直す。
値はずらすだけで、計算結果は変わらない:

    w_u8 = w_i8 + 128,  zp_u8 = zp_i8 + 128   (w - zp が同じ)

- 直すのは ConvInteger の入力 1(w)/ 3(w_zero_point)と MatMulInteger の入力 1(B)/ 3(b_zero_point)の初期値だけ。
  零点が無ければ(= 0)、128 の uint8 の零点を足す。
- 活性側(DynamicQuantizeLinear の出力)はもとから uint8 なので触らない。
- それ以外の int8 の値(ほかのノードが使う int8 の初期値、int8 の Constant、int8 の入出力、サブグラフ)があれば止める。

使い方(Docker の python:3.12 で):
    docker run --rm -v "$PWD:$PWD" -w "$PWD" python:3.12 sh -c \\
      "pip install -q onnx==1.17.0 && python tool/requantize_uint8.py IN_int8.onnx OUT_uint8.onnx"
"""

import sys

import numpy as np
import onnx
from onnx import TensorProto, numpy_helper

# op_type → 直す入力の位置(重み, 重みの零点)
WEIGHT_SLOTS = {"ConvInteger": (1, 3), "MatMulInteger": (1, 3)}


def fail(msg: str) -> None:
    sys.exit(f"requantize_uint8: {msg}")


def main(src: str, dst: str) -> None:
    model = onnx.load(src)
    g = model.graph
    inits = {t.name: t for t in g.initializer}

    # サブグラフは扱わない(この塔には無いはず)。
    for n in g.node:
        for a in n.attribute:
            if a.type in (onnx.AttributeProto.GRAPH, onnx.AttributeProto.GRAPHS):
                fail(f"subgraph in node {n.name} ({n.op_type}) is not supported")
            if a.type == onnx.AttributeProto.TENSOR and a.t.data_type == TensorProto.INT8:
                fail(f"int8 tensor attribute in node {n.name} ({n.op_type})")

    # 直してよい int8 の初期値 = 重み / 重みの零点の位置にだけ現れるもの。
    allowed: set[str] = set()
    added_zp = 0
    for n in g.node:
        slots = WEIGHT_SLOTS.get(n.op_type)
        if slots is None:
            continue
        w_idx, zp_idx = slots
        w = n.input[w_idx] if len(n.input) > w_idx else ""
        if w not in inits:
            fail(f"{n.op_type} {n.name}: weight {w!r} is not an initializer")
        if inits[w].data_type != TensorProto.INT8:
            fail(f"{n.op_type} {n.name}: weight {w!r} is not int8 (type {inits[w].data_type})")
        allowed.add(w)
        zp = n.input[zp_idx] if len(n.input) > zp_idx else ""
        if zp == "":
            # 零点が無い = 0(int8)→ uint8 では 128。スカラーで足す(ConvInteger / MatMulInteger とも可)。
            name = f"{w}_zero_point_u8"
            if name not in inits:
                t = numpy_helper.from_array(np.array(128, dtype=np.uint8), name)
                g.initializer.append(t)
                inits[name] = t
            while len(n.input) < zp_idx:
                n.input.append("")
            n.input.append(name)
            added_zp += 1
        else:
            if zp not in inits:
                fail(f"{n.op_type} {n.name}: weight zero point {zp!r} is not an initializer")
            if inits[zp].data_type != TensorProto.INT8:
                fail(f"{n.op_type} {n.name}: weight zero point {zp!r} is not int8")
            allowed.add(zp)

    # 直す初期値を、ほかのノード(の別の位置)が使っていないこと。
    for n in g.node:
        for i, name in enumerate(n.input):
            if name not in allowed:
                continue
            slots = WEIGHT_SLOTS.get(n.op_type)
            if slots is None or i not in slots:
                fail(f"int8 initializer {name!r} is also used by {n.op_type} {n.name} input {i}")

    # それ以外の int8 は分からないので止める。
    for t in g.initializer:
        if t.data_type == TensorProto.INT8 and t.name not in allowed:
            fail(f"unhandled int8 initializer {t.name!r}")
    for v in list(g.input) + list(g.output):
        if v.type.tensor_type.elem_type == TensorProto.INT8 and v.name not in allowed:
            fail(f"unhandled int8 graph input/output {v.name!r}")
    for v in g.value_info:
        if v.type.tensor_type.elem_type == TensorProto.INT8:
            fail(f"unhandled int8 value {v.name!r}")

    # ずらす: w_u8 = w_i8 + 128。
    converted = 0
    for i, t in enumerate(g.initializer):
        if t.name not in allowed:
            continue
        a = numpy_helper.to_array(t).astype(np.int16) + 128
        if a.min() < 0 or a.max() > 255:
            fail(f"{t.name}: out of range after shift")
        g.initializer[i].CopyFrom(numpy_helper.from_array(a.astype(np.uint8), t.name))
        converted += 1
    # 古い形式で初期値が入力にも載っていれば、型を合わせる。
    for v in g.input:
        if v.name in allowed:
            v.type.tensor_type.elem_type = TensorProto.UINT8

    onnx.checker.check_model(model)
    onnx.save(model, dst)
    print(f"converted {converted} int8 initializers to uint8 (+{added_zp} zero points added) -> {dst}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
