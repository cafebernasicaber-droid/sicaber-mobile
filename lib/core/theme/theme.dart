import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── CONTROLADOR DE TEMA (claro / oscuro) ────────────────────────
class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  static const _prefKey = 'modo_oscuro';

  bool _isDark = true; // por defecto oscuro, igual que la web
  bool get isDark => _isDark;

  Future<void> cargarPreferencia() async {
    final prefs = await SharedPreferences.getInstance();
    _isDark = prefs.getBool(_prefKey) ?? true;
    notifyListeners();
  }

  Future<void> toggle() async {
    _isDark = !_isDark;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, _isDark);
  }

  Future<void> setDark(bool value) async {
    if (_isDark == value) return;
    _isDark = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, _isDark);
  }
}

// ── COLORES (dinámicos según el tema activo) ────────────────────
// Se mantiene el nombre "C" y todos los identificadores para no
// tener que tocar las pantallas que ya usan C.bg, C.text, etc.
class C {
  static bool get _dark => ThemeController.instance.isDark;

  // Fondos
  static Color get bg       => _dark ? const Color(0xFF0F0F0F) : const Color(0xFFF7F5F1);
  static Color get surface  => _dark ? const Color(0xFF1A1A1A) : const Color(0xFFFFFFFF);
  static Color get card     => _dark ? const Color(0xFF1C1C1C) : const Color(0xFFFFFFFF);
  static Color get surf2    => _dark ? const Color(0xFF252525) : const Color(0xFFF0EDE6);
  static Color get elevated => _dark ? const Color(0xFF2A2A2A) : const Color(0xFFE9E5DC);
  static Color get border   => _dark ? const Color(0x14FFFFFF) : const Color(0x14000000);

  // Marca
  static const green   = Color(0xFF4CAF50);
  static const greenD  = Color(0xFF388E3C);
  static Color get greenBg => _dark ? const Color(0x1A4CAF50) : const Color(0x1F4CAF50);

  // Texto
  static Color get text    => _dark ? const Color(0xFFF0ECE4) : const Color(0xFF232019);
  static Color get textSec => _dark ? const Color(0xFFA09880) : const Color(0xFF6E6656);
  static Color get textMut => _dark ? const Color(0xFF6B6355) : const Color(0xFF9A927E);

  static const red  = Color(0xFFE53935);
  static const gold = Color(0xFFFFB300);
  static const info = Color(0xFF42A5F5);

  static Color get overlay => _dark ? const Color(0xB3000000) : const Color(0xB3FFFFFF);
}

// ── TEMA CLARO Y OSCURO ──────────────────────────────────────
ThemeData _buildTheme({required bool dark}) {
  final bg       = dark ? const Color(0xFF0F0F0F) : const Color(0xFFF7F5F1);
  final surface  = dark ? const Color(0xFF1A1A1A) : const Color(0xFFFFFFFF);
  final card     = dark ? const Color(0xFF1C1C1C) : const Color(0xFFFFFFFF);
  final surf2    = dark ? const Color(0xFF252525) : const Color(0xFFF0EDE6);
  final border   = dark ? const Color(0x14FFFFFF) : const Color(0x14000000);
  final text     = dark ? const Color(0xFFF0ECE4) : const Color(0xFF232019);
  final textSec  = dark ? const Color(0xFFA09880) : const Color(0xFF6E6656);
  final textMut  = dark ? const Color(0xFF6B6355) : const Color(0xFF9A927E);
  const green    = Color(0xFF4CAF50);
  const red      = Color(0xFFE53935);
  final elevated = dark ? const Color(0xFF2A2A2A) : const Color(0xFFE9E5DC);

  return ThemeData(
    useMaterial3: true,
    brightness: dark ? Brightness.dark : Brightness.light,
    scaffoldBackgroundColor: bg,
    colorScheme: dark
        ? ColorScheme.dark(primary: green, onPrimary: Colors.white, secondary: const Color(0xFFFFB300),
            surface: surface, onSurface: text, error: red)
        : ColorScheme.light(primary: green, onPrimary: Colors.white, secondary: const Color(0xFFFFB300),
            surface: surface, onSurface: text, error: red),
    appBarTheme: AppBarTheme(
      backgroundColor: surface, foregroundColor: text, elevation: 0,
      systemOverlayStyle: dark
          ? const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light)
          : const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark),
      titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: text),
      iconTheme: IconThemeData(color: text),
    ),
    cardTheme: CardThemeData(
      color: card, elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        side: BorderSide(color: border))),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: green, foregroundColor: Colors.white,
        elevation: 0, minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: green, side: const BorderSide(color: green),
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: surf2,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: green, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: red)),
      hintStyle: TextStyle(color: textMut),
      labelStyle: TextStyle(color: textSec)),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: surface, selectedItemColor: green,
      unselectedItemColor: textMut, type: BottomNavigationBarType.fixed, elevation: 0,
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
      unselectedLabelStyle: const TextStyle(fontSize: 11)),
    dividerTheme: DividerThemeData(color: border, thickness: 1),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: elevated, contentTextStyle: TextStyle(color: text),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating),
  );
}

ThemeData get darkTheme  => _buildTheme(dark: true);
ThemeData get lightTheme => _buildTheme(dark: false);

// Se mantiene por compatibilidad si algo importa `appTheme` directo
ThemeData get appTheme => darkTheme;