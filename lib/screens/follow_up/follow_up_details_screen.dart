import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:summerschool/core/constants/app_colors.dart';
import 'package:summerschool/models/class_member_model.dart';
import 'package:summerschool/models/follow_up_model.dart';
import 'package:summerschool/providers/auth_provider.dart';
import 'package:summerschool/models/user_model.dart';
import 'package:summerschool/constants/user_roles.dart';
import 'package:summerschool/providers/follow_up_provider.dart';
import 'package:summerschool/services/follow_up_service.dart';

class FollowUpDetailsScreen extends StatefulWidget {
  const FollowUpDetailsScreen({
    super.key,
    required this.student,
    required this.weekStartDate,
    this.readOnly = false,
  });

  final ClassMemberModel student;
  final DateTime weekStartDate; // interpreted as month start for monthly visits
  final bool readOnly;

  @override
  State<FollowUpDetailsScreen> createState() => _FollowUpDetailsScreenState();
}

class _FollowUpDetailsScreenState extends State<FollowUpDetailsScreen> {
  final TextEditingController _notesController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _openAddVisitDialog(
    BuildContext context,
    FollowUpProvider provider,
    UserModel user,
    DateTime monthStart,
  ) async {
    DateTime selected = DateTime.now();
    final summaryCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    bool responded = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setInner) {
            return AlertDialog(
              title: const Text('Add Visit'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      title: Text(DateFormat('yyyy/MM/dd').format(selected)),
                      trailing: OutlinedButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selected,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) setInner(() => selected = picked);
                        },
                        child: const Text('Choose Date'),
                      ),
                    ),
                    CheckboxListTile(
                      value: responded,
                      onChanged: (v) => setInner(() => responded = v ?? false),
                      title: const Text('Responded / Contacted'),
                    ),
                    TextField(
                      controller: summaryCtrl,
                      decoration: const InputDecoration(labelText: 'Summary'),
                    ),
                    TextField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(labelText: 'Notes'),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      setState(() => _isSaving = true);
                      await provider.saveVisit(
                        studentId: widget.student.id,
                        studentName: widget.student.name,
                        stage: widget.student.stage,
                        servantId: user.id,
                        servantName: user.name,
                        createdByRole: user.role.value,
                        visitDate: selected,
                        responded: responded,
                        visitType: 'visit',
                        summary: summaryCtrl.text.trim(),
                        notes: notesCtrl.text.trim(),
                        favoriteThing: '',
                      );
                      if (!mounted) return;
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Visit added'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to save: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    } finally {
                      if (mounted) setState(() => _isSaving = false);
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    if (auth.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (user == null ||
        (!auth.isMemberManager && !auth.isMember && !auth.isManager)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Visit Details')),
        body: Center(
          child: Text(
            'This page is available only to the servants responsible for visits.',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (!auth.isManager &&
        FollowUpService.normalizeStage(user.stage) !=
            FollowUpService.normalizeStage(widget.student.stage)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Visit Details')),
        body: Center(
          child: Text(
            'You cannot open a student from a different stage than yours.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      );
    }

    final provider = context.read<FollowUpProvider>();
    final currentDate = DateTime.now();
    final formattedDate = DateFormat('yyyy/MM/dd').format(currentDate);
    final monthStart = FollowUpService.weekStartOf(widget.weekStartDate);
    final readOnly = widget.readOnly;
    debugPrint(
      '[Manager][Visits] open details studentId=${widget.student.id} stage="${widget.student.stage}" readOnly=$readOnly',
    );

    return Scaffold(
      backgroundColor: AppColors.surfaceSoft,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        title: Text(readOnly ? 'Visit Details (Read Only)' : 'Visit Details'),
      ),
      body: SafeArea(
        child: StreamBuilder<List<FollowUpModel>>(
          stream: provider.watchMonthlyVisitsForStudent(
            studentId: widget.student.id,
            stage: widget.student.stage,
            monthDate: monthStart,
            requesterRole: user.role.value,
            requesterStage: user.stage,
          ),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final visits = snapshot.data ?? [];
            final latest = visits.isNotEmpty
                ? (visits..sort((a, b) => b.visitDate.compareTo(a.visitDate)))
                      .first
                : null;
            final servantName = latest?.servantName.isNotEmpty == true
                ? latest!.servantName
                : user.name;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withOpacity(0.95),
                          AppColors.primary.withOpacity(0.75),
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Student: ${widget.student.name}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Stage: ${widget.student.stage}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Responsible servant: $servantName',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _InfoCard(
                    icon: Icons.calendar_month_rounded,
                    title: 'Today',
                    value:
                        '${FollowUpService.dayName(currentDate)} - $formattedDate',
                  ),
                  const SizedBox(height: 12),
                  _InfoCard(
                    icon: Icons.event_repeat_rounded,
                    title: 'Month start',
                    value: DateFormat('yyyy/MM/dd').format(monthStart),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Visits in selected month',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (visits.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text('No visits recorded for this month.'),
                    )
                  else
                    Column(
                      children: visits
                          .map(
                            (v) => ListTile(
                              leading: Icon(
                                v.responded ? Icons.check_circle : Icons.cancel,
                                color: v.responded
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                              title: Text(
                                DateFormat('yyyy/MM/dd').format(v.visitDate),
                              ),
                              subtitle: Text(
                                v.summary.isNotEmpty ? v.summary : v.notes,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  const SizedBox(height: 18),
                  if (!readOnly)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving
                            ? null
                            : () async {
                                await _openAddVisitDialog(
                                  context,
                                  provider,
                                  user,
                                  monthStart,
                                );
                              },
                        icon: const Icon(Icons.add_location_alt_rounded),
                        label: const Text('Add Visit'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primary.withOpacity(0.1),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
