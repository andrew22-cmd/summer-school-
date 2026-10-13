import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:summerschool/core/constants/app_colors.dart';
import 'package:summerschool/core/routes/app_routes.dart';
import 'package:summerschool/models/task_model.dart';
import 'package:summerschool/providers/auth_provider.dart';
import 'package:summerschool/providers/task_provider.dart';
import 'package:summerschool/screens/tasks/task_history_screen.dart';
import 'package:summerschool/screens/tasks/edit_task_screen.dart';
import 'package:summerschool/core/localization/app_localizations.dart';

class MyTasksScreen extends StatefulWidget {
  const MyTasksScreen({super.key});

  @override
  State<MyTasksScreen> createState() => _MyTasksScreenState();
}

class _MyTasksScreenState extends State<MyTasksScreen> {
  String? _startedForUserId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    if (auth.isLoading || user == null) return;
    if (!auth.isMember && !auth.isMemberManager) return;

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

    if (!auth.isMember && !auth.isMemberManager) {
      return Scaffold(
        appBar: AppBar(title: Text(context.tr('my_tasks'))),
        body: const Center(child: Text('This page is for members only.')),
      );
    }

    final taskProvider = context.watch<TaskProvider>();

    return Scaffold(
      backgroundColor: AppColors.surfaceSoft,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        title: Text(context.tr('my_tasks')),
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
            ? Center(child: Text(context.tr('no_tasks')))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: taskProvider.myTasks.length,
                itemBuilder: (context, index) {
                  final task = taskProvider.myTasks[index];
                  return _TaskCard(task: task);
                },
              ),
      ),
      floatingActionButton: auth.isMemberManager
          ? FloatingActionButton(
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.manageTasks);
              },
              backgroundColor: AppColors.primary,
              tooltip: context.tr('add_task'),
              child: const Icon(Icons.add_rounded, color: Colors.white),
            )
          : null,
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task});

  final TaskModel task;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isManager = auth.isManager;
    final isCompleted = task.isCompleted == true;
    final borderColor = isCompleted ? Colors.green : Colors.orange;

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
                  child: Text(
                    task.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
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
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle, size: 16, color: Colors.green),
                        SizedBox(width: 6),
                        Text(
                          context.tr('complete'),
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
            Text('${context.tr('assigned_by')}: ${task.assignedByName}'),
            Text('${context.tr('due_date')}: ${DateFormat('yyyy/MM/dd').format(task.dueDate)}'),
            Text(
              '${context.tr('created')}: ${DateFormat('yyyy/MM/dd HH:mm').format(task.createdAt)}',
            ),
            if (task.completedAt != null)
              Text(
                '${context.tr('completed_at')}: ${DateFormat('yyyy/MM/dd HH:mm').format(task.completedAt!)}',
              ),
            if (task.history.isNotEmpty && isManager)
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TaskHistoryScreen(task: task),
                          ),
                        );
                      },
                      icon: const Icon(Icons.history_rounded),
                      label: Text(context.tr('view_history')),
                    ),
                  ),
                  if (!isCompleted)
                    TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EditTaskScreen(task: task),
                          ),
                        );
                      },
                      icon: const Icon(Icons.edit_rounded),
                      label: Text(context.tr('edit')),
                    ),
                ],
              )
            else if (!isCompleted && isManager)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditTaskScreen(task: task),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit_rounded),
                  label: Text(context.tr('edit')),
                ),
              ),
            const SizedBox(height: 10),
            if (!isCompleted)
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      await context.read<TaskProvider>().completeTask(task.id);
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to complete task: $e')),
                      );
                    }
                  },
                  icon: const Icon(Icons.check_rounded),
                  label: Text(context.tr('mark_completed')),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
