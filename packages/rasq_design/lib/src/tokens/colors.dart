import 'package:flutter/material.dart';

/// Brand palette. 原典: UI_status「デフォルトカラー」+ ワイヤーフレーム「デフォルトの色合い」.
abstract final class RasqColors {
  static const Color main = Color(0xFF02EFFD);
  static const Color sub = Color(0xFF3274B5);
  static const Color accent = Color(0xFFF09937);
  static const Color navy = Color(0xFF1E4C7C);
  static const Color white = Color(0xFFFFFFFF);
  static const Color lightBlue = Color(0xFFADC5FA);
  static const Color gray = Color(0xFFD5D5D5);
  static const Color black = Color(0xFF000000);

  // Secondary swatches that appear on the wireframe colour sheet.
  static const Color yellow = Color(0xFFF6E359);
  static const Color salmon = Color(0xFFF09286);
  static const Color pink = Color(0xFFD79686);

  // Semantic
  static const Color live = Color(0xFFE53935);
  static const Color inVc = Color(0xFF4CD964);
  static const Color warning = Color(0xFFF09937);
  static const Color danger = Color(0xFFE53935);
  static const Color link = Color(0xFF1E88E5);
  static const Color muted = Color(0xFF8E8E93);

  /// Gradient used by "見てみる" / "参加" pills (accent→pink→lightBlue).
  static const LinearGradient ctaGradient = LinearGradient(
    colors: [Color(0xFFF09286), Color(0xFFD79686), Color(0xFFADC5FA)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}
