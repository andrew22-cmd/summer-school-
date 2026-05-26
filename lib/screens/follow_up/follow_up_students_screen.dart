import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:summerschool/core/constants/app_colors.dart';
import 'package:summerschool/models/class_member_model.dart';
import 'package:summerschool/providers/auth_provider.dart';
import 'package:summerschool/constants/user_roles.dart';
import 'package:summerschool/providers/follow_up_provider.dart';
import 'package:summerschool/screens/follow_up/follow_up_details_screen.dart';
import 'package:summerschool/services/follow_up_service.dart';

class FollowUpStudentsScreen extends StatefulWidget {
  const FollowUpStudentsScreen({
    super.key,
    this.forcedStage,
    this.readOnly = false,
  });

  final String? forcedStage;
  final bool readOnly;

  @override
  State<FollowUpStudentsScreen> createState() => _FollowUpStudentsScreenState();
}

class _FollowUpStudentsScreenState extends State<FollowUpStudentsScreen> {
  String? _startedStage;
  String _currentStageLabel = '';
  DateTime _selectedMonthStart = FollowUpService.weekStartOf(DateTime.now());

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final stage = widget.forcedStage?.trim().isNotEmpty == true
        ? widget.forcedStage!.trim()
        : (user?.stage ?? '');

    if (auth.isLoading || user == null) return;
    if (!auth.isMemberManager && !auth.isMember && !auth.isManager) return;
    if (stage.trim().isEmpty) return;
    _currentStageLabel = stage;
    if (_startedStage == stage) return;
    _startedStage = stage;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<FollowUpProvider>().startListening(
        stage,
        monthDate: _selectedMonthStart,
        requesterRole: user.role.value,
        requesterStage: user.stage,
      );
    });
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
        appBar: AppBar(title: const Text('Visits')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'This page is only available for servants responsible for visits.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
      );
    }

    final effectiveStage = widget.forcedStage?.trim().isNotEmpty == true
        ? widget.forcedStage!.trim()
        : user.stage;

    if (effectiveStage.trim().isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Visits')),
        body: const Center(
          child: Text('No stage is currently linked to your account.'),
        ),
      );
    }

    final provider = context.watch<FollowUpProvider>();
    final stageLabel = effectiveStage;
    final isReadOnly = widget.readOnly;
    final membersOnlyPending = !isReadOnly && !auth.isMemberManager;
    final visibleStudents = membersOnlyPending
        ? provider.students
              .where((s) => !provider.contactedForStudent(s.id))
              .toList()
        : provider.students;
    if (!provider.isLoading) {
      debugPrint(
        '[Manager][Visits] visits loaded stage="$stageLabel" students=${provider.students.length} visible=${visibleStudents.length} readOnly=$isReadOnly',
      );
    }
    final weekLabel = DateFormat('yyyy/MM').format(provider.currentMonthStart);

    return Scaffold(
      backgroundColor: AppColors.surfaceSoft,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        title: Text(isReadOnly ? 'Visits (Read Only)' : 'Visits'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            context.read<FollowUpProvider>().startListening(
              stageLabel,
              monthDate: _selectedMonthStart,
              requesterRole: user.role.value,
              requesterStage: user.stage,
            );
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final crossAxisCount = width >= 1100
                  ? 3
                  : width >= 700
                  ? 2
                  : 1;

              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeaderCard(stage: stageLabel, weekLabel: weekLabel),
                    const SizedBox(height: 12),
                    _MonthSelector(
                      selectedMonthStart: _selectedMonthStart,
                      onPickMonth: _pickMonth,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Stage Students',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (provider.isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 48),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (provider.error != null)
                      _buildError(provider.error!)
                    else if (visibleStudents.isEmpty)
                      _buildEmptyState(membersOnlyPending)
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: visibleStudents.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: crossAxisCount == 1 ? 2.25 : 1.7,
                        ),
                        itemBuilder: (context, index) {
                          final student = visibleStudents[index];
                          final visitsCount = provider.visitsCountForStudent(
                            student.id,
                          );
                          return _StudentCard(
                            student: student,
                            visitsCount: visitsCount,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FollowUpDetailsScreen(
                                    student: student,
                                    weekStartDate: _selectedMonthStart,
                                    readOnly: isReadOnly,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _pickMonth() async {
    final initial = _selectedMonthStart;
    int selYear = initial.year;
    int selMonth = initial.month;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setInner) {
            return AlertDialog(
              title: const Text('Choose month'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: () => setInner(() => selYear -= 1),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Text(
                        selYear.toString(),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      IconButton(
                        onPressed: () => setInner(() => selYear += 1),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(12, (i) {
                      final m = i + 1;
                      final isSelected = m == selMonth;
                      final label = DateFormat.MMM().format(DateTime(0, m));
                      return ChoiceChip(
                        label: Text(label),
                        selected: isSelected,
                        onSelected: (_) => setInner(() => selMonth = m),
                        selectedColor: Theme.of(context).primaryColor,
                      );
                    }),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    final newMonthStart = DateTime(selYear, selMonth, 1);
    if (!mounted) return;
    setState(() {
      _selectedMonthStart = newMonthStart;
    });

    final auth = context.read<AuthProvider>();
    final user = auth.user!;
    context.read<FollowUpProvider>().startListening(
      _currentStageLabel,
      monthDate: _selectedMonthStart,
      requesterRole: user.role.value,
      requesterStage: user.stage,
    );
  }

  Widget _buildError(String error) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Text(
          'Error: $error',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.red.shade700),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool membersOnlyPending) {
    final message = membersOnlyPending
        ? 'Great job. No pending (not-contacted) students for this month.'
        : 'No students found in your stage at the moment.';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.groups_rounded, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(message, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.stage, required this.weekLabel});

  final String stage;
  final String weekLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
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
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Monthly Visits Follow-up',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text('Stage: $stage', style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 4),
          Text(
            'Selected month: $weekLabel',
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _MonthSelector extends StatelessWidget {
  const _MonthSelector({
    required this.selectedMonthStart,
    required this.onPickMonth,
  });

  final DateTime selectedMonthStart;
  final VoidCallback onPickMonth;

  @override
  Widget build(BuildContext context) {
    final monthEnd = DateTime(
      selectedMonthStart.year,
      selectedMonthStart.month + 1,
      0,
    );
    final formatter = DateFormat('yyyy/MM/dd');

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selected Month',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${formatter.format(selectedMonthStart)}  →  ${formatter.format(monthEnd)}',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: onPickMonth,
              icon: const Icon(Icons.date_range_rounded),
              label: const Text('Choose Month'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentCard extends StatelessWidget {
  const _StudentCard({
    required this.student,
    required this.visitsCount,
    required this.onTap,
  });

  final ClassMemberModel student;
  final int visitsCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = visitsCount >= 2
        ? Colors.green
        : (visitsCount == 1 ? Colors.orange : Colors.redAccent);

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: Icon(Icons.person_rounded, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    student.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${visitsCount.toString()}/2',
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        visitsCount >= 2 ? 'Contacted' : 'Not contacted',
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Stage: ${student.stage}',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Visit Details'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
