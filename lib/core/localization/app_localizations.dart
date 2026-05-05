import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});

class LocaleNotifier extends StateNotifier<Locale> {
  static const String _languageKey = 'selected_language';
  
  LocaleNotifier() : super(const Locale('en')) {
    _loadSavedLocale();
  }

  Future<void> _loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString(_languageKey) ?? 'en';
    state = Locale(languageCode);
  }

  Future<void> setLocale(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, languageCode);
    state = Locale(languageCode);
  }

  String get currentLanguageCode => state.languageCode;
  
  bool get isMongolian => state.languageCode == 'mn';
  bool get isEnglish => state.languageCode == 'en';
}

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'app_name': 'ShiftMate',
      'dashboard': 'Dashboard',
      'my_shifts': 'My Shifts',
      'group_chat': 'Group Chat',
      'logout': 'Logout',
      'login': 'Login',
      'register': 'Register',
      'sign_in': 'Sign In',
      'sign_up': 'Sign Up',
      'settings': 'Settings',
      'language': 'Language',
      'save': 'Save',
      'delete': 'Delete',
      'cancel': 'Cancel',
      'ok': 'OK',
      'yes': 'Yes',
      'no': 'No',
      'error': 'Error',
      'success': 'Success',
      'loading': 'Loading...',
      'today': 'Today',
      'tomorrow': 'Tomorrow',
      'yesterday': 'Yesterday',
    },
    'mn': {
      'app_name': 'ShiftMate',
      'dashboard': 'Хяналт',
      'my_shifts': 'Миний ээлж',
      'group_chat': 'Бүлэг чат',
      'logout': 'Гарах',
      'login': 'Нэвтрэх',
      'register': 'Бүртгүүлэх',
      'sign_in': 'Нэвтрэх',
      'sign_up': 'Бүртгэх',
      'settings': 'Тохиргоо',
      'language': 'Хэл',
      'save': 'Хадгалах',
      'delete': 'Устгах',
      'cancel': 'Цуцлах',
      'ok': 'Тийм',
      'yes': 'Тийм',
      'no': 'Үгүй',
      'error': 'Алдаа',
      'success': 'Амжилттай',
      'loading': 'Ачааллаж байна...',
      'today': 'Өнөөдөр',
      'tomorrow': 'Маргааш',
      'yesterday': 'Өчигдөр',
    },
  };

  String translate(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? 
           _localizedValues['en']?[key] ?? 
           key;
  }

  String get appName => translate('app_name');
  String get dashboard => translate('dashboard');
  String get myShifts => translate('my_shifts');
  String get groupChat => translate('group_chat');
  String get logout => translate('logout');
  String get login => translate('login');
  String get register => translate('register');
  String get signIn => translate('sign_in');
  String get signUp => translate('sign_up');
  String get settings => translate('settings');
  String get language => translate('language');
  String get save => translate('save');
  String get delete => translate('delete');
  String get cancel => translate('cancel');
  String get ok => translate('ok');
  String get yes => translate('yes');
  String get no => translate('no');
  String get error => translate('error');
  String get success => translate('success');
  String get loading => translate('loading');
  String get today => translate('today');
  String get tomorrow => translate('tomorrow');
  String get yesterday => translate('yesterday');
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'mn'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}