import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppTheme {
  static final ValueNotifier<bool> isDark = ValueNotifier(false);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    isDark.value = prefs.getBool('dark_mode') ?? false;
  }

  static Future<void> toggle() async {
    isDark.value = !isDark.value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', isDark.value);
  }

  // ── Fondos ────────────────────────────────────────────────────────────────
  static Color get bgTop    => isDark.value ? const Color(0xFF0D0D1A) : const Color(0xFFF0F0F3);
  static Color get bgBottom => isDark.value ? const Color(0xFF16213E) : const Color(0xFFA6A6BC);

  // ── Texto principal ───────────────────────────────────────────────────────
  static Color get darkText => isDark.value ? const Color(0xFFECECF4) : const Color(0xFF1A1A2E);

  // ── Cards glass ───────────────────────────────────────────────────────────
  static Color get cardBg1    => isDark.value ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.72);
  static Color get cardBg2    => isDark.value ? Colors.white.withOpacity(0.03) : Colors.white.withOpacity(0.48);
  static Color get cardBorder => isDark.value ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.85);

  // ── Texto secundario ──────────────────────────────────────────────────────
  static Color get subtitleColor  => isDark.value ? Colors.white.withOpacity(0.45) : Colors.black.withOpacity(0.35);
  static Color get subtitleColor2 => isDark.value ? Colors.white.withOpacity(0.30) : Colors.black.withOpacity(0.22);

  // ── Handle / separadores ──────────────────────────────────────────────────
  static Color get handleColor => isDark.value ? Colors.white.withOpacity(0.20) : Colors.black.withOpacity(0.12);

  // ── Bottom sheets ─────────────────────────────────────────────────────────
  static Color get sheetBg     => isDark.value ? const Color(0xFF1A1A2E).withOpacity(0.95) : Colors.white.withOpacity(0.90);
  static Color get sheetBorder => isDark.value ? Colors.white.withOpacity(0.10) : Colors.white.withOpacity(0.90);

  // ── Locked cards ──────────────────────────────────────────────────────────
  static Color get lockedCardBg     => isDark.value ? Colors.white.withOpacity(0.04) : Colors.white.withOpacity(0.55);
  static Color get lockedCardBorder => isDark.value ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.75);

  // ── Sombra blanca de glass-morphism (en oscuro se elimina) ────────────────
  static Color get cardGlowWhite => isDark.value ? Colors.transparent : Colors.white.withOpacity(0.9);
}
