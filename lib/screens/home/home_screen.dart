import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:summerschool/providers/auth_provider.dart';
import 'package:summerschool/screens/home/manager_home_screen.dart';
import 'package:summerschool/screens/home/members_home_screen.dart';
import 'package:summerschool/screens/home/tabs/home_tab.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    if (authProvider.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!authProvider.isLoggedIn) {
      return const Scaffold(body: HomeTab());
    }

    if (authProvider.isManager) {
      return const ManagerHomeScreen();
    }

    return const MembersHomeScreen();
  }
}
