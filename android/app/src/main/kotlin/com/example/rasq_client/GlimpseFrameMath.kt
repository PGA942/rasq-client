package com.example.rasq_client

/**
 * 画面の読み取り (D-416) の小さな計算。Android の API に触らない(JVM の単体テストで確かめる)。
 */
object GlimpseFrameMath {
    /** 読み取りの id(フォルダー名)に使える形。Dart 側と同じ。 */
    private val idPattern = Regex("^[a-z0-9-]{8,64}$")

    fun isValidId(id: String?): Boolean = id != null && idPattern.matches(id)

    /**
     * 長辺を [longEdge] 以下に縮めた大きさ(拡大はしない)。幅 / 高さは偶数(2 以上)にそろえる
     * (VirtualDisplay / ImageReader が奇数で嫌がる端末がある)。
     */
    fun scaledSize(width: Int, height: Int, longEdge: Int): Pair<Int, Int> {
        require(width > 0 && height > 0 && longEdge > 0)
        val long = maxOf(width, height)
        val scale = if (long > longEdge) longEdge.toDouble() / long else 1.0
        fun even(v: Double): Int = maxOf(2, (Math.round(v).toInt() / 2) * 2)
        return Pair(even(width * scale), even(height * scale))
    }

    /** 見比べ用に、[grid]×[grid] の格子の点の色を拾う(同じコマを 2 度送らない)。 */
    fun fingerprint(width: Int, height: Int, grid: Int = 24, pixelAt: (x: Int, y: Int) -> Int): IntArray {
        require(width > 0 && height > 0 && grid > 0)
        val out = IntArray(grid * grid)
        for (gy in 0 until grid) {
            val y = ((gy + 0.5) * height / grid).toInt().coerceIn(0, height - 1)
            for (gx in 0 until grid) {
                val x = ((gx + 0.5) * width / grid).toInt().coerceIn(0, width - 1)
                out[gy * grid + gx] = pixelAt(x, y)
            }
        }
        return out
    }

    /**
     * ほぼ同じコマか。違う点が [tolerance](割合)以下なら同じとみなす(入力欄のカーソルの点滅などで別のコマにしない)。
     */
    fun sameFrame(a: IntArray?, b: IntArray?, tolerance: Double = 0.005): Boolean {
        if (a == null || b == null || a.size != b.size) return false
        var diff = 0
        for (i in a.indices) if (a[i] != b[i]) diff++
        return diff <= a.size * tolerance
    }

    /** ISO 8601(UTC、ミリ秒まで)。 */
    fun isoUtc(epochMillis: Long): String {
        val f = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", java.util.Locale.US)
        f.timeZone = java.util.TimeZone.getTimeZone("UTC")
        return f.format(java.util.Date(epochMillis))
    }

    /** 読み取りの記録(meta.json)。Dart 側が読む。 */
    fun metaJson(id: String, capturedAtMillis: Long, width: Int, height: Int, files: List<String>): String {
        val sb = StringBuilder()
        sb.append("{\"id\":\"").append(id).append("\",\"capturedAt\":\"").append(isoUtc(capturedAtMillis))
            .append("\",\"width\":").append(width).append(",\"height\":").append(height).append(",\"frames\":[")
        files.forEachIndexed { i, f ->
            if (i > 0) sb.append(',')
            // ファイル名はこちらで決めた frame_<n>.jpg だけ(エスケープの要る字は入らない)。
            sb.append('"').append(f).append('"')
        }
        sb.append("]}")
        return sb.toString()
    }
}
