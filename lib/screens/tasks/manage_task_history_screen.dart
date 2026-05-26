import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:summerschool/core/constants/app_colors.dart';
import 'package:summerschool/models/task_model.dart';
import 'package:summerschool/providers/auth_provider.dart';
import 'package:summerschool/providers/task_provider.dart';
import 'package:summerschool/screens/tasks/edit_task_screen.dart';
import 'package:summerschool/screens/tasks/task_history_screen.dart';

class ManageTaskHistoryScreen extends StatefulWidget {
  const ManageTaskHistoryScreen({super.key});

  @override
  State<ManageTaskHistoryScreen> createState() =>
      _ManageTaskHistoryScreenState();
}

class _ManageTaskHistoryScreenState extends State<ManageTaskHistoryScreen> {
  String? _startedForUserId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    if (auth.isLoading || user == null) return;
    if (!auth.isManager) return;

    if (_startedForUserId == user.id) return;
    _startedForUserId = user.id;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<TaskProvider>().startMyTasks(user.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    if (auth.isLoading || user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!auth.isManager) {
      return Scaffold(
        appBar: AppBar(title: const Text('Task History')),
        body: const Center(child: Text('This page is for managers only.')),
      );
    }

    final taskProvider = context.watch<TaskProvider>();

    return Scaffold(
      backgroundColor: AppColors.surfaceSoft,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        title: const Text('Task History & Management'),
        elevation: 1,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          context.read<TaskProvider>().startMyTasks(user.id);
        },
        child: taskProvider.isLoadingMyTasks
            ? const Center(child: CircularProgressIndicator())
            : taskProvider.myTasksError != null
            ? Center(child: Text('Error: ${taskProvider.myTasksError}'))
            : taskProvider.myTasks.isEmpty
            ? const Center(child: Text('No tasks created yet'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: taskProvider.myTasks.length,
                itemBuilder: (context, index) {
                  final task = taskProvider.myTasks[index];
                  return _ManagerTaskCard(task: task);
                },
              ),
      ),
    );
  }
}

class _ManagerTaskCard extends StatelessWidget {
  const _ManagerTaskCard({required this.task});

  final TaskModel task;

  @override
  Widget build(BuildContext context) {
    final isCompleted = task.isCompleted == true;
    final borderColor = isCompleted ? Colors.green : Colors.orange;
    final hasHistory = task.history.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Assigned to: ${task.assignedToName}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                if (isCompleted)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 16, color: Colors.green),
                        SizedBox(width: 6),
                        Text(
                          'Completed',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(task.description),
            const SizedBox(height: 10),
            Text('Due date: ${DateFormat('yyyy/MM/dd').format(task.dueDate)}'),
            Text(
              'Created: ${DateFormat('yyyy/MM/dd HH:mm').format(task.createdAt)}',
            ),
            if (task.completedAt != null)
              Text(
                'Completed at: ${DateFormat('yyyy/MM/dd HH:mm').format(task.completedAt!)}',
              ),
            if (hasHistory)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${task.history.length} change${task.history.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (hasHistory)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TaskHistoryScreen(task: task),
                          ),
                        );
                      },
                      icon: const Icon(Icons.history_rounded),
                      label: const Text('View History'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                if (hasHistory) const SizedBox(width: 8),
                if (!isCompleted)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EditTaskScreen(task: task),
                          ),
                        );
                      },
                      icon: const Icon(Icons.edit_rounded),
                      label: const Text('Edit'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
