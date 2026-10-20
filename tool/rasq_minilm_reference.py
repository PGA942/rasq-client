#!/usr/bin/env python3
"""test/fixtures/rasq_minilm_reference.json の norm_dot を作り直す (D-522)。

texts / ids(tokenizer.json の id)はそのまま使い、モデルだけを回す。端末と同じ onnxruntime 1.15.1・同じ形
(8 文を 1 回で、最長に右詰め、pad_id 1、attention_mask は float32 で詰め物は 0)で `embedding` を出し、
L2 正規化したベクトルどうしの内積の行列を書く。

    docker run --rm -v "$PWD:$PWD" -w "$PWD" python:3.11 sh -c \\
      "pip install -q onnxruntime==1.15.1 numpy==1.26.4 patchelf && \\
       patchelf --clear-execstack /usr/local/lib/python3.11/site-packages/onnxruntime/capi/onnxruntime_pybind11_state*.so && \\
       python tool/rasq_minilm_reference.py MODEL.onnx SHA256"
(1.15.1 の共有ライブラリは実行可能なスタックを要求していて、新しいカーネルでは読めないので patchelf で外す。)
"""

import json
import sys

import numpy as np
import onnxruntime as ort

FIXTURE = "test/fixtures/rasq_minilm_reference.json"


def main(model: str, sha: str) -> None:
    ref = json.load(open(FIXTURE, encoding="utf-8"))
    ids = ref["ids"]
    n = max(len(x) for x in ids)
    input_ids = np.array([x + [1] * (n - len(x)) for x in ids], dtype=np.int64)
    mask = np.array([[1.0] * len(x) + [0.0] * (n - len(x)) for x in ids], dtype=np.float32)
    s = ort.InferenceSession(model, providers=["CPUExecutionProvider"])
    e = s.run(["embedding"], {"input_ids": input_ids, "attention_mask": mask})[0]
    e = e / np.linalg.norm(e, axis=1, keepdims=True)
    ref["norm_dot"] = [[round(float(v), 6) for v in row] for row in (e @ e.T)]
    ref["model"] = "text_tower_uint8.onnx"
    ref["model_sha256"] = sha
    ref["generated"] = (
        f"tool/rasq_minilm_reference.py, onnxruntime {ort.__version__}, 1 batch of {len(ids)} (pad_id 1, float32 mask) (D-522). "
        "The previous norm_dot came from the earlier D-390 uint8 quantisation of the text tower."
    )
    with open(FIXTURE, "w", encoding="utf-8") as f:
        json.dump(ref, f, ensure_ascii=False)
        f.write("\n")
    print(f"wrote {FIXTURE} with onnxruntime {ort.__version__}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
