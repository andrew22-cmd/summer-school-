import 'package:flutter/material.dart';

import 'routes/app_routes.dart';
import 'theme/app_theme.dart';

class SummerSchoolApp extends StatelessWidget {
  const SummerSchoolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'San Mina Summer School',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: AppRoutes.splash,
      routes: AppRoutes.routes,
    );
  }
}
