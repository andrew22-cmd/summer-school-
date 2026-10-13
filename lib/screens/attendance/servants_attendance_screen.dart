import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:summerschool/core/constants/app_colors.dart';
import 'package:summerschool/providers/auth_provider.dart';
import 'package:summerschool/providers/servants_attendance_provider.dart';
import 'package:summerschool/services/pdf_service.dart';
import 'package:summerschool/core/localization/app_localizations.dart';

class ServantsAttendanceScreen extends StatefulWidget {
  const ServantsAttendanceScreen({super.key, this.forcedStage});

  final String? forcedStage;

  @override
  State<ServantsAttendanceScreen> createState() =>
      _ServantsAttendanceScreenState();
}

class _ServantsAttendanceScreenState extends State<ServantsAttendanceScreen> {
  bool _started = false;
  bool _isExportingPdf = false;
  final PdfService _pdfService = const PdfService();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;

    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    if (auth.isLoading || user == null) return;

    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ServantsAttendanceProvider>().startListening(
        user: user,
        forcedStage: widget.forcedStage,
      );
    });
  }

  // ── PDF export ────────────────────────────────────────────────────────
  Future<void> _exportAndShareServantsPdf(
    ServantsAttendanceProvider provider,
  ) async {
    if (_isExportingPdf) return;

    final now = DateTime.now();
    final String arabicDayName = DateFormat('EEEE').format(now);
    final String arabicDateStr = DateFormat('dd-MM-yyyy').format(now);

    // ── Build rows from live servant list ──────────────────────────────
    final messenger = ScaffoldMessenger.of(context);
    final rows = provider.servants
        .map(
          (servant) => [
            servant.name,
            provider.attendedForServant(servant.id) ? 'حاضر' : 'غائب',
            arabicDateStr,
          ],
        )
        .toList();

    if (rows.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('لا توجد بيانات خدام للتصدير.')),
      );
      return;
    }

    setState(() => _isExportingPdf = true);
    try {
      await _pdfService.generateAndShareAttendancePdf(
        arabicDayName: arabicDayName,
        arabicDateStr: arabicDateStr,
        headers: const ['الاسم', 'الحالة', 'التاريخ'],
        data: rows,
        title: 'تقرير حضور وغياب الخدام',
        fileNamePrefix: 'تقرير_حضور_الخدام',
      );
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('تم تجهيز تقرير حضور الخدام بنجاح.')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('فشل تصدير التقرير: $e')));
    } finally {
      if (mounted) setState(() => _isExportingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final provider = context.watch<ServantsAttendanceProvider>();
    final user = auth.user;

    if (auth.isLoading || user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!auth.isMember && !auth.isMemberManager && !auth.isManager) {
      return const Scaffold(
        body: Center(
          child: Text('You are not allowed to view servants attendance.'),
        ),
      );
    }

    final width = MediaQuery.sizeOf(context).width;
    final englishDay = DateFormat('EEEE', 'en').format(provider.selectedDate);
    final dateStr = DateFormat('yyyy-MM-dd').format(provider.selectedDate);
    final dayName = context.tr(englishDay);

    return Scaffold(
      backgroundColor: AppColors.surfaceSoft,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        title: Text(context.tr('servants_attendance')),
        actions: [
          if (provider.canEdit) ...[
            TextButton.icon(
              onPressed: provider.isEditMode || provider.isSaving
                  ? null
                  : provider.enableEditMode,
              icon: const Icon(Icons.edit_rounded),
              label: Text(context.tr('edit')),
            ),
            TextButton.icon(
              onPressed: provider.isEditMode && !provider.isSaving
                  ? () async {
                      try {
                        await provider.saveAttendance();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Servants attendance saved successfully.',
                            ),
                          ),
                        );
                        if (context.mounted) {
                          Navigator.of(context).pop(true);
                        }
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Save failed: $e')),
                        );
                      }
                    }
                  : null,
              icon: provider.isSaving
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  IconButton(
                                    onPressed: provider.previousDay,
                                    icon: const Icon(
                                      Icons.chevron_left_rounded,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      '$dayName - $dateStr',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: provider.nextDay,
                                    icon: const Icon(
                                      Icons.chevron_right_rounded,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_today_rounded,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(provider.dayNameArabic),
                                  const Spacer(),
                                  if (provider.isManager)
                                    Flexible(
                                      child: DropdownButtonFormField<String>(
                                        initialValue:
                                            provider.selectedStage.isEmpty
                                            ? null
                                            : provider.selectedStage,
                                        isExpanded: true,
                                        decoration: InputDecoration(
                                          labelText: context.tr('stage'),
                                          border: OutlineInputBorder(),
                                          isDense: true,
                                        ),
                                        items: provider.availableStages
                                            .map(
                                              (s) => DropdownMenuItem(
                                                value: s,
                                                child: Text(s),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: (value) {
                                          if (value == null) return;
                                          provider.setSelectedStage(value);
                                        },
                                      ),
                                    )
                                  else
                                    Text('Stage: ${provider.selectedStage}'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: TextField(
                            onChanged: provider.setSearch,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.search_rounded),
                              hintText: 'Search by servant name',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
                // ── Scrollable servants list ───────────────────────────────
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child:
                        provider.isLoadingServants ||
                            provider.isLoadingAttendance
                        ? const Center(child: CircularProgressIndicator())
                        : provider.error != null
                        ? Center(child: Text(provider.error!))
                        : provider.servants.isEmpty
                        ? const Center(
                            child: Text('No servants found in this stage.'),
                          )
                        : ListView.separated(
                            physics: const BouncingScrollPhysics(),
                            itemCount: provider.servants.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final servant = provider.servants[index];
                              final attended = provider.attendedForServant(
                                servant.id,
                              );
                              final roleLabel = servant.isMemberManager
                                  ? 'member manager'
                                  : 'member';
                              final roleLabelAr = servant.isMemberManager
                                  ? 'Servant Supervisor'
                                  : 'Servant';

                              return Card(
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(color: Colors.grey.shade300),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  child: width < 560
                                      ? Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              servant.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              dateStr,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium
                                                  ?.copyWith(
                                                    color: Colors.grey.shade700,
                                                  ),
                                            ),
                                            Text(
                                              '$roleLabelAr ($roleLabel)',
                                              style: TextStyle(
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Align(
                                              alignment: Alignment.centerRight,
                                              child: Checkbox(
                                                value: attended,
                                                onChanged:
                                                    (provider.canEdit &&
                                                        provider.isEditMode)
                                                    ? (_) => provider
                                                          .toggleAttendance(
                                                            servant.id,
                                                          )
                                                    : null,
                                              ),
                                            ),
                                          ],
                                        )
                                      : Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                servant.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child: Text(
                                                '$roleLabelAr ($roleLabel)',
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                            Checkbox(
                                              value: attended,
                                              onChanged:
                                                  (provider.canEdit &&
                                                      provider.isEditMode)
                                                  ? (_) => provider
                                                        .toggleAttendance(
                                                          servant.id,
                                                        )
                                                  : null,
                                            ),
                                          ],
                                        ),
                                ),
                              );
                            },
                          ),
                  ),
                ),
                // ── Permanent Export & Share button ──────────────────────
                Container(
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
                          : () => _exportAndShareServantsPdf(provider),
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
                        _isExportingPdf
                            ? context.tr('exporting')
                            : context.tr('export_share'),
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
    );
  }
}
