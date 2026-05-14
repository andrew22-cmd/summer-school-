import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:summerschool/core/constants/app_colors.dart';
import 'package:summerschool/models/class_member_model.dart';
import 'package:summerschool/models/points_history_model.dart';
import 'package:summerschool/providers/auth_provider.dart';
import 'package:summerschool/providers/points_provider.dart';

class PointsHistoryScreen extends StatefulWidget {
  const PointsHistoryScreen({super.key, this.student});

  final ClassMemberModel? student;

  @override
  State<PointsHistoryScreen> createState() => _PointsHistoryScreenState();
}

class _PointsHistoryScreenState extends State<PointsHistoryScreen> {
  String? _startedStage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    debugPrint('[PointsHistoryScreen] didChangeDependencies()');
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[PointsHistoryScreen] build()');
    final auth = context.watch<AuthProvider>();
    final provider = context.watch<PointsProvider>();
    final history = provider.history;

    final stage = auth.user?.stage ?? '';
    final stageNorm = stage.replaceAll(' ', '').toLowerCase();

    if (!auth.isLoading && auth.user != null && stageNorm.isNotEmpty) {
      if (_startedStage != stage) {
        _startedStage = stage;
        debugPrint(
          '[PointsHistoryScreen] Scheduling history stream start for stage="$stage" stage_norm="$stageNorm" studentId=${widget.student?.id ?? 'ALL'}',
        );
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          final latestAuth = context.read<AuthProvider>();
          final latestStage = latestAuth.user?.stage ?? '';
          if (latestStage.trim().isEmpty) {
            debugPrint(
              '[PointsHistoryScreen] stage became empty before stream start; skipping.',
            );
            return;
          }

          final pointsProvider = context.read<PointsProvider>();
          try {
            await pointsProvider.cleanupOldHistory();
          } catch (e) {
            debugPrint(
              '[PointsHistoryScreen] cleanupOldHistory best-effort error: $e',
            );
          }

          debugPrint(
            '[PointsHistoryScreen] Starting realtime history stream for stage="$latestStage" studentId=${widget.student?.id ?? 'ALL'}',
          );
          await pointsProvider.startListeningHistory(
            latestStage,
            studentId: widget.student?.id,
          );
        });
      }
    } else {
      debugPrint(
        '[PointsHistoryScreen] Waiting for auth/stage. isLoading=${auth.isLoading} user=${auth.user == null ? 'null' : 'ready'} stage="$stage"',
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surfaceSoft,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        title: Text(
          widget.student == null
              ? 'Points History'
              : '${widget.student!.name} History',
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: provider.error != null
              ? Center(
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(color: Colors.red.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 44,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'History stream error',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text(provider.error ?? 'Unknown error'),
                        ],
                      ),
                    ),
                  ),
                )
              : provider.isLoadingHistory
              ? const Center(child: CircularProgressIndicator())
              : history.isEmpty
              ? Center(
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.history_rounded,
                            size: 44,
                            color: AppColors.primary,
                          ),
                          SizedBox(height: 10),
                          Text(
                            'No history yet',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          SizedBox(height: 4),
                          Text('Points changes will appear here.'),
                        ],
                      ),
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: history.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = history[index];
                    return _HistoryCard(item: item, formatDate: _formatDate);
                  },
                ),
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.item, required this.formatDate});

  final PointsHistoryModel item;
  final String Function(DateTime) formatDate;

  @override
  Widget build(BuildContext context) {
    final isAdd = item.operationType.toLowerCase() == 'add';
    final color = isAdd ? Colors.green : Colors.red;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.12),
          child: Icon(
            isAdd ? Icons.add_rounded : Icons.remove_rounded,
            color: color,
          ),
        ),
        title: Text(
          item.studentName,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${isAdd ? 'Added' : 'Removed'} ${item.points} طايو'),
              Text('Reason: ${item.reason}'),
              Text('At: ${formatDate(item.createdAt)}'),
              Text('By: ${item.createdBy}'),
            ],
          ),
        ),
        trailing: Chip(
          label: Text(isAdd ? 'ADD' : 'REMOVE'),
          backgroundColor: color.withOpacity(0.12),
          labelStyle: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
