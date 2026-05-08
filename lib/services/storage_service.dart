import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _anthropicApiKey = 'anthropic_api_key';

  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static Future<void> saveAnthropicApiKey(String apiKey) async {
    await _prefs.setString(_anthropicApiKey, apiKey);
  }

  static String? getAnthropicApiKey() {
    return _prefs.getString(_anthropicApiKey);
  }
}
