import 'package:flutter/material.dart';
import 'package:summerschool/models/schedule_subject_model.dart';
import 'package:summerschool/services/schedule_subject_service.dart';

class ManageScheduleSubjectsScreen extends StatefulWidget {
  const ManageScheduleSubjectsScreen({super.key});

  @override
  State<ManageScheduleSubjectsScreen> createState() =>
      _ManageScheduleSubjectsScreenState();
}

class _ManageScheduleSubjectsScreenState
    extends State<ManageScheduleSubjectsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _englishController = TextEditingController();
  final _arabicController = TextEditingController();
  final _service = ScheduleSubjectService();
  bool _isSaving = false;

  @override
  void dispose() {
    _englishController.dispose();
    _arabicController.dispose();
    super.dispose();
  }

  Future<void> _saveSubject() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      await _service.addSubject(
        englishLabel: _englishController.text,
        arabicLabel: _arabicController.text,
      );
      if (!mounted) return;
      _englishController.clear();
      _arabicController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subject added successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteSubject(ScheduleSubjectOption subject) async {
    if (subject.isBuiltIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Default subjects cannot be removed.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete subject'),
        content: Text('Delete “${subject.value}” from the list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _service.deleteSubject(subject.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Subject removed.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to remove subject: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Subjects')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Form(
                key: _formKey,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Add Subject',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _englishController,
                          decoration: const InputDecoration(
                            labelText: 'English name',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if ((value ?? '').trim().isEmpty) {
                              return 'English name is required.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _arabicController,
                          decoration: const InputDecoration(
                            labelText: 'Arabic name',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if ((value ?? '').trim().isEmpty) {
                              return 'Arabic name is required.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _isSaving ? null : _saveSubject,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.add_rounded),
                          label: const Text('Add Subject'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: StreamBuilder<List<ScheduleSubjectOption>>(
                  stream: _service.watchSubjects(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final subjects =
                        snapshot.data ?? const <ScheduleSubjectOption>[];
                    if (subjects.isEmpty) {
                      return const Center(
                        child: Text('No subjects available.'),
                      );
                    }

                    return ListView.separated(
                      itemCount: subjects.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final subject = subjects[index];
                        return ListTile(
                          title: Text(subject.value),
                          subtitle: Text(subject.arabicLabel),
                          trailing: !subject.isBuiltIn
                              ? IconButton(
                                  onPressed: () => _deleteSubject(subject),
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                  ),
                                  color: Colors.red,
                                )
                              : const Icon(Icons.lock_outline_rounded),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
