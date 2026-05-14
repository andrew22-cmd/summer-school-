import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:summerschool/core/constants/app_colors.dart';
import 'package:summerschool/models/user_model.dart';
import 'package:summerschool/providers/spiritual_notebook_provider.dart';
import 'package:summerschool/services/spiritual_notebook_service.dart';
import 'package:summerschool/widgets/spiritual_notebook/spiritual_notebook_table.dart';

class ReadOnlyMemberNotebookScreen extends StatefulWidget {
  const ReadOnlyMemberNotebookScreen({super.key, required this.member});

  final UserModel member;

  @override
  State<ReadOnlyMemberNotebookScreen> createState() =>
      _ReadOnlyMemberNotebookScreenState();
}

class _ReadOnlyMemberNotebookScreenState
    extends State<ReadOnlyMemberNotebookScreen> {
  static const List<Map<String, String>> columns = [
    {'label': 'باكر', 'key': 'baker'},
    {'label': 'نوم', 'key': 'sleepPrayer'},
    {'label': 'تناول', 'key': 'communion'},
    {'label': 'عهد جديد', 'key': 'newTestament'},
    {'label': 'عهد قديم', 'key': 'oldTestament'},
    {'label': 'قداس', 'key': 'mass'},
    {'label': 'اعتراف', 'key': 'confession'},
  ];

  static const List<Map<String, String>> days = [
    {'label': 'السبت', 'key': 'saturday'},
    {'label': 'الأحد', 'key': 'sunday'},
    {'label': 'الاثنين', 'key': 'monday'},
    {'label': 'الثلاثاء', 'key': 'tuesday'},
    {'label': 'الأربعاء', 'key': 'wednesday'},
    {'label': 'الخميس', 'key': 'thursday'},
    {'label': 'الجمعة', 'key': 'friday'},
  ];

  String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

  DateTime _parseWeekStart(String weekStart) => DateTime.parse(weekStart);

  String _weekStartForDate(DateTime date) {
    final target = DateTime(date.year, date.month, date.day);
    final int saturday = DateTime.saturday;
    int diff = target.weekday - saturday;
    if (diff < 0) diff += 7;
    return target
        .subtract(Duration(days: diff))
        .toIso8601String()
        .split('T')
        .first;
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SpiritualNotebookProvider>(
      create: (_) =>
          SpiritualNotebookProvider(SpiritualNotebookService())
            ..startListening(userId: widget.member.id),
      child: Consumer<SpiritualNotebookProvider>(
        builder: (context, provider, _) {
          final notebook = provider.notebook;
          final currentWeekStart =
              notebook?.weekStartDate ?? _weekStartForDate(DateTime.now());
          final weekStartDate = _parseWeekStart(currentWeekStart);
          final now = DateTime.now();

          return Scaffold(
            backgroundColor: AppColors.surfaceSoft,
            appBar: AppBar(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              title: Text(widget.member.name),
            ),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Member: ${widget.member.name}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text('Stage: ${widget.member.stage}'),
                            Text('Class: ${widget.member.className}'),
                            const SizedBox(height: 8),
                            Text('Date: ${_formatDate(now)}'),
                            Text('Day: ${_arabicDay(now.weekday)}'),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () {
                                    final prev = _parseWeekStart(
                                      currentWeekStart,
                                    ).subtract(const Duration(days: 7));
                                    provider.startListening(
                                      userId: widget.member.id,
                                      weekStartDate: _weekStartForDate(prev),
                                    );
                                  },
                                  icon: const Icon(Icons.chevron_left),
                                ),
                                Expanded(
                                  child: Center(
                                    child: Text(
                                      'Week start: ${_formatDate(weekStartDate)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    final next = _parseWeekStart(
                                      currentWeekStart,
                                    ).add(const Duration(days: 7));
                                    provider.startListening(
                                      userId: widget.member.id,
                                      weekStartDate: _weekStartForDate(next),
                                    );
                                  },
                                  icon: const Icon(Icons.chevron_right),
                                ),
                                IconButton(
                                  tooltip: 'Pick a date',
                                  onPressed: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: weekStartDate,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2100),
                                    );
                                    if (picked != null) {
                                      provider.startListening(
                                        userId: widget.member.id,
                                        weekStartDate: _weekStartForDate(
                                          picked,
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.calendar_today_outlined,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: provider.isLoading && notebook == null
                          ? const Center(child: CircularProgressIndicator())
                          : notebook == null
                          ? const Center(child: Text('No notebook data found.'))
                          : SingleChildScrollView(
                              padding: const EdgeInsets.only(bottom: 24),
                              child: SpiritualNotebookTable(
                                notebook: notebook,
                                weekStartDate: currentWeekStart,
                                columns: columns,
                                days: days,
                                formatDate: _formatDate,
                                readOnly: true,
                                onCellTap: null,
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

  String _arabicDay(int weekday) {
    const days = [
      '',
      'الاثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد',
    ];
    return days[weekday];
  }
}
