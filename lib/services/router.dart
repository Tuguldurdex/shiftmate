import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/presentation/screens/splash_screen.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/register_screen.dart';
import '../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../features/shifts/presentation/screens/shift_list_screen.dart';
import '../features/shifts/presentation/screens/add_shift_screen.dart';
import '../features/group_chat/presentation/screens/chat_list_screen.dart';
import '../features/group_chat/presentation/screens/group_chat_screen.dart';
import '../features/group_chat/presentation/screens/create_group_screen.dart';
import '../features/worker/presentation/screens/time_log_request_screen.dart';
import '../features/worker/presentation/screens/appreciation_screen.dart';
import '../features/worker/presentation/screens/clock_in_screen.dart';
import '../providers.dart';

class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier(this._ref) {
    _ref.listen(authProvider, (_, _) => notifyListeners());
  }
  final Ref _ref;
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthNotifier(ref);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final isAuthenticated = authState.isAuthenticated;
      final isManager = authState.user?.isAdmin ?? false;
      final isAuthRoute =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/splash';

      // Redirect to login if not authenticated
      if (!isAuthenticated && !isAuthRoute) return '/login';
      
      // Redirect authenticated users to dashboard
      if (isAuthenticated && isAuthRoute) return '/dashboard';
      
      // Prevent non-managers from accessing add-shift
      if (!isManager && state.matchedLocation == '/add-shift') {
        return '/shifts';
      }
      
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return MainScaffold(child: child);
        },
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/shifts',
            builder: (context, state) => const ShiftListScreen(),
          ),
          GoRoute(
            path: '/add-shift',
            builder: (context, state) => const AddShiftScreen(),
          ),
          GoRoute(
            path: '/edit-shift/:shiftId',
            builder: (context, state) {
              final shiftId = state.pathParameters['shiftId'];
              return AddShiftScreen(shiftId: shiftId);
            },
          ),
          GoRoute(
            path: '/group-chat',
            builder: (context, state) => const ChatListScreen(),
          ),
          GoRoute(
            path: '/group-chat/:groupId',
            builder: (context, state) {
              final groupId = state.pathParameters['groupId'] ?? '';
              return GroupChatScreen(groupId: groupId);
            },
          ),
          GoRoute(
            path: '/create-group',
            builder: (context, state) => const CreateGroupScreen(),
          ),
          GoRoute(
            path: '/time-log',
            builder: (context, state) => const TimeLogRequestScreen(),
          ),
          GoRoute(
            path: '/appreciation',
            builder: (context, state) => const AppreciationScreen(),
          ),
          GoRoute(
            path: '/clock-in/:shiftId',
            builder: (context, state) {
              final shiftId = state.pathParameters['shiftId'] ?? '';
              return ClockInScreen(shiftId: shiftId);
            },
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) =>
        Scaffold(body: Center(child: Text('Page not found: ${state.error}'))),
  );
});

class MainScaffold extends StatelessWidget {
  final Widget child;

  const MainScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final showNav = location == '/dashboard' ||
        location == '/shifts' ||
        location == '/group-chat' ||
        location == '/time-log' ||
        location == '/appreciation';

    int currentIndex = 0;
    if (location == '/shifts') currentIndex = 1;
    if (location == '/group-chat') currentIndex = 2;
    if (location == '/time-log') currentIndex = 3;
    if (location == '/appreciation') currentIndex = 4;

    return Scaffold(
      body: child,
      bottomNavigationBar: showNav
          ? BottomNavigationBar(
              currentIndex: currentIndex,
              onTap: (index) {
                switch (index) {
                  case 0:
                    context.go('/dashboard');
                  case 1:
                    context.go('/shifts');
                  case 2:
                    context.go('/group-chat');
                  case 3:
                    context.go('/time-log');
                  case 4:
                    context.go('/appreciation');
                }
              },
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard_outlined),
                  activeIcon: Icon(Icons.dashboard),
                  label: 'Dashboard',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.schedule_outlined),
                  activeIcon: Icon(Icons.schedule),
                  label: 'Shifts',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.chat_bubble_outlined),
                  activeIcon: Icon(Icons.chat_bubble),
                  label: 'Group Chat',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.access_time_outlined),
                  activeIcon: Icon(Icons.access_time_filled),
                  label: 'Time Log',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.favorite_border),
                  activeIcon: Icon(Icons.favorite),
                  label: 'Appreciate',
                ),
              ],
            )
          : null,
    );
  }
}
