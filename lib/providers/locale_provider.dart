import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class LocaleProvider extends ChangeNotifier {
  Locale _locale = const Locale('en');
  final SharedPreferences _prefs;

  LocaleProvider(this._prefs) {
    _loadFromPrefs();
  }

  Locale get locale => _locale;

  void _loadFromPrefs() {
    final langCode = _prefs.getString('language_code');
    if (langCode != null) {
      _locale = Locale(langCode);
      Intl.defaultLocale = langCode;
      notifyListeners();
    } else {
      Intl.defaultLocale = _locale.languageCode;
    }
  }

  Future<void> setLocale(Locale locale) async {
    if (!['en', 'ar'].contains(locale.languageCode)) return;
    
    _locale = locale;
    Intl.defaultLocale = locale.languageCode;
    await _prefs.setString('language_code', locale.languageCode);
    notifyListeners();
  }
}
