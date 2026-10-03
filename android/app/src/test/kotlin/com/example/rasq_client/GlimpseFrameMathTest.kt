package com.example.rasq_client

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** 画面の読み取り (D-416) の小さな計算。`cd android && ./gradlew :app:testDebugUnitTest --tests '*GlimpseFrameMathTest'`。 */
class GlimpseFrameMathTest {
    @Test
    fun scaledSize_shrinksLongEdgeTo1080_keepsAspect_evenDims() {
        assertEquals(Pair(498, 1080), GlimpseFrameMath.scaledSize(1080, 2340, 1080))
        assertEquals(Pair(1080, 498), GlimpseFrameMath.scaledSize(2340, 1080, 1080))
        assertEquals(Pair(608, 1080), GlimpseFrameMath.scaledSize(720, 1280, 1080))
        // 拡大はしない、奇数は偶数に。
        assertEquals(Pair(640, 480), GlimpseFrameMath.scaledSize(641, 481, 1080))
        assertEquals(Pair(2, 2), GlimpseFrameMath.scaledSize(1, 1, 1080))
    }

    @Test
    fun fingerprint_samplesGrid_andSameFrameToleratesTinyChanges() {
        val a = GlimpseFrameMath.fingerprint(100, 200, grid = 10) { x, y -> x * 1000 + y }
        assertEquals(100, a.size)
        assertEquals(5 * 1000 + 10, a[0]) // 格子の真ん中の点
        val b = a.copyOf()
        assertTrue(GlimpseFrameMath.sameFrame(a, b))
        val big = GlimpseFrameMath.fingerprint(100, 200, grid = 24) { _, _ -> 0 }
        val blink = big.copyOf().also { it[3] = 1 } // 576 点のうち 1 点(カーソルの点滅)
        assertTrue(GlimpseFrameMath.sameFrame(big, blink))
        val scrolled = big.copyOf().also { for (i in 0 until 50) it[i] = 7 }
        assertFalse(GlimpseFrameMath.sameFrame(big, scrolled))
        assertFalse(GlimpseFrameMath.sameFrame(null, big))
        assertFalse(GlimpseFrameMath.sameFrame(a, big))
    }

    @Test
    fun ids_and_meta() {
        assertTrue(GlimpseFrameMath.isValidId("g1759478400000-0a1b2c3d4e5f"))
        assertFalse(GlimpseFrameMath.isValidId("../etc"))
        assertFalse(GlimpseFrameMath.isValidId("short"))
        assertFalse(GlimpseFrameMath.isValidId(null))
        assertEquals("2025-10-03T08:00:00.000Z", GlimpseFrameMath.isoUtc(1759478400000L))
        assertEquals(
            "{\"id\":\"g1-abcdef\",\"capturedAt\":\"2025-10-03T08:00:00.000Z\",\"width\":498,\"height\":1080,\"frames\":[\"frame_0.jpg\",\"frame_1.jpg\"]}",
            GlimpseFrameMath.metaJson("g1-abcdef", 1759478400000L, 498, 1080, listOf("frame_0.jpg", "frame_1.jpg")),
        )
    }
}
