import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../features/auth/data/auth_state.dart';
import '../features/auth/domain/user_model.dart';
import '../services/user_service.dart';
import 'core/utils/validation_utils.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState()) {
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return;
    try {
      final userService = UserService();
      final userProfile = await userService.getUser(firebaseUser.uid);
      if (mounted) {
        state = state.copyWith(
          user: UserModel(
            id: firebaseUser.uid,
            email: firebaseUser.email ?? '',
            name: userProfile?.name ?? firebaseUser.displayName ?? firebaseUser.email?.split('@').first ?? '',
            role: userProfile?.role ?? 'worker',
            createdAt: DateTime.now(),
          ),
          isAuthenticated: true,
          isLoading: false,
        );
      }
    } catch (_) {}
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
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

      // Sign in with Firebase
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        final user = credential.user!;

        // Load Firestore profile separately — don't let it block or fail auth
        UserProfile? userProfile;
        try {
          final userService = UserService();
          userProfile = await userService.getUser(user.uid);
          if (userProfile == null) {
            await userService.createUser(
              uid: user.uid,
              name: user.displayName ?? email.split('@').first,
              email: email,
              role: 'admin',
            );
            userProfile = await userService.getUser(user.uid);
          }
        } catch (_) {}

        state = state.copyWith(
          user: UserModel(
            id: user.uid,
            email: user.email ?? email,
            name: userProfile?.name ?? user.displayName ?? email.split('@').first,
            role: userProfile?.role ?? 'worker',
            createdAt: DateTime.now(),
          ),
          isLoading: false,
          isAuthenticated: true,
        );
        return true;
      }

      state = state.copyWith(isLoading: false, error: 'Login failed');
      return false;
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No account found with this email';
          break;
        case 'wrong-password':
        case 'invalid-credential':
          errorMessage = 'Incorrect email or password';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email address';
          break;
        case 'user-disabled':
          errorMessage = 'This account has been disabled';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many attempts. Please try again later.';
          break;
        default:
          errorMessage = 'Login failed. Please try again.';
      }
      state = state.copyWith(isLoading: false, error: errorMessage);
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Login failed. Please try again.',
      );
      return false;
    }
  }

  Future<bool> register(String name, String email, String password, String role) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
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

      // Create user with Firebase
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        final user = credential.user!;
        
        // Update display name
        await user.updateDisplayName(name);
        
        // Create user profile in Firestore
        final userService = UserService();
        await userService.createUser(
          uid: user.uid,
          name: name,
          email: email,
          role: role,
        );

        state = state.copyWith(
          user: UserModel(
            id: user.uid,
            email: email,
            name: name,
            role: role,
            createdAt: DateTime.now(),
          ),
          isLoading: false,
          isAuthenticated: true,
        );
        return true;
      }
      
      state = state.copyWith(isLoading: false, error: 'Registration failed');
      return false;
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = 'An account with this email already exists';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email address';
          break;
        case 'weak-password':
          errorMessage = 'Password is too weak';
          break;
        case 'operation-not-allowed':
          errorMessage = 'Account creation is disabled';
          break;
        default:
          errorMessage = 'Registration failed. Please try again.';
      }
      state = state.copyWith(isLoading: false, error: errorMessage);
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Registration failed. Please try again.',
      );
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      // Ignore logout errors
    }
    state = AuthState();
  }

  void updateName(String name) {
    if (state.user != null) {
      state = state.copyWith(user: state.user!.copyWith(name: name));
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

// Auth state stream provider
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

// Current user provider
final currentFirebaseUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).value;
});

// User role provider (from Firestore)
final userRoleProvider = FutureProvider.family<String, String>((ref, uid) async {
  final userService = ref.watch(userServiceProvider);
  return await userService.getUserRole(uid);
});

// Role-based permission providers
final isManagerProvider = Provider<bool>((ref) {
  final user = ref.watch(authProvider).user;
  return user?.isAdmin ?? false;
});

final isWorkerProvider = Provider<bool>((ref) {
  final user = ref.watch(authProvider).user;
  return user?.isWorker ?? true;
});

final canAddEmployeesProvider = Provider<bool>((ref) {
  final user = ref.watch(authProvider).user;
  return user?.canAddEmployees ?? false;
});