import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/data/auth_state.dart';
import '../features/auth/domain/user_model.dart';
import '../../services/mock_data_service.dart';
import '../../core/utils/validation_utils.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState());

  final MockDataService _mockDataService = MockDataService();

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await Future.delayed(const Duration(seconds: 1));

      final emailError = ValidationUtils.validateEmail(email);
      if (emailError != null) {
        state = state.copyWith(isLoading: false, error: emailError);
        return false;
      }

      final passwordError = ValidationUtils.validatePassword(password);
      if (passwordError != null) {
        state = state.copyWith(isLoading: false, error: passwordError);
        return false;
      }

      final user = _mockDataService.getMockUser();
      state = state.copyWith(
        user: user,
        isLoading: false,
        isAuthenticated: true,
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Login failed. Please try again.',
      );
      return false;
    }
  }

  Future<bool> register(String name, String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await Future.delayed(const Duration(seconds: 1));

      final nameError = ValidationUtils.validateName(name);
      if (nameError != null) {
        state = state.copyWith(isLoading: false, error: nameError);
        return false;
      }

      final emailError = ValidationUtils.validateEmail(email);
      if (emailError != null) {
        state = state.copyWith(isLoading: false, error: emailError);
        return false;
      }

      final passwordError = ValidationUtils.validatePassword(password);
      if (passwordError != null) {
        state = state.copyWith(isLoading: false, error: passwordError);
        return false;
      }

      final user = UserModel(
        id: ValidationUtils.generateId(),
        email: email,
        name: name,
        createdAt: DateTime.now(),
      );

      state = state.copyWith(
        user: user,
        isLoading: false,
        isAuthenticated: true,
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Registration failed. Please try again.',
      );
      return false;
    }
  }

  void logout() {
    state = AuthState();
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}
