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
import 'package:summerschool/screens/attendance/attendance_screen.dart';
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
import 'package:summerschool/providers/event_provider.dart';
import 'package:summerschool/services/event_service.dart';
import 'package:summerschool/screens/spiritual_notebook/spiritual_notebook_screen.dart';
import 'package:summerschool/screens/spiritual_notebook/members_notebook_selection_screen.dart';
import 'package:summerschool/providers/spiritual_notebook_provider.dart';
import 'package:summerschool/services/spiritual_notebook_service.dart';
import 'package:summerschool/providers/auth_provider.dart';
import 'package:summerschool/screens/attachments/attachments_screen.dart';
import 'package:summerschool/screens/attachments/manage_attachments_screen.dart';
import 'package:summerschool/screens/follow_up/follow_up_students_screen.dart';
import 'package:summerschool/screens/schedule/schedule_screen.dart';
import 'package:summerschool/screens/manager/all_classes_screen.dart';
import 'package:summerschool/screens/manager/all_members/all_members_screen.dart';
import 'package:summerschool/screens/tasks/manage_tasks_screen.dart';
import 'package:summerschool/screens/tasks/my_tasks_screen.dart';
import 'package:summerschool/screens/tasks/manage_task_history_screen.dart';
import 'package:summerschool/screens/tasks/task_history_dashboard_screen.dart';
import 'package:summerschool/screens/notifications/send_notification_screen.dart';
import 'package:summerschool/screens/notifications/notification_center_screen.dart';
import 'package:summerschool/screens/debug/debug_fcm_screen.dart';

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
  static const String attendance = '/attendance';
  static const String servantsAttendance = '/servants-attendance';
  static const String attachments = '/attachments';
  static const String manageAttachments = '/manage-attachments';
  static const String schedule = '/schedule';
  static const String followUpStudents = '/follow-up-students';
  static const String allClasses = '/all-classes';
  static const String allMembers = '/all-members';
  static const String myTasks = '/my-tasks';
  static const String manageTasks = '/manage-tasks';
  static const String manageTaskHistory = '/manage-task-history';
  static const String taskHistoryDashboard = '/task-history-dashboard';
  static const String spiritualNotebook = '/spiritual-notebook';
  static const String membersNotebookSelection = '/members-notebook-selection';
  static const String adminLogin = '/admin-login';
  static const String adminDashboard = '/admin-dashboard';
  static const String adminClassMembers = '/admin-class-members';
  static const String sendNotification = '/send-notification';
  static const String notificationCenter = '/notification-center';
  static const String debugFcm = '/debug-fcm';

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
    addEvent: (context) => ChangeNotifierProvider<EventProvider>(
      create: (_) => EventProvider(EventService()),
      child: const AddEventScreen(),
    ),
    manageEvents: (context) => const ManageEventsScreen(),
    points: (_) => ChangeNotifierProvider<PointsProvider>(
      create: (_) => PointsProvider(PointsService()),
      child: const PointsScreen(),
    ),
    attendance: (_) => const AttendanceScreen(),
    servantsAttendance: (_) => const AttendanceScreen(servantsMode: true),
    attachments: (_) => const AttachmentsScreen(),
    manageAttachments: (_) => const ManageAttachmentsScreen(),
    schedule: (_) => const ScheduleScreen(),
    followUpStudents: (_) => const FollowUpStudentsScreen(),
    allClasses: (_) => const AllClassesScreen(),
    allMembers: (_) => const AllMembersScreen(),
    myTasks: (_) => const MyTasksScreen(),
    manageTasks: (_) => const ManageTasksScreen(),
    manageTaskHistory: (_) => const ManageTaskHistoryScreen(),
    taskHistoryDashboard: (_) => const TaskHistoryDashboardScreen(),
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
    sendNotification: (_) => const SendNotificationScreen(),
    notificationCenter: (_) => const NotificationCenterScreen(),
    debugFcm: (_) => const DebugFcmScreen(),
  };
}
