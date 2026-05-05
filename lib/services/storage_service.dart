import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _ollamaBaseUrlKey = 'ollama_server_url';

  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static Future<void> saveOllamaBaseUrl(String url) async {
    await _prefs.setString(_ollamaBaseUrlKey, url);
  }

  static String? getOllamaBaseUrl() {
    return _prefs.getString(_ollamaBaseUrlKey);
  }
}
