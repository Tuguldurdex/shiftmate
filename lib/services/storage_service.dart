import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';
import '../features/auth/domain/user_model.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<void> saveUser(UserModel user) async {
    await _prefs.setString(AppConstants.userKey, user.id);
  }

  String? getUserId() {
    return _prefs.getString(AppConstants.userKey);
  }

  Future<void> saveToken(String token) async {
    await _prefs.setString(AppConstants.tokenKey, token);
  }

  String? getToken() {
    return _prefs.getString(AppConstants.tokenKey);
  }

  Future<void> clearAll() async {
    await _prefs.clear();
  }
}
