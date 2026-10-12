import 'package:flutter/material.dart';

/// The server's default "Graphite" palette (styles.css :root), so native screens match the web UI.
class Ml {
  static const bg = Color(0xFF0F1115);
  static const panel = Color(0xFF171A21);
  static const panel2 = Color(0xFF1E222B);
  static const panel3 = Color(0xFF262B36);
  static const line = Color(0xFF262B35);
  static const text = Color(0xFFE6E8EE);
  static const muted = Color(0xFF8B93A7);
  static const accent = Color(0xFF5AA9FF);
  static const ok = Color(0xFF7EE787);
  static const warn = Color(0xFFF0B429);
  static const bad = Color(0xFFFF6B6B);
  static const tv = Color(0xFF5AA9FF);
  static const anime = Color(0xFFC792EA);
  static const movie = Color(0xFFF78C6C);

  static ThemeData theme() {
    final scheme = ColorScheme.fromSeed(seedColor: accent, brightness: Brightness.dark).copyWith(
      surface: panel,
      primary: accent,
      onPrimary: bg,
      error: bad,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      dividerColor: line,
      appBarTheme: const AppBarTheme(backgroundColor: panel, foregroundColor: text, elevation: 0, scrolledUnderElevation: 0),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: panel,
        indicatorColor: accent.withValues(alpha: 0.2),
        labelTextStyle: WidgetStatePropertyAll(const TextStyle(fontSize: 12, color: text)),
      ),
      cardTheme: const CardThemeData(color: panel, margin: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10)), side: BorderSide(color: line))),
      listTileTheme: const ListTileThemeData(iconColor: muted, textColor: text),
      inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder(), filled: true, fillColor: panel),
      bottomSheetTheme: const BottomSheetThemeData(backgroundColor: panel),
      dialogTheme: const DialogThemeData(backgroundColor: panel2),
    );
  }
}
