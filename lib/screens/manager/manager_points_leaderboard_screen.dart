import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:summerschool/core/constants/app_colors.dart';
import 'package:summerschool/models/class_member_model.dart';
import 'package:summerschool/providers/class_member_provider.dart';
import 'package:summerschool/providers/points_provider.dart';
import 'package:summerschool/screens/points/points_history_screen.dart';
import 'package:summerschool/services/points_service.dart';

class ManagerPointsLeaderboardScreen extends StatefulWidget {
  const ManagerPointsLeaderboardScreen({super.key, required this.stage});

  final String stage;

  @override
  State<ManagerPointsLeaderboardScreen> createState() =>
      _ManagerPointsLeaderboardScreenState();
}

class _ManagerPointsLeaderboardScreenState
    extends State<ManagerPointsLeaderboardScreen> {
  String _query = '';
  String? _startedStage;

  void _openHistory(BuildContext context, ClassMemberModel member) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider<PointsProvider>(
          create: (_) =>
              PointsProvider(PointsService())
                ..startListeningHistory(widget.stage, studentId: member.id),
          child: PointsHistoryScreen(student: member),
        ),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_startedStage == widget.stage) return;
    _startedStage = widget.stage;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      debugPrint(
        '[Manager][Leaderboard] start listening for stage="${widget.stage}"',
      );
      context.read<ClassMemberProvider>().startListening(widget.stage);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClassMemberProvider>();

    final filtered = provider.allMembers.where((member) {
      final q = _query.trim().toLowerCase();
      return q.isEmpty || member.name.toLowerCase().contains(q);
    }).toList()..sort((a, b) => b.totalPoints.compareTo(a.totalPoints));

    if (!provider.isLoading) {
      debugPrint(
        '[Manager][Leaderboard] snapshot received stage="${widget.stage}" count=${provider.allMembers.length}',
      );
      debugPrint(
        '[Manager][Leaderboard] leaderboard loaded stage="${widget.stage}" visible=${filtered.length}',
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surfaceSoft,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        title: const Text('Youth Points (Read Only)'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: AppColors.primary.withOpacity(0.08),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Text(
                  'Class: ${widget.stage}',
                  textDirection: TextDirection.ltr,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
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
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded),
                      hintText: 'Search by name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: provider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : provider.error != null
                    ? Center(
                        child: Text(
                          'Error: ${provider.error}',
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : filtered.isEmpty
                    ? const Center(
                        child: Text('No members found for this class.'),
                      )
                    : Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        child: ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final m = filtered[index];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.primary.withOpacity(
                                  0.1,
                                ),
                                child: Text('${index + 1}'),
                              ),
                              title: Text(m.name),
                              subtitle: Text(
                                'Class: ${m.stage}',
                                textDirection: TextDirection.ltr,
                              ),
                              trailing: Wrap(
                                spacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    '${m.totalPoints} pts',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: Colors.green,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'History',
                                    icon: const Icon(Icons.history_rounded),
                                    onPressed: () => _openHistory(context, m),
                                  ),
                                ],
                              ),
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
}
