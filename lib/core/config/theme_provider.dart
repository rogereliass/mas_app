import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for managing theme state across the app
/// Persists theme preference using SharedPreferences
class ThemeProvider with ChangeNotifier {
  static const String _themePreferenceKey = 'theme_mode';
  
  ThemeMode _themeMode = ThemeMode.system;
  
  ThemeProvider() {
    _loadThemePreference();
  }
  
  ThemeMode get themeMode => _themeMode;
  
  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      // This will be determined by the system
      return false;
    }
    return _themeMode == ThemeMode.dark;
  }
  
  /// Load saved theme preference from storage
  Future<void> _loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getString(_themePreferenceKey);
      
      if (savedTheme != null) {
        _themeMode = ThemeMode.values.firstWhere(
          (mode) => mode.toString() == savedTheme,
          orElse: () => ThemeMode.system,
        );
        notifyListeners();
      }
    } catch (e) {
      // If loading fails, use system default
      _themeMode = ThemeMode.system;
    }
  }
  
  /// Save theme preference to storage
  Future<void> _saveThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themePreferenceKey, _themeMode.toString());
    } catch (e) {
      // Silently fail if saving fails
    }
  }
  
  /// Set theme mode to light
  Future<void> setLightMode() async {
    _themeMode = ThemeMode.light;
    await _saveThemePreference();
    notifyListeners();
  }
  
  /// Set theme mode to dark
  Future<void> setDarkMode() async {
    _themeMode = ThemeMode.dark;
    await _saveThemePreference();
    notifyListeners();
  }
  
  /// Set theme mode to system
  Future<void> setSystemMode() async {
    _themeMode = ThemeMode.system;
    await _saveThemePreference();
    notifyListeners();
  }
  
  /// Toggle between light and dark mode
  Future<void> toggleTheme() async {
    if (_themeMode == ThemeMode.light) {
      await setDarkMode();
    } else {
      await setLightMode();
    }
  }
}
