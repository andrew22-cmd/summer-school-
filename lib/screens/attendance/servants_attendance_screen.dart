import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:summerschool/core/constants/app_colors.dart';
import 'package:summerschool/providers/auth_provider.dart';
import 'package:summerschool/providers/servants_attendance_provider.dart';

class ServantsAttendanceScreen extends StatefulWidget {
  const ServantsAttendanceScreen({super.key, this.forcedStage});

  final String? forcedStage;

  @override
  State<ServantsAttendanceScreen> createState() =>
      _ServantsAttendanceScreenState();
}

class _ServantsAttendanceScreenState extends State<ServantsAttendanceScreen> {
  bool _started = false;

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
    final dateLabel = DateFormat(
      'EEEE - d MMMM yyyy',
      'en',
    ).format(provider.selectedDate);

    return Scaffold(
      backgroundColor: AppColors.surfaceSoft,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        title: const Text('Servants Attendance'),
        actions: [
          if (provider.canEdit) ...[
            TextButton.icon(
              onPressed: provider.isEditMode || provider.isSaving
                  ? null
                  : provider.enableEditMode,
              icon: const Icon(Icons.edit_rounded),
              label: const Text('EDIT'),
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
              label: const Text('SAVE'),
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
                                icon: const Icon(Icons.chevron_left_rounded),
                              ),
                              Expanded(
                                child: Text(
                                  dateLabel,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: provider.nextDay,
                                icon: const Icon(Icons.chevron_right_rounded),
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
                                    value: provider.selectedStage.isEmpty
                                        ? null
                                        : provider.selectedStage,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Stage',
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
                  Expanded(
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
                            separatorBuilder: (_, __) =>
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
