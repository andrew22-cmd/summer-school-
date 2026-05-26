import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:summerschool/core/constants/app_colors.dart';
import 'package:summerschool/models/class_member_model.dart';
import 'package:summerschool/providers/auth_provider.dart';
import 'package:summerschool/providers/points_provider.dart';

class StudentPointsRecordScreen extends StatefulWidget {
  const StudentPointsRecordScreen({super.key, this.student});

  final ClassMemberModel? student;

  @override
  State<StudentPointsRecordScreen> createState() =>
      _StudentPointsRecordScreenState();
}

class _StudentPointsRecordScreenState extends State<StudentPointsRecordScreen> {
  String? _startedStage;

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${local.year}/${two(local.month)}/${two(local.day)}';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final provider = context.watch<PointsProvider>();
    final stage = auth.user?.stage ?? '';
    final stageNorm = stage.replaceAll(' ', '').toLowerCase();

    if (!auth.isLoading && auth.user != null && stageNorm.isNotEmpty) {
      if (_startedStage != stage) {
        _startedStage = stage;
        debugPrint(
          '[StudentPointsRecordScreen] Starting realtime records stream stage="$stage" studentId=${widget.student?.id ?? 'ALL'}',
        );
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          final latestStage = context.read<AuthProvider>().user?.stage ?? '';
          if (latestStage.trim().isEmpty) return;
          final pointsProvider = context.read<PointsProvider>();
          try {
            await pointsProvider.startListeningHistory(
              latestStage,
              studentId: widget.student?.id,
            );
          } catch (e) {
            debugPrint(
              '[StudentPointsRecordScreen] failed to start stream: $e',
            );
          }
        });
      }
    }

    final records = provider.history;
    final isSingleStudent = widget.student != null;

    return Scaffold(
      backgroundColor: AppColors.surfaceSoft,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        title: Text(
          isSingleStudent
              ? '${widget.student!.name} Points Record'
              : 'Student Points Record System',
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: provider.error != null
              ? Center(child: Text(provider.error ?? 'Unknown error'))
              : provider.isLoadingHistory
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: records.isEmpty
                          ? const Center(child: Text('No point records yet.'))
                          : SingleChildScrollView(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  headingRowColor: WidgetStatePropertyAll(
                                    AppColors.primary.withOpacity(0.08),
                                  ),
                                  columnSpacing: 24,
                                  columns: const [
                                    DataColumn(label: Text('Date')),
                                    DataColumn(label: Text('Add/Remove')),
                                    DataColumn(label: Text('Points')),
                                    DataColumn(label: Text('Reason')),
                                    DataColumn(label: Text('Added By')),
                                    DataColumn(label: Text('Before')),
                                    DataColumn(label: Text('After')),
                                  ],
                                  rows: records.map((item) {
                                    final isAdd = item.isAdd;
                                    final color = isAdd
                                        ? Colors.green
                                        : Colors.red;
                                    return DataRow(
                                      cells: [
                                        DataCell(
                                          Text(_formatDate(item.createdAt)),
                                        ),
                                        DataCell(
                                          Text(
                                            isAdd ? 'Add' : 'Remove',
                                            style: TextStyle(
                                              color: color,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            '${isAdd ? '+' : '-'}${item.points}',
                                            style: TextStyle(
                                              color: color,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          SizedBox(
                                            width: 220,
                                            child: Text(
                                              item.reason,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                        DataCell(Text(item.createdByName)),
                                        DataCell(
                                          Text('${item.totalPointsBefore}'),
                                        ),
                                        DataCell(
                                          Text('${item.totalPointsAfter}'),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
