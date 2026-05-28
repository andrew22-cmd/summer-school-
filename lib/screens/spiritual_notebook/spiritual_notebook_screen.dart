import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:summerschool/core/constants/app_colors.dart';
import 'package:summerschool/core/routes/app_routes.dart';
import 'package:summerschool/providers/auth_provider.dart';
import 'package:summerschool/providers/spiritual_notebook_provider.dart';
import 'package:summerschool/services/spiritual_notebook_service.dart';
import 'package:summerschool/models/spiritual_notebook_model.dart';

class SpiritualNotebookScreen extends StatefulWidget {
  const SpiritualNotebookScreen({super.key});

  @override
  State<SpiritualNotebookScreen> createState() =>
      _SpiritualNotebookScreenState();
}

class _SpiritualNotebookScreenState extends State<SpiritualNotebookScreen> {
  static const List<Map<String, String>> columns = [
    {'label': 'Morning Prayer', 'key': 'baker'},
    {'label': 'Sleep Prayer', 'key': 'sleepPrayer'},
    {'label': 'Communion', 'key': 'communion'},
    {'label': 'New Testament', 'key': 'newTestament'},
    {'label': 'Old Testament', 'key': 'oldTestament'},
    {'label': 'Mass', 'key': 'mass'},
    {'label': 'Confession', 'key': 'confession'},
  ];

  static const List<Map<String, String>> days = [
    {'label': 'Saturday', 'key': 'saturday'},
    {'label': 'Sunday', 'key': 'sunday'},
    {'label': 'Monday', 'key': 'monday'},
    {'label': 'Tuesday', 'key': 'tuesday'},
    {'label': 'Wednesday', 'key': 'wednesday'},
    {'label': 'Thursday', 'key': 'thursday'},
    {'label': 'Friday', 'key': 'friday'},
  ];

  String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

  DateTime _weekStartFrom(String weekStart) => DateTime.parse(weekStart);

  String _weekStartForDate(DateTime date) {
    final target = DateTime(date.year, date.month, date.day);
    final int saturday = DateTime.saturday; // 6
    int diff = target.weekday - saturday;
    if (diff < 0) diff += 7;
    final weekStart = target.subtract(Duration(days: diff));
    return weekStart.toIso8601String().split('T').first;
  }

  DateTime _parseWeekStart(String weekStart) => DateTime.parse(weekStart);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    if (auth.isLoading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Spiritual Notebook')),
        body: Center(
          child: ElevatedButton(
            onPressed: () =>
                Navigator.pushReplacementNamed(context, AppRoutes.login),
            child: const Text('Sign in'),
          ),
        ),
      );
    }

    return ChangeNotifierProvider<SpiritualNotebookProvider>(
      create: (_) =>
          SpiritualNotebookProvider(SpiritualNotebookService())
            ..startListening(userId: user.id),
      child: Consumer<SpiritualNotebookProvider>(
        builder: (context, provider, _) {
          final notebook = provider.notebook;
          final now = DateTime.now();
          final todayName = days[now.weekday % 7]['label'];

          return Scaffold(
            backgroundColor: AppColors.surfaceSoft,
            appBar: AppBar(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              title: const Text(
                'Spiritual Notebook',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  tooltip: 'Previous week',
                                  onPressed: () {
                                    final current =
                                        notebook?.weekStartDate ??
                                        _weekStartForDate(DateTime.now());
                                    final dt = _parseWeekStart(
                                      current,
                                    ).subtract(const Duration(days: 7));
                                    final nextWeek = _weekStartForDate(dt);
                                    provider.startListening(
                                      userId: user.id,
                                      weekStartDate: nextWeek,
                                    );
                                  },
                                  icon: const Icon(Icons.chevron_left),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Week start: ${_formatDate(_parseWeekStart(notebook?.weekStartDate ?? _weekStartForDate(DateTime.now())))}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Day: ${todayName ?? ''}',
                                      style: const TextStyle(
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                                IconButton(
                                  tooltip: 'Next week',
                                  onPressed: () {
                                    final current =
                                        notebook?.weekStartDate ??
                                        _weekStartForDate(DateTime.now());
                                    final dt = _parseWeekStart(
                                      current,
                                    ).add(const Duration(days: 7));
                                    final nextWeek = _weekStartForDate(dt);
                                    provider.startListening(
                                      userId: user.id,
                                      weekStartDate: nextWeek,
                                    );
                                  },
                                  icon: const Icon(Icons.chevron_right),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                IconButton(
                                  tooltip: 'Pick a date',
                                  onPressed: () async {
                                    final initial = _parseWeekStart(
                                      notebook?.weekStartDate ??
                                          _weekStartForDate(DateTime.now()),
                                    );
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: initial,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2100),
                                    );
                                    if (picked != null) {
                                      final week = _weekStartForDate(picked);
                                      provider.startListening(
                                        userId: user.id,
                                        weekStartDate: week,
                                      );
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.calendar_today_outlined,
                                  ),
                                ),
                                if (provider.isLoading)
                                  const CircularProgressIndicator(),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (auth.isMemberManager)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: SizedBox(
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: () => Navigator.pushNamed(
                              context,
                              AppRoutes.membersNotebookSelection,
                            ),
                            icon: const Icon(Icons.groups_rounded),
                            label: const Text('View Members Notebooks'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ),
                    Expanded(
                      child: notebook == null && provider.isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : SingleChildScrollView(
                              padding: const EdgeInsets.only(bottom: 24.0),
                              child: _buildTable(
                                context,
                                notebook!,
                                user.id,
                                provider,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    try {
      final provider = context.read<SpiritualNotebookProvider?>();
      provider?.stopListening();
    } catch (_) {}
    super.dispose();
  }

  Widget _buildTable(
    BuildContext context,
    SpiritualNotebookModel notebook,
    String userId,
    SpiritualNotebookProvider provider,
  ) {
    final weekStart = _weekStartFrom(notebook.weekStartDate);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: MediaQuery.of(context).size.width,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 140,
                    child: Text(
                      'Day',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  for (final col in columns)
                    Container(
                      width: 80,
                      alignment: Alignment.center,
                      child: Text(
                        col['label']!,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Rows
            ...List.generate(days.length, (index) {
              final day = days[index];
              final dayKey = day['key']!;
              final date = weekStart.add(Duration(days: index));
              final dayMap = notebook.entries[dayKey] ?? {};

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 140,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${day['label']} - ${_formatDate(date)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      for (final col in columns)
                        GestureDetector(
                          onTap: () async {
                            await provider.toggleCell(
                              userId: userId,
                              weekStartDate: notebook.weekStartDate,
                              dayKey: dayKey,
                              fieldKey: col['key']!,
                            );
                          },
                          child: Container(
                            width: 80,
                            height: 64,
                            alignment: Alignment.center,
                            child: _buildCheckbox(dayMap[col['key']] == true),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckbox(bool value) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: value ? AppColors.primary : Colors.transparent,
        border: Border.all(color: value ? AppColors.primary : Colors.black26),
        borderRadius: BorderRadius.circular(8),
      ),
      child: value
          ? const Icon(Icons.check, color: Colors.white, size: 20)
          : const SizedBox.shrink(),
    );
  }
}
