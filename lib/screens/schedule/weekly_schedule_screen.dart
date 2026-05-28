import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import 'package:summerschool/core/constants/app_colors.dart';
import 'package:summerschool/models/weekly_schedule_item_model.dart';
import 'package:summerschool/providers/auth_provider.dart';
import 'package:summerschool/providers/weekly_schedule_provider.dart';
import 'package:summerschool/screens/schedule/add_weekly_schedule_item_screen.dart';
import 'package:summerschool/services/weekly_schedule_service.dart';

class WeeklyScheduleScreen extends StatefulWidget {
  const WeeklyScheduleScreen({
    super.key,
    this.forcedStage,
    this.readOnly = false,
  });

  final String? forcedStage;
  final bool readOnly;

  @override
  State<WeeklyScheduleScreen> createState() => _WeeklyScheduleScreenState();
}

class _WeeklyScheduleScreenState extends State<WeeklyScheduleScreen> {
  late final WeeklyScheduleProvider _provider;
  DateTime _selectedWeekStart = _weekStartOf(DateTime.now());

  @override
  void initState() {
    super.initState();
    _provider = WeeklyScheduleProvider(service: WeeklyScheduleService());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      final stage = widget.forcedStage?.trim().isNotEmpty == true
          ? widget.forcedStage!.trim()
          : (auth.user?.stage ?? '');
      _provider.initialize(stage: stage);
    });
  }

  @override
  void dispose() {
    _provider.disposeListening();
    _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final stage = widget.forcedStage?.trim().isNotEmpty == true
        ? widget.forcedStage!.trim()
        : (auth.user?.stage ?? '');
    final canManage = auth.isMemberManager && !widget.readOnly;

    return ChangeNotifierProvider<WeeklyScheduleProvider>.value(
      value: _provider,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Scaffold(
          backgroundColor: AppColors.surfaceSoft,
          appBar: AppBar(
            backgroundColor: Colors.white,
            foregroundColor: AppColors.primary,
            title: const Text('Weekly Stage Schedule'),
          ),
          floatingActionButton: canManage
              ? FloatingActionButton(
                  onPressed: () => _openAddScreen(
                    context,
                    stage: stage,
                    initialDay: _provider.selectedDay,
                  ),
                  child: const Icon(Icons.add_rounded),
                )
              : null,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, _) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _HeaderCard(stage: stage),
                      const SizedBox(height: 10),
                      _DayToggle(
                        selectedDay: context
                            .watch<WeeklyScheduleProvider>()
                            .selectedDay,
                        onChanged: (day) => context
                            .read<WeeklyScheduleProvider>()
                            .selectDay(day),
                      ),
                      const SizedBox(height: 10),
                      _WeekSelectorCard(
                        selectedWeekStart: _selectedWeekStart,
                        onPreviousWeek: _goToPreviousWeek,
                        onNextWeek: _goToNextWeek,
                        onPickWeek: _pickWeek,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Current day: ${WeeklyScheduleDays.arabicLabel(context.watch<WeeklyScheduleProvider>().selectedDay)} - ${intl.DateFormat('yyyy/MM/dd').format(_dateForSelectedDay(context.watch<WeeklyScheduleProvider>().selectedDay))}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: Consumer<WeeklyScheduleProvider>(
                          builder: (context, provider, _) {
                            if (stage.trim().isEmpty) {
                              return const _EmptyMessage(
                                message:
                                    'Stage is not set for this user. Schedule cannot be loaded.',
                              );
                            }

                            if (provider.isLoading && provider.items.isEmpty) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            if (provider.error != null &&
                                provider.items.isEmpty) {
                              return _EmptyMessage(message: provider.error!);
                            }

                            if (provider.items.isEmpty) {
                              return const _EmptyMessage(
                                message:
                                    'No items for this day yet. Press + to add a new item.',
                              );
                            }

                            return Scrollbar(
                              thumbVisibility: true,
                              child: ListView.builder(
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.only(bottom: 22),
                                itemCount: provider.items.length,
                                itemBuilder: (context, index) {
                                  final item = provider.items[index];
                                  return _TimelineItemCard(
                                    item: item,
                                    canManage: canManage,
                                    onTap: canManage
                                        ? () => _openAddScreen(
                                            context,
                                            stage: stage,
                                            initialDay: provider.selectedDay,
                                            existing: item,
                                          )
                                        : null,
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openAddScreen(
    BuildContext context, {
    required String stage,
    required String initialDay,
    WeeklyScheduleItemModel? existing,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider<WeeklyScheduleProvider>.value(
          value: _provider,
          child: AddWeeklyScheduleItemScreen(
            stage: stage,
            initialDay: initialDay,
            item: existing,
          ),
        ),
      ),
    );
  }

  void _goToPreviousWeek() {
    setState(() {
      _selectedWeekStart = _selectedWeekStart.subtract(const Duration(days: 7));
    });
    debugPrint(
      '[WeeklySchedule] week changed -> ${intl.DateFormat('yyyy/MM/dd').format(_selectedWeekStart)}',
    );
  }

  void _goToNextWeek() {
    setState(() {
      _selectedWeekStart = _selectedWeekStart.add(const Duration(days: 7));
    });
    debugPrint(
      '[WeeklySchedule] week changed -> ${intl.DateFormat('yyyy/MM/dd').format(_selectedWeekStart)}',
    );
  }

  Future<void> _pickWeek() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedWeekStart,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Pick any date in the week',
      locale: const Locale('en'),
    );
    if (picked == null || !mounted) return;

    setState(() {
      _selectedWeekStart = _weekStartOf(picked);
    });
    debugPrint(
      '[WeeklySchedule] week selected -> ${intl.DateFormat('yyyy/MM/dd').format(_selectedWeekStart)}',
    );
  }

  DateTime _dateForSelectedDay(String selectedDay) {
    if (selectedDay == WeeklyScheduleDays.wednesday) {
      return _selectedWeekStart.add(const Duration(days: 4));
    }
    return _selectedWeekStart;
  }

  static DateTime _weekStartOf(DateTime date) {
    final local = DateTime(date.year, date.month, date.day);
    var diff = local.weekday - DateTime.sunday;
    if (diff < 0) diff += 7;
    return local.subtract(Duration(days: diff));
  }
}

class _WeekSelectorCard extends StatelessWidget {
  const _WeekSelectorCard({
    required this.selectedWeekStart,
    required this.onPreviousWeek,
    required this.onNextWeek,
    required this.onPickWeek,
  });

  final DateTime selectedWeekStart;
  final VoidCallback onPreviousWeek;
  final VoidCallback onNextWeek;
  final VoidCallback onPickWeek;

  @override
  Widget build(BuildContext context) {
    final weekEnd = selectedWeekStart.add(const Duration(days: 6));
    final formatter = intl.DateFormat('yyyy/MM/dd');

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous week',
            onPressed: onPreviousWeek,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onPickWeek,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    const Text(
                      'Selected week',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${formatter.format(selectedWeekStart)}  -  ${formatter.format(weekEnd)}',
                      textDirection: TextDirection.ltr,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Next week',
            onPressed: onNextWeek,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.stage});

  final String stage;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.95),
            AppColors.primary.withOpacity(0.75),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'WEEKLY STAGE SCHEDULE',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 19,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Weekly Stage Schedule',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text('Stage: $stage', style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}

class _DayToggle extends StatelessWidget {
  const _DayToggle({required this.selectedDay, required this.onChanged});

  final String selectedDay;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    const selectedColor = AppColors.secondary;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Expanded(
            child: _DayButton(
              label: 'Sunday',
              selected: selectedDay == WeeklyScheduleDays.sunday,
              selectedColor: selectedColor,
              onTap: () => onChanged(WeeklyScheduleDays.sunday),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _DayButton(
              label: 'Wednesday',
              selected: selectedDay == WeeklyScheduleDays.wednesday,
              selectedColor: selectedColor,
              onTap: () => onChanged(WeeklyScheduleDays.wednesday),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayButton extends StatelessWidget {
  const _DayButton({
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? selectedColor : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? selectedColor : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          style: TextStyle(
            color: selected ? AppColors.primary : AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _TimelineItemCard extends StatelessWidget {
  const _TimelineItemCard({
    required this.item,
    required this.canManage,
    this.onTap,
  });

  final WeeklyScheduleItemModel item;
  final bool canManage;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                ),
              ),
              Container(
                width: 2,
                height: 96,
                color: AppColors.primary.withOpacity(0.25),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: Ink(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${_formatMinutes(context, item.startTime)} ← ${_formatMinutes(context, item.endTime)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        if (canManage) const Icon(Icons.edit_rounded, size: 18),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.resolvedSubject,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if ((item.servantName ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        item.servantName!.trim(),
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                    if ((item.notes ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        item.notes!.trim(),
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatMinutes(BuildContext context, int minutes) {
    final time = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
    return MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(time, alwaysUse24HourFormat: false);
  }
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(height: 1.5),
          ),
        ),
      ),
    );
  }
}
