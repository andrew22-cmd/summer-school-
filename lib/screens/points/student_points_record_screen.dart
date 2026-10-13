import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:summerschool/core/constants/app_colors.dart';
import 'package:summerschool/models/class_member_model.dart';
import 'package:summerschool/providers/auth_provider.dart';
import 'package:summerschool/providers/points_provider.dart';
import 'package:summerschool/services/pdf_service.dart';
import 'package:summerschool/core/localization/app_localizations.dart';

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
    return DateFormat('dd-MM-yyyy').format(dt.toLocal());
  }

  Future<void> _exportAndSharePointsPdf({
    required String stage,
    required PointsProvider provider,
  }) async {
    if (_isExportingPdf) return;

    final messenger = ScaffoldMessenger.of(context);

    // ── Resolve student identity ───────────────────────────────────────
    final student = widget.student;
    final studentName = student?.name ??
        (provider.history.isNotEmpty ? provider.history.first.studentName : stage);
    final studentCode = student?.id ?? stage;
    // Live balance: prefer the provider-tracked total, fall back to model field.
    final int currentPoints = student != null
        ? (provider.currentTotalForStudent(student.id) ?? student.totalPoints)
        : 0;

    // ── Build 4-column Arabic rows ────────────────────────────────────
    // Columns: ['التاريخ', 'النقاط', 'السبب / البيان', 'بواسطة']
    final rows = provider.history
        .map(
          (item) => [
            _formatDate(item.createdAt),
            '${item.isAdd ? '+' : '-'}${item.points}',
            item.reason,
            item.createdByName,
          ],
        )
        .toList();

    if (rows.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('لا توجد بيانات نقاط للتصدير.'),
        ),
      );
      return;
    }

    setState(() => _isExportingPdf = true);
    try {
      await _pdfService.generateAndSharePointsPdf(
        studentName: studentName,
        studentCode: studentCode,
        currentPoints: currentPoints,
        data: rows,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('تم تجهيز تقرير النقاط بنجاح.')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('فشل تصدير التقرير: $e')),
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
              ? '${widget.student!.name} ${context.tr('points_record')}'
              : context.tr('points_record'),
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
        label: Text(_isExportingPdf ? context.tr('exporting') : context.tr('export_share')),
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
                          ? Center(child: Text(context.tr('no_point_records')))
                          : SingleChildScrollView(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  headingRowColor: WidgetStatePropertyAll(
                                    AppColors.primary.withOpacity(0.08),
                                  ),
                                  columnSpacing: 24,
                                  columns: [
                                    DataColumn(label: Text(context.tr('date'))),
                                    DataColumn(label: Text(context.tr('add_remove'))),
                                    DataColumn(label: Text(context.tr('points'))),
                                    DataColumn(label: Text(context.tr('reason'))),
                                    DataColumn(label: Text(context.tr('added_by'))),
                                    DataColumn(label: Text(context.tr('before'))),
                                    DataColumn(label: Text(context.tr('after'))),
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
                                            context.tr(isAdd ? 'add' : 'remove'),
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
