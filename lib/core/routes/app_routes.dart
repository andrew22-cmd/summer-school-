import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:summerschool/providers/admin_users_provider.dart';
import 'package:summerschool/screens/auth/login_screen.dart';
import 'package:summerschool/screens/admin/admin_dashboard_screen.dart';
import 'package:summerschool/screens/admin/admin_login_screen.dart';
import 'package:summerschool/screens/home/home_screen.dart';
import 'package:summerschool/screens/home/manager_home_screen.dart';
import 'package:summerschool/screens/home/members_home_screen.dart';
import 'package:summerschool/screens/onboarding/onboarding_screen.dart';
import 'package:summerschool/screens/splash/splash_screen.dart';
import 'package:summerschool/services/firestore_user_service.dart';

class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String home = '/home';
  static const String managerHome = '/manager-home';
  static const String membersHome = '/members-home';
  static const String adminLogin = '/admin-login';
  static const String adminDashboard = '/admin-dashboard';

  static Map<String, WidgetBuilder> get routes => {
    splash: (_) => const SplashScreen(),
    onboarding: (_) => const OnboardingScreen(),
    login: (_) => const LoginScreen(),
    home: (_) => const HomeScreen(),
    managerHome: (_) => const ManagerHomeScreen(),
    membersHome: (_) => const MembersHomeScreen(),
    adminLogin: (_) => const AdminLoginScreen(),
    adminDashboard: (context) => ChangeNotifierProvider<AdminUsersProvider>(
      create: (_) =>
          AdminUsersProvider(context.read<FirestoreUserService>())
            ..startListening(),
      child: const AdminDashboardScreen(),
    ),
  };
}
