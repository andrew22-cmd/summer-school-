import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:summerschool/core/constants/app_colors.dart';
import 'package:summerschool/core/routes/app_routes.dart';
import 'package:summerschool/providers/attendance_provider.dart';
import 'package:summerschool/providers/auth_provider.dart';
import 'package:summerschool/providers/servants_attendance_provider.dart';
import 'package:summerschool/screens/attendance/servants_attendance_screen.dart';
import 'package:summerschool/services/pdf_service.dart';
import 'package:summerschool/services/servants_attendance_service.dart';
import 'package:summerschool/core/localization/app_localizations.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({
    super.key,
    this.forcedStage,
    this.readOnly = false,
    this.servantsMode = false,
  });

  final String? forcedStage;
  final bool readOnly;
  final bool servantsMode;

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  String? _startedStage;
  bool _isExportingPdf = false;
  final PdfService _pdfService = const PdfService();

  Future<void> _exportAndShareAttendancePdf({
    required String stage,
    required AttendanceProvider attendance,
  }) async {
    if (_isExportingPdf) return;

    final now = DateTime.now();
    final String currentDayName = DateFormat('EEEE').format(now);
    final String currentDateStr = DateFormat('dd-MM-yyyy').format(now);

    // ── Build data rows (fully Arabic labels) ────────────────────────────
    final messenger = ScaffoldMessenger.of(context);
    final rows = attendance.students
        .map(
          (student) => [
            student.name,
            attendance.isPresent(student.id) ? 'حاضر' : 'غائب',
            currentDateStr,
            stage,
          ],
        )
        .toList();

    if (rows.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('لا توجد بيانات حضور للتصدير.')),
      );
      return;
    }

    setState(() => _isExportingPdf = true);
    try {
      await _pdfService.generateAndShareAttendancePdf(
        arabicDayName: currentDayName,
        arabicDateStr: currentDateStr,
        headers: const ['الاسم', 'الحالة', 'التاريخ', 'المرحلة'],
        data: rows,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('تم تجهيز تقرير الحضور بنجاح.')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('فشل تصدير التقرير: $e')));
    } finally {
      if (mounted) setState(() => _isExportingPdf = false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.servantsMode) return;

    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final stage = widget.forcedStage?.trim().isNotEmpty == true
        ? widget.forcedStage!.trim()
        : (user?.stage ?? '');

    if (auth.isLoading || user == null || stage.trim().isEmpty) {
      return;
    }

    if (_startedStage == stage) return;
    _startedStage = stage;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      debugPrint('[STREAM START] AttendanceScreen starting for stage="$stage"');
      final provider = context.read<AttendanceProvider>();
      provider.startListening(stage);
      if (widget.readOnly) {
        provider.disableEditMode();
      } else {
        provider.syncEditModeFromCachedAttendance();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.servantsMode) {
      return ChangeNotifierProvider<ServantsAttendanceProvider>(
        create: (_) =>
            ServantsAttendanceProvider(service: ServantsAttendanceService()),
        child: ServantsAttendanceScreen(forcedStage: widget.forcedStage),
      );
    }

    final auth = context.watch<AuthProvider>();
    final attendance = context.watch<AttendanceProvider>();
    final user = auth.user;
    final effectiveStage = widget.forcedStage?.trim().isNotEmpty == true
        ? widget.forcedStage!.trim()
        : (user?.stage ?? '');
    final readOnly = widget.readOnly;

    if (auth.isLoading || user == null || effectiveStage.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final students = attendance.students;
    if (!attendance.isLoadingStudents) {
      debugPrint(
        '[Manager][Attendance] attendance loaded stage="$effectiveStage" students=${students.length} readOnly=$readOnly',
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surfaceSoft,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        title: Text(
          readOnly
              ? '${context.tr('attendance')} (${context.tr('read_only')})'
              : context.tr('attendance'),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: FilledButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.servantsAttendance);
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.assignment_turned_in_rounded, size: 18),
              label: Text(
                context.tr('servants_attendance'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 4),
          if (!readOnly) ...[
            TextButton.icon(
              onPressed: attendance.isEditMode || attendance.isSaving
                  ? null
                  : attendance.enableEditMode,
              icon: const Icon(Icons.edit_rounded),
              label: Text(context.tr('edit')),
            ),
            const SizedBox(width: 4),
            TextButton.icon(
              onPressed: attendance.isEditMode && !attendance.isSaving
                  ? () async {
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await attendance.saveAttendance(
                          updatedBy: auth.user?.name.trim().isNotEmpty == true
                              ? auth.user!.name.trim()
                              : (auth.user?.id ?? 'local_admin'),
                        );
                        if (!context.mounted) return;
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Attendance saved successfully.'),
                          ),
                        );
                        if (context.mounted) {
                          Navigator.of(context).pop(true);
                        }
                      } catch (e) {
                        if (!context.mounted) return;
                        messenger.showSnackBar(
                          SnackBar(content: Text('Save failed: $e')),
                        );
                      }
                    }
                  : null,
              icon: attendance.isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(context.tr('save')),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),

      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DateHeader(attendance: attendance),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        onChanged: attendance.setSearch,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search_rounded),
                          hintText: context.tr('search'),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: attendance.isLoadingStudents && students.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : attendance.error != null && students.isEmpty
                        ? _ErrorState(message: attendance.error!)
                        : students.isEmpty
                        ? _EmptyAttendanceState(stage: effectiveStage)
                        : Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _AttendanceHeaderRow(
                                    editMode: readOnly
                                        ? false
                                        : attendance.isEditMode,
                                  ),
                                  const SizedBox(height: 8),
                                  Expanded(
                                    child: ListView.separated(
                                      itemCount: students.length,
                                      separatorBuilder: (_, _) =>
                                          const SizedBox(height: 10),
                                      itemBuilder: (context, index) {
                                        final student = students[index];
                                        return _AttendanceRow(
                                          studentName: student.name,
                                          present: attendance.isPresent(
                                            student.id,
                                          ),
                                          editMode: readOnly
                                              ? false
                                              : attendance.isEditMode,
                                          onToggle: () => attendance
                                              .toggleAttendance(student.id),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ),
                  // ── Permanent Export & Share button ──────────────────────
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSoft,
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isExportingPdf
                            ? null
                            : () => _exportAndShareAttendancePdf(
                                stage: effectiveStage,
                                attendance: attendance,
                              ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          disabledBackgroundColor: AppColors.primary.withValues(
                            alpha: 0.5,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: _isExportingPdf
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.picture_as_pdf_rounded,
                                color: Colors.white,
                              ),
                        label: Text(
                          _isExportingPdf ? '...' : context.tr('export_share'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.attendance});

  final AttendanceProvider attendance;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            IconButton(
              constraints: const BoxConstraints.tightFor(width: 34, height: 34),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              onPressed: attendance.previousDay,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    context.tr(attendance.selectedEnglishDayName),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    attendance.formattedSelectedDate,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 15,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              constraints: const BoxConstraints.tightFor(width: 34, height: 34),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              onPressed: attendance.nextDay,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttendanceHeaderRow extends StatelessWidget {
  const _AttendanceHeaderRow({required this.editMode});

  final bool editMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(
              context.tr('name'),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              context.tr('status'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: editMode ? Colors.orange : AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceRow extends StatelessWidget {
  const _AttendanceRow({
    required this.studentName,
    required this.present,
    required this.editMode,
    required this.onToggle,
  });

  final String studentName;
  final bool present;
  final bool editMode;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(
              studentName,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: editMode ? onToggle : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: present
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.grey.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Checkbox(
                    value: present,
                    onChanged: editMode ? (_) => onToggle() : null,
                    activeColor: Colors.green,
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyAttendanceState extends StatelessWidget {
  const _EmptyAttendanceState({required this.stage});

  final String stage;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: Colors.grey.shade300),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: const Icon(
                  Icons.fact_check_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${context.tr('no_students')} - $stage',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: Colors.red.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, style: const TextStyle(color: Colors.red)),
        ),
      ),
    );
  }
}
