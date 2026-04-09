class AppConstants {
  static const String appName = 'ShiftMate';
  static const String appVersion = '1.0.0';

  // Supabase Configuration (Replace with your actual values)
  static const String supabaseUrl = 'https://your-project.supabase.co';
  static const String supabaseKey = 'your-anon-key';

  // Storage Keys
  static const String userKey = 'user_data';
  static const String tokenKey = 'auth_token';
  static const String themeKey = 'theme_mode';

  // Shift Roles
  static const List<String> shiftRoles = [
    'Manager',
    'Cashier',
    'Server',
    'Kitchen Staff',
    'Security',
    'Cleaner',
    'Receptionist',
    'Delivery',
  ];

  // Shift Status
  static const String statusUpcoming = 'upcoming';
  static const String statusCompleted = 'completed';
  static const String statusMissed = 'missed';
}
