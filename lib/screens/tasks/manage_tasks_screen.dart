import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:summerschool/constants/user_roles.dart';
import 'package:summerschool/core/constants/app_colors.dart';
import 'package:summerschool/models/user_model.dart';
import 'package:summerschool/providers/auth_provider.dart';
import 'package:summerschool/providers/task_provider.dart';
import 'package:summerschool/screens/tasks/edit_task_screen.dart';

class ManageTasksScreen extends StatefulWidget {
  const ManageTasksScreen({super.key});

  @override
  State<ManageTasksScreen> createState() => _ManageTasksScreenState();
}

class _ManageTasksScreenState extends State<ManageTasksScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _dueDate;
  UserModel? _selectedAssignee;
  String? _startedForUserId;
  bool _tasksInitialized = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    if (auth.isLoading || user == null) return;

    final canAssign = auth.isManager || auth.isMemberManager;
    if (!canAssign) return;

    if (_startedForUserId == user.id) return;
    _startedForUserId = user.id;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<TaskProvider>().startAllowedAssignees(user);
      // Always start watching created tasks
      if (!_tasksInitialized) {
        context.read<TaskProvider>().startMyCreatedTasks(user.id);
        _tasksInitialized = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final currentUser = auth.user;

    if (auth.isLoading || currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!auth.isManager && !auth.isMemberManager) {
      return Scaffold(
        appBar: AppBar(title: const Text('Add Tasks')),
        body: const Center(child: Text('You are not allowed to assign tasks.')),
      );
    }

    final taskProvider = context.watch<TaskProvider>();

    return Scaffold(
      backgroundColor: AppColors.surfaceSoft,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        title: const Text('Add Tasks'),
      ),
      body: SafeArea(
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              TabBar(
                labelColor: AppColors.primary,
                unselectedLabelColor: Colors.grey,
                indicatorColor: AppColors.primary,
                tabs: const [
                  Tab(text: 'Create Task'),
                  Tab(text: 'Task History'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    // Create Task Tab
                    _buildCreateTaskTab(currentUser, taskProvider),
                    // Task History Tab
                    _buildTaskHistoryTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreateTaskTab(UserModel currentUser, TaskProvider taskProvider) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Create Task',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _AssigneePickerField(
                      selected: _selectedAssignee,
                      isLoading: taskProvider.isLoadingAssignees,
                      assigneesError: taskProvider.assigneesError,
                      onPressed: () async {
                        final picked = await _openAssigneePicker(taskProvider);
                        if (picked != null) {
                          setState(() => _selectedAssignee = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Task title',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _descriptionController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Task details',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _pickDueDate,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month_rounded),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _dueDate == null
                                    ? 'Select due date'
                                    : 'Due: ${DateFormat('yyyy/MM/dd').format(_dueDate!)}',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: taskProvider.isCreatingTask
                            ? null
                            : () => _createTask(currentUser),
                        icon: taskProvider.isCreatingTask
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send_rounded),
                        label: const Text('Send Task'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskHistoryTab() {
    final auth = context.watch<AuthProvider>();
    final currentUser = auth.user;

    if (currentUser == null) {
      return const Center(child: Text('Please login'));
    }

    final taskProvider = context.watch<TaskProvider>();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Task History',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (taskProvider.isLoadingMyCreatedTasks)
                      const Center(child: CircularProgressIndicator())
                    else if (taskProvider.myCreatedTasks.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text('No tasks yet'),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: taskProvider.myCreatedTasks.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final task = taskProvider.myCreatedTasks[index];
                          return ListTile(
                            title: Text(task.title),
                            subtitle: Text(
                              'Assigned to: ${task.assignedToName} • Due: ${DateFormat('yyyy/MM/dd').format(task.dueDate)}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  tooltip: 'Edit Task',
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            EditTaskScreen(task: task),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      locale: const Locale('en'),
    );
    if (picked == null || !mounted) return;
    setState(() => _dueDate = picked);
  }

  Future<void> _createTask(UserModel currentUser) async {
    final selected = _selectedAssignee;
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();

    if (selected == null) {
      _showMessage('Please select a servant.');
      return;
    }
    if (title.isEmpty) {
      _showMessage('Please enter task title.');
      return;
    }
    if (description.isEmpty) {
      _showMessage('Please enter task details.');
      return;
    }
    if (_dueDate == null) {
      _showMessage('Please choose due date.');
      return;
    }

    try {
      await context.read<TaskProvider>().createTask(
        assignedBy: currentUser,
        assignedTo: selected,
        title: title,
        description: description,
        dueDate: _dueDate!,
      );

      if (!mounted) return;
      _titleController.clear();
      _descriptionController.clear();
      setState(() {
        _selectedAssignee = null;
        _dueDate = null;
      });

      _showMessage('Task sent successfully.', success: true);
    } catch (e) {
      if (!mounted) return;
      _showMessage('Failed to send task: $e');
    }
  }

  Future<UserModel?> _openAssigneePicker(TaskProvider provider) async {
    return showDialog<UserModel>(
      context: context,
      builder: (context) {
        String query = '';

        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = provider.searchAllowedAssignees(query);

            return AlertDialog(
              title: const Text('Select servant'),
              content: SizedBox(
                width: 500,
                height: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      onChanged: (value) => setModalState(() => query = value),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search by servant name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: filtered.isEmpty
                          ? const Center(child: Text('No servants found.'))
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final u = filtered[index];
                                return ListTile(
                                  title: Text(u.name),
                                  subtitle: Text(
                                    '${u.role.value} • ${u.stage}',
                                  ),
                                  onTap: () => Navigator.pop(context, u),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showMessage(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? Colors.green : null,
      ),
    );
  }
}

class _AssigneePickerField extends StatelessWidget {
  const _AssigneePickerField({
    required this.selected,
    required this.isLoading,
    required this.assigneesError,
    required this.onPressed,
  });

  final UserModel? selected;
  final bool isLoading;
  final String? assigneesError;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isLoading ? null : onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.person_search_rounded),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                selected == null
                    ? (isLoading
                          ? 'Loading servants...'
                          : (assigneesError == null
                                ? 'Select assigned servant'
                                : 'Error loading servants'))
                    : '${selected!.name} (${selected!.role.value})',
              ),
            ),
            const Icon(Icons.arrow_drop_down_rounded),
          ],
        ),
      ),
    );
  }
}
