import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:summerschool/core/constants/app_colors.dart';
import 'package:summerschool/models/class_member_model.dart';
import 'package:summerschool/providers/class_member_provider.dart';
import 'package:summerschool/services/class_member_service.dart';

class AdminClassMembersScreen extends StatelessWidget {
  const AdminClassMembersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ClassMemberProvider>(
      create: (_) =>
          ClassMemberProvider(service: ClassMemberService())
            ..startListeningAllMembers(),
      child: const _AdminClassMembersView(),
    );
  }
}

class _AdminClassMembersView extends StatefulWidget {
  const _AdminClassMembersView();

  @override
  State<_AdminClassMembersView> createState() => _AdminClassMembersViewState();
}

class _AdminClassMembersViewState extends State<_AdminClassMembersView> {
  final TextEditingController _searchController = TextEditingController();
  // Use spaced format to match existing user.stage values (e.g. '1 M', '2 S')
  static const List<String> _stageOptions = [
    '1 S',
    '1 M',
    '2 S',
    '2 M',
    '3 S',
    '3 M',
    '4 S',
    '4 M',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showStudentForm({ClassMemberModel? member}) async {
    final provider = context.read<ClassMemberProvider>();
    final isEdit = member != null;

    final nameController = TextEditingController(text: member?.name ?? '');
    final yearController = TextEditingController(text: member?.year ?? '');
    final phoneController = TextEditingController(text: member?.phone ?? '');
    final parentPhoneController = TextEditingController(
      text: member?.parentPhone ?? '',
    );
    final confessionController = TextEditingController(
      text: member?.confessionFather ?? '',
    );
    final pointsController = TextEditingController(
      text: member?.totalPoints.toString() ?? '0',
    );
    final existingStage = (member?.stage ?? '').trim();
    final stageOptions = [
      ..._stageOptions,
      if (existingStage.isNotEmpty && !_stageOptions.contains(existingStage))
        existingStage,
    ];
    String? selectedStage = existingStage.isEmpty ? null : existingStage;
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEdit ? 'Edit Student' : 'Add Student'),
              content: SizedBox(
                width: 420,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Name *',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: selectedStage,
                          decoration: const InputDecoration(
                            labelText: 'Stage *',
                            border: OutlineInputBorder(),
                          ),
                          items: stageOptions
                              .map(
                                (s) => DropdownMenuItem<String>(
                                  value: s,
                                  child: Text(s),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setDialogState(() => selectedStage = value);
                          },
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: yearController,
                          decoration: const InputDecoration(
                            labelText: 'Year',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Phone',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: parentPhoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Parent Phone',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: confessionController,
                          decoration: const InputDecoration(
                            labelText: 'Confession Father',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: pointsController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Total Points',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;

                    final data = ClassMemberModel(
                      id: member?.id ?? '',
                      name: nameController.text.trim(),
                      stage: (selectedStage ?? '').trim(),
                      year: yearController.text.trim(),
                      phone: phoneController.text.trim(),
                      parentPhone: parentPhoneController.text.trim(),
                      confessionFather: confessionController.text.trim(),
                      totalPoints:
                          int.tryParse(pointsController.text.trim()) ?? 0,
                      createdAt: member?.createdAt ?? DateTime.now(),
                      createdBy: member?.createdBy ?? 'local_admin',
                    );

                    try {
                      if (isEdit) {
                        await provider.updateMember(data.id, data.toMap());
                      } else {
                        await provider.addMember(data);
                      }
                      if (!context.mounted) return;
                      Navigator.pop(context, true);
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Save failed: $e')),
                      );
                    }
                  },
                  child: Text(isEdit ? 'Save Changes' : 'Add Student'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    yearController.dispose();
    phoneController.dispose();
    parentPhoneController.dispose();
    confessionController.dispose();
    pointsController.dispose();

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isEdit ? 'Student updated.' : 'Student added.')),
      );
    }
  }

  Future<void> _confirmDelete(ClassMemberModel member) async {
    final provider = context.read<ClassMemberProvider>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Student'),
        content: Text('Are you sure you want to delete ${member.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await provider.deleteMember(member.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Student deleted.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClassMemberProvider>();
    final members = provider.members;
    final stages = {..._stageOptions, ...provider.availableStages}.toList()
      ..sort();

    return Scaffold(
      backgroundColor: AppColors.surfaceSoft,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        title: const Text('Class Students'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: provider.setSearch,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded),
                      hintText: 'Search by student name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String>(
                    value: provider.stageFilter.isEmpty
                        ? null
                        : provider.stageFilter,
                    decoration: InputDecoration(
                      labelText: 'Stage Filter',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: '',
                        child: Text('All Stages'),
                      ),
                      ...stages.map(
                        (s) =>
                            DropdownMenuItem<String>(value: s, child: Text(s)),
                      ),
                    ],
                    onChanged: (value) {
                      provider.setStageFilter((value ?? '').trim());
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: provider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : members.isEmpty
                  ? _EmptyState(onAdd: _showStudentForm)
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth >= 980) {
                          return _StudentsTable(
                            students: members,
                            onEdit: (m) => _showStudentForm(member: m),
                            onDelete: _confirmDelete,
                          );
                        }
                        return ListView.separated(
                          itemCount: members.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final m = members[index];
                            return Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(color: Colors.grey.shade300),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                title: Text(
                                  m.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 6),
                                    Text('Stage: ${m.stage} | Year: ${m.year}'),
                                    Text('Phone: ${m.phone}'),
                                    Text('Parent: ${m.parentPhone}'),
                                    Text('Confession: ${m.confessionFather}'),
                                    Text('Points: ${m.totalPoints}'),
                                  ],
                                ),
                                trailing: Wrap(
                                  spacing: 6,
                                  children: [
                                    IconButton(
                                      onPressed: () =>
                                          _showStudentForm(member: m),
                                      icon: const Icon(Icons.edit_rounded),
                                      tooltip: 'Edit',
                                    ),
                                    IconButton(
                                      onPressed: () => _confirmDelete(m),
                                      icon: const Icon(Icons.delete_rounded),
                                      color: AppColors.danger,
                                      tooltip: 'Delete',
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentsTable extends StatelessWidget {
  const _StudentsTable({
    required this.students,
    required this.onEdit,
    required this.onDelete,
  });

  final List<ClassMemberModel> students;
  final ValueChanged<ClassMemberModel> onEdit;
  final ValueChanged<ClassMemberModel> onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(
            AppColors.primary.withOpacity(0.08),
          ),
          columns: const [
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Stage')),
            DataColumn(label: Text('Year')),
            DataColumn(label: Text('Phone')),
            DataColumn(label: Text('Parent Phone')),
            DataColumn(label: Text('Confession Father')),
            DataColumn(label: Text('Points')),
            DataColumn(label: Text('Actions')),
          ],
          rows: students
              .map(
                (m) => DataRow(
                  cells: [
                    DataCell(Text(m.name)),
                    DataCell(Text(m.stage)),
                    DataCell(Text(m.year)),
                    DataCell(Text(m.phone)),
                    DataCell(Text(m.parentPhone)),
                    DataCell(Text(m.confessionFather)),
                    DataCell(Text(m.totalPoints.toString())),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () => onEdit(m),
                            icon: const Icon(Icons.edit_rounded),
                            tooltip: 'Edit',
                          ),
                          IconButton(
                            onPressed: () => onDelete(m),
                            icon: const Icon(Icons.delete_rounded),
                            color: AppColors.danger,
                            tooltip: 'Delete',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

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
                  Icons.school_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'No students found',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              const Text('Add students to start managing classroom records.'),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Student'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
