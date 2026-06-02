import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:summerschool/core/constants/app_colors.dart';
import 'package:summerschool/core/routes/app_routes.dart';
import 'package:summerschool/providers/attendance_provider.dart';
import 'package:summerschool/providers/auth_provider.dart';
import 'package:summerschool/providers/servants_attendance_provider.dart';
import 'package:summerschool/screens/attendance/servants_attendance_screen.dart';
import 'package:summerschool/services/pdf_service.dart';
import 'package:summerschool/services/servants_attendance_service.dart';

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

    final messenger = ScaffoldMessenger.of(context);
    final rows = attendance.students
        .map(
          (student) => [
            student.name,
            attendance.isPresent(student.id) ? 'Present' : 'Absent',
            attendance.formattedSelectedDate,
            stage,
          ],
        )
        .toList();

    if (rows.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No attendance data available to export.')),
      );
      return;
    }

    setState(() => _isExportingPdf = true);
    try {
      await _pdfService.generateAndShareTablePdf(
        title: 'Attendance - $stage',
        headers: const ['Student', 'Status', 'Date', 'Stage'],
        data: rows,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Attendance PDF ready to share.')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to export attendance PDF: $e')),
      );
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
        title: Text(readOnly ? 'Attendance (Read Only)' : 'Attendance'),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.servantsAttendance);
            },
            icon: const Icon(Icons.assignment_turned_in_rounded),
            label: const Text('Servants Attendance'),
          ),
          const SizedBox(width: 4),
          if (!readOnly) ...[
            TextButton.icon(
              onPressed: attendance.isEditMode || attendance.isSaving
                  ? null
                  : attendance.enableEditMode,
              icon: const Icon(Icons.edit_rounded),
              label: const Text('EDIT'),
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
              label: const Text('SAVE'),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isExportingPdf
            ? null
            : () => _exportAndShareAttendancePdf(
                stage: effectiveStage,
                attendance: attendance,
              ),
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
                          hintText: 'Search by student name',
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
                                      separatorBuilder: (_, __) =>
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
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            IconButton(
              onPressed: attendance.previousDay,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    '${attendance.selectedEnglishDayName}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    attendance.formattedSelectedDate,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
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
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Expanded(
            flex: 5,
            child: Text('Name', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Status',
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
                        ? Colors.green.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.08),
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
                backgroundColor: AppColors.primary.withOpacity(0.1),
                child: const Icon(
                  Icons.fact_check_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'No students found for $stage',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              const Text('Attendance appears here for your current stage.'),
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
