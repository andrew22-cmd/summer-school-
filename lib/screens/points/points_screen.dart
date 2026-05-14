import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:summerschool/core/constants/app_colors.dart';
import 'package:summerschool/models/class_member_model.dart';
import 'package:summerschool/providers/auth_provider.dart';
import 'package:summerschool/providers/class_member_provider.dart';
import 'package:summerschool/providers/points_provider.dart';
import 'package:summerschool/screens/points/add_points_screen.dart';
import 'package:summerschool/screens/points/points_history_screen.dart';
import 'package:summerschool/services/points_service.dart';

class PointsScreen extends StatefulWidget {
  const PointsScreen({super.key});

  @override
  State<PointsScreen> createState() => _PointsScreenState();
}

class _PointsScreenState extends State<PointsScreen> {
  String? _startedStage;
  String? _startedHistoryStage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final stage = user?.stage ?? '';

    if (auth.isLoading || user == null || stage.trim().isEmpty) {
      debugPrint(
        '[PointsScreen] Waiting for auth/stage. isLoading=${auth.isLoading} stage="$stage"',
      );
      return;
    }

    if (_startedStage == stage) return;
    _startedStage = stage;

    debugPrint(
      '[PointsScreen] Starting realtime members stream for stage="$stage" stage_norm="${stage.replaceAll(' ', '').toLowerCase()}"',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ClassMemberProvider>().startListening(stage);
    });

    if (_startedHistoryStage == stage) return;
    _startedHistoryStage = stage;

    debugPrint(
      '[PointsScreen] Starting realtime points-history stream for stage="$stage"',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PointsProvider>().startListeningTotals(stage);
    });
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[UI REBUILD] PointsScreen.build() called');
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Watch ClassMemberProvider for members list (source of truth for totalPoints)
    final memberProvider = context.watch<ClassMemberProvider>();
    final pointsProvider = context.watch<PointsProvider>();
    debugPrint(
      '[UI REBUILD] PointsScreen watching ClassMemberProvider - provider notified',
    );
    final students = memberProvider.members;
    debugPrint(
      '[UI REBUILD] PointsScreen got ${students.length} students from provider',
    );
    for (final s in students) {
      debugPrint('[UI REBUILD]   - ${s.name}: totalPoints=${s.totalPoints}');
    }
    final canEdit = true;

    return Scaffold(
      backgroundColor: AppColors.surfaceSoft,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        title: const Text('Points (الطايوهات)'),
        actions: [
          IconButton(
            tooltip: 'History',
            icon: const Icon(Icons.history_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) => ChangeNotifierProvider.value(
                    value: context.read<PointsProvider>(),
                    child: const PointsHistoryScreen(),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    onChanged: memberProvider.setSearch,
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
                child: memberProvider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : students.isEmpty
                    ? _EmptyPointsState(stage: user.stage)
                    : NotificationListener<ScrollNotification>(
                        onNotification: (_) {
                          debugPrint(
                            '[PointsScreen] student list scroll/rebuild notification',
                          );
                          return false;
                        },
                        child: ListView.separated(
                          itemCount: students.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final student = students[index];
                            debugPrint(
                              '[UI REBUILD] itemBuilder[$index] student="${student.name}" totalPoints=${student.totalPoints}',
                            );
                            return Consumer<ClassMemberProvider>(
                              builder: (context, memberProvider, _) {
                                debugPrint(
                                  '[UI REBUILD] Consumer[$index] watching ClassMemberProvider for "${student.name}"',
                                );
                                // Get the fresh student object from provider to ensure totalPoints is up-to-date
                                final freshStudent = memberProvider.allMembers
                                    .firstWhere(
                                      (m) => m.id == student.id,
                                      orElse: () => student,
                                    );
                                final liveTotal =
                                    pointsProvider.currentTotalForStudent(
                                      freshStudent.id,
                                    ) ??
                                    freshStudent.totalPoints;
                                debugPrint(
                                  '[UI REBUILD] Consumer[$index] fresh student="${freshStudent.name}" totalPoints=${freshStudent.totalPoints} liveTotal=$liveTotal',
                                );
                                return _PointsStudentCard(
                                  student: freshStudent,
                                  currentTotal: liveTotal,
                                  canEdit: canEdit,
                                  onAdd: () => _openAddPoints(
                                    context,
                                    freshStudent,
                                    PointsActionMode.add,
                                  ),
                                  onRemove: () => _openAddPoints(
                                    context,
                                    freshStudent,
                                    PointsActionMode.remove,
                                  ),
                                  onHistory: () =>
                                      _openHistory(context, freshStudent),
                                );
                              },
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openAddPoints(
    BuildContext context,
    ClassMemberModel student,
    PointsActionMode mode,
  ) {
    debugPrint(
      '[NAVIGATION] PointsScreen -> AddPointsScreen studentId=${student.id} mode=${mode.name}',
    );
    final memberProvider = context.read<ClassMemberProvider>();
    final pointsProvider = context.read<PointsProvider>();
    debugPrint('[PROVIDER FOUND] ClassMemberProvider found in PointsScreen');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => MultiProvider(
          providers: [
            ChangeNotifierProvider<ClassMemberProvider>.value(
              value: memberProvider,
            ),
            ChangeNotifierProvider<PointsProvider>.value(value: pointsProvider),
          ],
          child: AddPointsScreen(selectedStudent: student, initialMode: mode),
        ),
      ),
    );
  }

  void _openHistory(BuildContext context, ClassMemberModel student) {
    debugPrint(
      '[NAVIGATION] PointsScreen -> PointsHistoryScreen studentId=${student.id}',
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => ChangeNotifierProvider<PointsProvider>(
          create: (_) => PointsProvider(PointsService())
            ..startListeningHistory(
              context.read<AuthProvider>().user?.stage ?? '',
              studentId: student.id,
            ),
          child: PointsHistoryScreen(student: student),
        ),
      ),
    );
  }
}

class _PointsStudentCard extends StatelessWidget {
  const _PointsStudentCard({
    required this.student,
    required this.currentTotal,
    required this.canEdit,
    required this.onAdd,
    required this.onRemove,
    required this.onHistory,
  });

  final ClassMemberModel student;
  final int currentTotal;
  final bool canEdit;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    debugPrint(
      '[UI REBUILD][_PointsStudentCard] build() studentId=${student.id} name="${student.name}" totalPoints=${student.totalPoints} currentTotal=$currentTotal',
    );
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 700;
            final content = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text('Stage: ${student.stage}'),
                Text(
                  'Total Points: $currentTotal',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Colors.green,
                  ),
                ),
              ],
            );

            final actions = Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (canEdit)
                  OutlinedButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Add Points'),
                  ),
                if (canEdit)
                  OutlinedButton.icon(
                    onPressed: onRemove,
                    icon: const Icon(Icons.remove_circle_outline),
                    label: const Text('Remove Points'),
                  ),
                OutlinedButton.icon(
                  onPressed: onHistory,
                  icon: const Icon(Icons.history_rounded),
                  label: const Text('View History'),
                ),
              ],
            );

            if (isWide) {
              return Row(
                children: [
                  Expanded(child: content),
                  const SizedBox(width: 12),
                  actions,
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [content, const SizedBox(height: 12), actions],
            );
          },
        ),
      ),
    );
  }
}

class _EmptyPointsState extends StatelessWidget {
  const _EmptyPointsState({required this.stage});

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
                  Icons.emoji_events_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'No students found for $stage',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              const Text('Points appear for students in your current stage.'),
            ],
          ),
        ),
      ),
    );
  }
}
