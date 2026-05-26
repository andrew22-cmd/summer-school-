import 'package:flutter/material.dart';
import 'package:summerschool/core/constants/app_colors.dart';
import 'package:summerschool/models/spiritual_notebook_model.dart';

class SpiritualNotebookTable extends StatelessWidget {
  const SpiritualNotebookTable({
    super.key,
    required this.notebook,
    required this.weekStartDate,
    required this.columns,
    required this.days,
    required this.formatDate,
    required this.onCellTap,
    this.readOnly = false,
  });

  final SpiritualNotebookModel notebook;
  final String weekStartDate;
  final List<Map<String, String>> columns;
  final List<Map<String, String>> days;
  final String Function(DateTime) formatDate;
  final Future<void> Function(String dayKey, String fieldKey)? onCellTap;
  final bool readOnly;

  DateTime get _weekStart => DateTime.parse(weekStartDate);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: MediaQuery.of(context).size.width,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 140,
                    child: Text(
                      'Day',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  for (final col in columns)
                    SizedBox(
                      width: 80,
                      child: Center(
                        child: Text(
                          col['label']!,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ...List.generate(days.length, (index) {
              final day = days[index];
              final dayKey = day['key']!;
              final date = _weekStart.add(Duration(days: index));
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
                          child: Text(
                            '${day['label']} - ${formatDate(date)}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      for (final col in columns)
                        SizedBox(
                          width: 80,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 2.0,
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: readOnly || onCellTap == null
                                  ? null
                                  : () => onCellTap!(dayKey, col['key']!),
                              child: Container(
                                height: 64,
                                alignment: Alignment.center,
                                child: _buildCheckbox(
                                  dayMap[col['key']] == true,
                                  readOnly: readOnly,
                                ),
                              ),
                            ),
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

  Widget _buildCheckbox(bool value, {required bool readOnly}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: value ? AppColors.primary : Colors.transparent,
        border: Border.all(
          color: value ? AppColors.primary : Colors.black26,
          width: 1.2,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: value
          ? Icon(
              readOnly ? Icons.check_circle : Icons.check,
              color: Colors.white,
              size: 20,
            )
          : const SizedBox.shrink(),
    );
  }
}
