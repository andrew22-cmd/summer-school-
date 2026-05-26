import 'package:flutter/material.dart';
import 'package:summerschool/screens/schedule/weekly_schedule_screen.dart';

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key, this.forcedStage, this.readOnly = false});

  final String? forcedStage;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return WeeklyScheduleScreen(forcedStage: forcedStage, readOnly: readOnly);
  }
}
