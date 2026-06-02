import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:summerschool/core/constants/app_colors.dart';
import 'package:summerschool/models/class_member_model.dart';
import 'package:summerschool/providers/auth_provider.dart';
import 'package:summerschool/providers/points_provider.dart';
import 'package:summerschool/services/pdf_service.dart';

class StudentPointsRecordScreen extends StatefulWidget {
  const StudentPointsRecordScreen({super.key, this.student});

  final ClassMemberModel? student;

  @override
  State<StudentPointsRecordScreen> createState() =>
      _StudentPointsRecordScreenState();
}

class _StudentPointsRecordScreenState extends State<StudentPointsRecordScreen> {
  String? _startedStage;
  bool _isExportingPdf = false;
  final PdfService _pdfService = const PdfService();

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${local.year}/${two(local.month)}/${two(local.day)}';
  }

  Future<void> _exportAndSharePointsPdf({
    required String stage,
    required PointsProvider provider,
  }) async {
    if (_isExportingPdf) return;

    final messenger = ScaffoldMessenger.of(context);
    final rows = provider.history
        .map(
          (item) => [
            _formatDate(item.createdAt),
            item.studentName,
            item.isAdd ? 'Add' : 'Remove',
            '${item.isAdd ? '+' : '-'}${item.points}',
            item.reason,
            item.createdByName,
            '${item.totalPointsBefore}',
            '${item.totalPointsAfter}',
            stage,
          ],
        )
        .toList();

    if (rows.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No points history available to export.')),
      );
      return;
    }

    setState(() => _isExportingPdf = true);
    try {
      await _pdfService.generateAndShareTablePdf(
        title: widget.student == null
            ? 'Student Points History - $stage'
            : '${widget.student!.name} Points History',
        headers: const [
          'Date',
          'Student',
          'Action',
          'Points',
          'Reason',
          'Added By',
          'Before',
          'After',
          'Stage',
        ],
        data: rows,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Points history PDF ready to share.')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to export points PDF: $e')),
      );
    } finally {
      if (mounted) setState(() => _isExportingPdf = false);
    }
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isExportingPdf
            ? null
            : () => _exportAndSharePointsPdf(stage: stage, provider: provider),
        icon: _isExportingPdf
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.picture_as_pdf_rounded),
        label: Text(_isExportingPdf ? 'Exporting...' : 'Export & Share'),
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
