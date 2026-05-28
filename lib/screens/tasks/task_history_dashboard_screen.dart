import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:summerschool/constants/user_roles.dart';
import 'package:summerschool/models/task_model.dart';
import 'package:summerschool/providers/auth_provider.dart';
import 'package:summerschool/providers/task_provider.dart';
import 'package:summerschool/screens/tasks/edit_task_screen.dart';
import 'package:summerschool/screens/tasks/task_history_screen.dart';

class TaskHistoryDashboardScreen extends StatefulWidget {
  const TaskHistoryDashboardScreen({Key? key}) : super(key: key);

  @override
  State<TaskHistoryDashboardScreen> createState() =>
      _TaskHistoryDashboardScreenState();
}

class _TaskHistoryDashboardScreenState
    extends State<TaskHistoryDashboardScreen> {
  late TextEditingController _searchController;
  String _selectedStatus = '';
  String _selectedStage = '';
  String _selectedRole = '';

  final List<String> _statuses = [
    'pending',
    'in_progress',
    'completed',
    'overdue',
  ];

  final List<String> _stages = ['Stage One', 'Stage Two', 'Stage Three'];
  final List<String> _roles = [
    UserRole.member.value,
    UserRole.memberManager.value,
  ];

  void _refreshTasks() {
    final authProvider = context.read<AuthProvider>();
    final currentUser = authProvider.user;
    if (currentUser == null) return;

    context.read<TaskProvider>().startAllTasks(
      currentUser,
      searchQuery: _searchController.text.trim().isEmpty
          ? null
          : _searchController.text.trim(),
      statusFilter: _selectedStatus.isEmpty ? null : _selectedStatus,
      stageFilter: _selectedStage.isEmpty ? null : _selectedStage,
      roleFilter: _selectedRole.isEmpty ? null : _selectedRole,
    );
  }

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshTasks();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getStatusArabic(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'overdue':
        return 'Overdue';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'in_progress':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'overdue':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _onSearchChanged(String query) {
    _refreshTasks();
  }

  void _onStatusFilterChanged(String? value) {
    setState(() {
      _selectedStatus = value ?? '';
    });
    _refreshTasks();
  }

  void _onStageFilterChanged(String? value) {
    setState(() {
      _selectedStage = value ?? '';
    });
    _refreshTasks();
  }

  void _onRoleFilterChanged(String? value) {
    setState(() {
      _selectedRole = value ?? '';
    });
    _refreshTasks();
  }

  Future<void> _showDeleteConfirmation(TaskModel task, BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Are you sure you want to delete task: ${task.title}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final authProvider = context.read<AuthProvider>();
              final currentUser = authProvider.user;
              final taskProvider = context.read<TaskProvider>();

              try {
                if (currentUser != null) {
                  await taskProvider.deleteTask(
                    taskId: task.id,
                    currentUser: currentUser,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Task deleted successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _showStatusChangeDialog(TaskModel task) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Task Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _statuses
              .map(
                (status) => RadioListTile<String>(
                  title: Text(_getStatusArabic(status)),
                  value: status,
                  groupValue: task.status,
                  onChanged: (value) async {
                    if (value != null) {
                      Navigator.pop(context);
                      final authProvider = context.read<AuthProvider>();
                      final currentUser = authProvider.user;
                      final taskProvider = context.read<TaskProvider>();

                      try {
                        if (currentUser != null) {
                          await taskProvider.updateTaskStatus(
                            taskId: task.id,
                            newStatus: value,
                            updatedBy: currentUser,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Status updated to ${_getStatusArabic(value)}',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    }
                  },
                ),
              )
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final currentUser = authProvider.user;
    final taskProvider = context.watch<TaskProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Tracking Dashboard'),
        centerTitle: true,
        backgroundColor: const Color(0xFF0D3B66),
        foregroundColor: Colors.white,
      ),
      body: currentUser == null
          ? const Center(child: Text('Please sign in'))
          : Column(
              children: [
                // Search Bar
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search tasks or users',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                // Filters
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SizedBox(
                        width: 220,
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Status',
                            border: OutlineInputBorder(),
                          ),
                          value: _selectedStatus.isEmpty
                              ? null
                              : _selectedStatus,
                          onChanged: _onStatusFilterChanged,
                          items: [
                            const DropdownMenuItem(
                              value: '',
                              child: Text('All Statuses'),
                            ),
                            ..._statuses.map(
                              (status) => DropdownMenuItem(
                                value: status,
                                child: Text(_getStatusArabic(status)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 220,
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Stage',
                            border: OutlineInputBorder(),
                          ),
                          value: _selectedStage.isEmpty ? null : _selectedStage,
                          onChanged: _onStageFilterChanged,
                          items: [
                            const DropdownMenuItem(
                              value: '',
                              child: Text('All Stages'),
                            ),
                            ..._stages.map(
                              (stage) => DropdownMenuItem(
                                value: stage,
                                child: Text(stage),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 220,
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Role',
                            border: OutlineInputBorder(),
                          ),
                          value: _selectedRole.isEmpty ? null : _selectedRole,
                          onChanged: _onRoleFilterChanged,
                          items: [
                            const DropdownMenuItem(
                              value: '',
                              child: Text('All Roles'),
                            ),
                            ..._roles.map(
                              (role) => DropdownMenuItem(
                                value: role,
                                child: Text(role),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_selectedStatus.isNotEmpty ||
                          _selectedStage.isNotEmpty ||
                          _selectedRole.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.filter_alt_off),
                          tooltip: 'Reset Filters',
                          onPressed: () {
                            setState(() {
                              _selectedStatus = '';
                              _selectedStage = '';
                              _selectedRole = '';
                            });
                            _refreshTasks();
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Tasks List
                Expanded(
                  child: taskProvider.isLoadingAllTasks
                      ? const Center(child: CircularProgressIndicator())
                      : taskProvider.allTasksError != null
                      ? Center(
                          child: Text('Error: ${taskProvider.allTasksError}'),
                        )
                      : taskProvider.allTasks.isEmpty
                      ? const Center(child: Text('No tasks found'))
                      : ListView.builder(
                          itemCount: taskProvider.allTasks.length,
                          itemBuilder: (context, index) {
                            final task = taskProvider.allTasks[index];
                            final canEdit =
                                currentUser.role == UserRole.manager ||
                                (currentUser.role == UserRole.memberManager &&
                                    task.assignedByUserId == currentUser.id);
                            final canDelete =
                                currentUser.role == UserRole.manager ||
                                (currentUser.role == UserRole.memberManager &&
                                    task.assignedByUserId == currentUser.id);

                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Title and Status Badge
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              task.title,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _getStatusColor(
                                                task.status,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              _getStatusArabic(task.status),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      // Assigned to
                                      Text(
                                        'Assigned to: ${task.assignedToName}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      // Created by
                                      Text(
                                        'Created by: ${task.assignedByName}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      // Due Date
                                      Text(
                                        'Due date: ${task.dueDate.toString().split(' ')[0]}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      // Last edited info
                                      if (task.lastEditedAt != null)
                                        Text(
                                          'Last edited: ${task.lastEditedBy} - ${task.lastEditedAt.toString().split(' ')[0]}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      const SizedBox(height: 12),
                                      // Action Buttons
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          if (canDelete)
                                            TextButton.icon(
                                              onPressed: () =>
                                                  _showDeleteConfirmation(
                                                    task,
                                                    context,
                                                  ),
                                              icon: const Icon(
                                                Icons.delete,
                                                color: Colors.red,
                                              ),
                                              label: const Text(
                                                'Delete',
                                                style: TextStyle(
                                                  color: Colors.red,
                                                ),
                                              ),
                                            ),
                                          if (canEdit) ...[
                                            TextButton.icon(
                                              onPressed: () =>
                                                  _showStatusChangeDialog(task),
                                              icon: const Icon(
                                                Icons.change_circle_outlined,
                                                color: Color(0xFF0D3B66),
                                              ),
                                              label: const Text(
                                                'Change Status',
                                                style: TextStyle(
                                                  color: Color(0xFF0D3B66),
                                                ),
                                              ),
                                            ),
                                            TextButton.icon(
                                              onPressed: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        EditTaskScreen(
                                                          task: task,
                                                        ),
                                                  ),
                                                );
                                              },
                                              icon: const Icon(
                                                Icons.edit,
                                                color: Color(0xFF0D3B66),
                                              ),
                                              label: const Text(
                                                'Edit',
                                                style: TextStyle(
                                                  color: Color(0xFF0D3B66),
                                                ),
                                              ),
                                            ),
                                            TextButton.icon(
                                              onPressed: () async {
                                                if (context.mounted) {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) =>
                                                          TaskHistoryScreen(
                                                            task: task,
                                                          ),
                                                    ),
                                                  );
                                                }
                                              },
                                              icon: const Icon(
                                                Icons.history,
                                                color: Color(0xFF0D3B66),
                                              ),
                                              label: const Text(
                                                'History',
                                                style: TextStyle(
                                                  color: Color(0xFF0D3B66),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
