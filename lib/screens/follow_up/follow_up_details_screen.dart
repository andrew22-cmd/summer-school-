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
import 'package:summerschool/core/localization/app_localizations.dart';

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

  Future<void> _openVisitEntryDetails(
    BuildContext context,
    FollowUpModel visit,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final dateText = DateFormat('yyyy/MM/dd').format(visit.visitDate);
        final createdAtText = DateFormat(
          'yyyy/MM/dd  HH:mm',
        ).format(visit.createdAt);
        final nextFollowUpText = visit.nextFollowUp == null
            ? ctx.tr('not_set')
            : DateFormat('yyyy/MM/dd').format(visit.nextFollowUp!);

        Widget detailRow({
          required IconData icon,
          required String title,
          required String value,
        }) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 20, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        value.trim().isEmpty ? '-' : value,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ctx.tr('visit_details'),
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  detailRow(
                    icon: Icons.calendar_month_rounded,
                    title: ctx.tr('visit_date'),
                    value:
                        '$dateText (${ctx.tr(FollowUpService.dayName(visit.visitDate))})',
                  ),
                  detailRow(
                    icon: Icons.person_rounded,
                    title: ctx.tr('servant'),
                    value: visit.servantName,
                  ),
                  detailRow(
                    icon: Icons.verified_user_rounded,
                    title: ctx.tr('responded_contacted'),
                    value: visit.responded ? ctx.tr('yes') : ctx.tr('no'),
                  ),
                  detailRow(
                    icon: Icons.category_rounded,
                    title: ctx.tr('visit_type'),
                    value: ctx.tr(visit.visitType),
                  ),
                  detailRow(
                    icon: Icons.short_text_rounded,
                    title: ctx.tr('summary'),
                    value: visit.summary,
                  ),
                  detailRow(
                    icon: Icons.notes_rounded,
                    title: ctx.tr('notes'),
                    value: visit.notes,
                  ),
                  detailRow(
                    icon: Icons.favorite_rounded,
                    title: ctx.tr('favorite_thing'),
                    value: visit.favoriteThing,
                  ),
                  detailRow(
                    icon: Icons.event_available_rounded,
                    title: ctx.tr('next_follow_up'),
                    value: nextFollowUpText,
                  ),
                  detailRow(
                    icon: Icons.history_rounded,
                    title: ctx.tr('recorded_at'),
                    value: createdAtText,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

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
              title: Text(context.tr('add_visit')),
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
                        child: Text(context.tr('choose_date')),
                      ),
                    ),
                    CheckboxListTile(
                      value: responded,
                      onChanged: (v) => setInner(() => responded = v ?? false),
                      title: Text(context.tr('responded_contacted')),
                    ),
                    TextField(
                      controller: summaryCtrl,
                      decoration: InputDecoration(
                        labelText: context.tr('summary'),
                      ),
                    ),
                    TextField(
                      controller: notesCtrl,
                      decoration: InputDecoration(
                        labelText: context.tr('notes'),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(context.tr('cancel')),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final dialogContext = ctx;
                    final messenger = ScaffoldMessenger.maybeOf(context);
                    final successMessage = context.tr('visit_added');

                    if (Navigator.of(dialogContext).canPop()) {
                      Navigator.of(dialogContext).pop();
                    }

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
                      messenger?.showSnackBar(
                        SnackBar(
                          content: Text(successMessage),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      messenger?.showSnackBar(
                        SnackBar(
                          content: Text('Failed to save: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    } finally {
                      if (mounted) setState(() => _isSaving = false);
                    }
                  },
                  child: Text(context.tr('save')),
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
        appBar: AppBar(title: Text(context.tr('visit_details'))),
        body: Center(
          child: Text(
            context.tr('only_responsible_servants'),
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
        appBar: AppBar(title: Text(context.tr('visit_details'))),
        body: Center(
          child: Text(
            context.tr('cannot_open_different_stage'),
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
        title: Text(
          readOnly
              ? context.tr('visit_details_readonly')
              : context.tr('visit_details'),
        ),
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
            final sortedVisits = [...visits]
              ..sort((a, b) => b.visitDate.compareTo(a.visitDate));
            final latest = sortedVisits.isNotEmpty ? sortedVisits.first : null;
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
                          AppColors.primary.withValues(alpha: 0.95),
                          AppColors.primary.withValues(alpha: 0.75),
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${context.tr('student_label')}${widget.student.name}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${context.tr('stage_label')}${widget.student.stage}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${context.tr('responsible_servant_label')}$servantName',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _InfoCard(
                    icon: Icons.calendar_month_rounded,
                    title: context.tr('today_label'),
                    value:
                        '${FollowUpService.dayName(currentDate)} - $formattedDate',
                  ),
                  const SizedBox(height: 12),
                  _InfoCard(
                    icon: Icons.event_repeat_rounded,
                    title: context.tr('month_start_label'),
                    value: DateFormat('yyyy/MM/dd').format(monthStart),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.tr('visits_in_month'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (visits.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(context.tr('no_visits_in_month')),
                    )
                  else
                    Column(
                      children: sortedVisits
                          .map(
                            (v) => Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: ListTile(
                                onTap: () => _openVisitEntryDetails(context, v),
                                leading: Icon(
                                  v.responded
                                      ? Icons.check_circle
                                      : Icons.cancel,
                                  color: v.responded
                                      ? Colors.green
                                      : Colors.orange,
                                ),
                                title: Text(
                                  DateFormat('yyyy/MM/dd').format(v.visitDate),
                                ),
                                subtitle: Text(
                                  v.summary.isNotEmpty
                                      ? v.summary
                                      : (v.notes.isNotEmpty
                                            ? v.notes
                                            : context.tr(
                                                'tap_to_view_details',
                                              )),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: const Icon(
                                  Icons.chevron_right_rounded,
                                ),
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
                        label: Text(context.tr('add_visit')),
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
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
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
