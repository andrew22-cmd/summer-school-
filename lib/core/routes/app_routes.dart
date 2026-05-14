import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:summerschool/providers/admin_users_provider.dart';
import 'package:summerschool/screens/auth/login_screen.dart';
import 'package:summerschool/screens/admin/admin_dashboard_screen.dart';
import 'package:summerschool/screens/admin/admin_class_members_screen.dart';
import 'package:summerschool/screens/admin/admin_login_screen.dart';
import 'package:summerschool/screens/points/points_screen.dart';
import 'package:summerschool/providers/points_provider.dart';
import 'package:summerschool/services/points_service.dart';
import 'package:summerschool/screens/home/home_screen.dart';
import 'package:summerschool/screens/home/manager_home_screen.dart';
import 'package:summerschool/screens/home/members_home_screen.dart';
import 'package:summerschool/screens/class_members/class_members_screen.dart';
import 'package:summerschool/screens/profile/profile_screen.dart';
import 'package:summerschool/screens/onboarding/onboarding_screen.dart';
import 'package:summerschool/screens/splash/splash_screen.dart';
import 'package:summerschool/services/firestore_user_service.dart';
import 'package:summerschool/screens/events/events_screen.dart';
import 'package:summerschool/screens/events/add_event_screen.dart';
import 'package:summerschool/screens/events/manage_events_screen.dart';
import 'package:summerschool/screens/spiritual_notebook/spiritual_notebook_screen.dart';
import 'package:summerschool/screens/spiritual_notebook/members_notebook_selection_screen.dart';
import 'package:summerschool/providers/spiritual_notebook_provider.dart';
import 'package:summerschool/services/spiritual_notebook_service.dart';
import 'package:summerschool/providers/auth_provider.dart';

class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String home = '/home';
  static const String managerHome = '/manager-home';
  static const String membersHome = '/members-home';
  static const String classMembers = '/class-members';
  static const String profile = '/profile';
  static const String events = '/events';
  static const String addEvent = '/add-event';
  static const String manageEvents = '/manage-events';
  static const String points = '/points';
  static const String spiritualNotebook = '/spiritual-notebook';
  static const String membersNotebookSelection = '/members-notebook-selection';
  static const String adminLogin = '/admin-login';
  static const String adminDashboard = '/admin-dashboard';
  static const String adminClassMembers = '/admin-class-members';

  static Map<String, WidgetBuilder> get routes => {
    splash: (_) => const SplashScreen(),
    onboarding: (_) => const OnboardingScreen(),
    login: (_) => const LoginScreen(),
    home: (_) => const HomeScreen(),
    managerHome: (_) => const ManagerHomeScreen(),
    membersHome: (_) => const MembersHomeScreen(),
    profile: (_) => const ProfileScreen(),
    events: (_) => const EventsScreen(),
    classMembers: (context) => const ClassMembersScreen(),
    addEvent: (context) => const AddEventScreen(),
    manageEvents: (context) => const ManageEventsScreen(),
    points: (_) => ChangeNotifierProvider<PointsProvider>(
      create: (_) => PointsProvider(PointsService()),
      child: const PointsScreen(),
    ),
    spiritualNotebook: (context) =>
        ChangeNotifierProvider<SpiritualNotebookProvider>(
          create: (_) => SpiritualNotebookProvider(SpiritualNotebookService())
            ..startListening(
              userId: context.read<AuthProvider>().user?.id ?? '',
            ),
          child: const SpiritualNotebookScreen(),
        ),
    membersNotebookSelection: (_) => const MembersNotebookSelectionScreen(),
    adminLogin: (_) => const AdminLoginScreen(),
    adminClassMembers: (_) => const AdminClassMembersScreen(),
    adminDashboard: (context) => ChangeNotifierProvider<AdminUsersProvider>(
      create: (_) =>
          AdminUsersProvider(context.read<FirestoreUserService>())
            ..startListening(),
      child: const AdminDashboardScreen(),
    ),
  };
}
