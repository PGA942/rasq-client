# 同梱モデル (D-216)

`tool/fetch_rai_models.sh` を実行すると、RAi のローカルモデル 3 つ(Qwen3.5 2B / Agents-A1 4B / Qwen3.5 0.8B、Q4_K_M)を
HF から取得して gzip し、このフォルダーに `<fileName>.gz` として置く。ビルドに含まれ、アプリでは「展開(同梱)」で
`Application Support/rai_models/` へ伸長する。`.gz` は git に入れない(無ければ従来どおりダウンロード)。
