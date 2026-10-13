import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:summerschool/providers/locale_provider.dart';
import 'package:summerschool/core/localization/app_localizations.dart';

import 'routes/app_routes.dart';
import 'theme/app_theme.dart';

class SummerSchoolApp extends StatelessWidget {
  const SummerSchoolApp({super.key});

  @override
  Widget build(BuildContext context) {
    final localeProvider = context.watch<LocaleProvider>();

    return MaterialApp(
      title: 'San Mina Summer School',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,

      locale: localeProvider.locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('ar')],
      initialRoute: AppRoutes.splash,
      routes: AppRoutes.routes,
    );
  }
}
