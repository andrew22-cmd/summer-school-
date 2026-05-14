import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:summerschool/core/constants/app_colors.dart';
import 'package:summerschool/models/class_member_model.dart';
import 'package:summerschool/providers/auth_provider.dart';
import 'package:summerschool/providers/class_member_provider.dart';
import 'package:summerschool/providers/points_provider.dart';

enum PointsActionMode { add, remove }

class AddPointsScreen extends StatefulWidget {
  const AddPointsScreen({
    super.key,
    this.selectedStudent,
    this.initialMode = PointsActionMode.add,
  });

  final ClassMemberModel? selectedStudent;
  final PointsActionMode initialMode;

  @override
  State<AddPointsScreen> createState() => _AddPointsScreenState();
}

class _AddPointsScreenState extends State<AddPointsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pointsController = TextEditingController(text: '0');
  final _reasonController = TextEditingController();
  String? _selectedStudentId;

  @override
  void initState() {
    super.initState();
    _selectedStudentId = widget.selectedStudent?.id;
  }

  @override
  void dispose() {
    _pointsController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit(bool isAdd) async {
    debugPrint(
      '\n[AddPointsScreen._submit] ╔════════════════════════════════════════════════════════════════',
    );
    debugPrint(
      '[AddPointsScreen._submit] ║ USER PRESSED: ${isAdd ? 'ADD POINTS' : 'REMOVE POINTS'}',
    );

    if (!_formKey.currentState!.validate()) {
      debugPrint('[AddPointsScreen._submit] ║ ❌ Form validation FAILED');
      return;
    }

    final provider = context.read<ClassMemberProvider>();
    debugPrint('[PROVIDER FOUND] ClassMemberProvider found in AddPointsScreen');
    final auth = context.read<AuthProvider>();
    final student = provider.allMembers
        .where((s) => s.id == _selectedStudentId)
        .toList();
    if (student.isEmpty) {
      debugPrint('[AddPointsScreen._submit] ║ ❌ Student not found in provider');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a student.')));
      return;
    }

    final points = int.tryParse(_pointsController.text.trim()) ?? 0;
    final reason = _reasonController.text.trim();
    final createdBy = auth.user?.name.trim().isNotEmpty == true
        ? auth.user!.name.trim()
        : (auth.user?.id ?? 'local_admin');

    debugPrint(
      '[AddPointsScreen._submit] ║ Student: ${student.first.name} (${student.first.id})',
    );
    debugPrint('[AddPointsScreen._submit] ║ Points: $points');
    debugPrint('[AddPointsScreen._submit] ║ Reason: $reason');
    debugPrint('[AddPointsScreen._submit] ║ CreatedBy: $createdBy');
    debugPrint(
      '[AddPointsScreen._submit] ║ Old totalPoints: ${student.first.totalPoints}',
    );

    try {
      debugPrint(isAdd ? '[ADD POINTS]' : '[REMOVE POINTS]');
      debugPrint(
        '[AddPointsScreen._submit] ║ Calling provider.${isAdd ? 'addPoints' : 'removePoints'}()...',
      );
      if (isAdd) {
        await provider.addPoints(
          student: student.first,
          points: points,
          reason: reason,
          createdBy: createdBy,
        );
      } else {
        await provider.removePoints(
          student: student.first,
          points: points,
          reason: reason,
          createdBy: createdBy,
        );
      }

      debugPrint('[AddPointsScreen._submit] ║ ✓ Provider call succeeded');
      debugPrint(
        '[AddPointsScreen._submit] ║ ℹ Realtime streams will update automatically from Firestore',
      );

      if (!mounted) {
        debugPrint(
          '[AddPointsScreen._submit] ║ ⚠ Widget unmounted, skipping navigation',
        );
        return;
      }

      debugPrint('[AddPointsScreen._submit] ║ Popping screen...');
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isAdd
                ? 'Points added successfully.'
                : 'Points removed successfully.',
          ),
        ),
      );
      debugPrint(
        '[AddPointsScreen._submit] ╚════════════════════════════════════════════════════════════════\n',
      );
    } catch (e) {
      debugPrint('[AddPointsScreen._submit] ║ ❌ EXCEPTION: $e');
      debugPrint(
        '[AddPointsScreen._submit] ╚════════════════════════════════════════════════════════════════\n',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save points: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClassMemberProvider>();
    final pointsProvider = context.watch<PointsProvider>();
    debugPrint(
      '[PROVIDER FOUND] ClassMemberProvider found in AddPointsScreen.build()',
    );
    final students = provider.allMembers;
    final currentStudent = students
        .where((s) => s.id == _selectedStudentId)
        .toList();
    final defaultAddMode = widget.initialMode == PointsActionMode.add;

    // Show loading if provider hasn't loaded students yet
    if (provider.isLoading && students.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.primary,
          title: Text(defaultAddMode ? 'Add Points' : 'Remove Points'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Show error if data failed to load
    if (provider.error != null && students.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.primary,
          title: Text(defaultAddMode ? 'Add Points' : 'Remove Points'),
        ),
        body: Center(child: Text('Error loading students: ${provider.error}')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surfaceSoft,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        title: Text(defaultAddMode ? 'Add Points' : 'Remove Points'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'الطايوهات',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                        ),
                        const SizedBox(height: 18),
                        DropdownButtonFormField<String>(
                          value: _selectedStudentId,
                          decoration: const InputDecoration(
                            labelText: 'Student selector *',
                            border: OutlineInputBorder(),
                          ),
                          items: students
                              .map(
                                (s) => DropdownMenuItem<String>(
                                  value: s.id,
                                  child: Text('${s.name}  •  ${s.stage}'),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _selectedStudentId = value),
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        if (currentStudent.isNotEmpty)
                          Builder(
                            builder: (_) {
                              final liveTotal =
                                  pointsProvider.currentTotalForStudent(
                                    currentStudent.first.id,
                                  ) ??
                                  currentStudent.first.totalPoints;

                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  'Current total: $liveTotal طايو',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              );
                            },
                          ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _pointsController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Enter Number *',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            final n = int.tryParse((v ?? '').trim()) ?? 0;
                            if (n <= 0) return 'Enter a valid number';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _reasonController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Reason *',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: defaultAddMode
                                  ? FilledButton.icon(
                                      onPressed: () => _submit(true),
                                      icon: const Icon(
                                        Icons.add_circle_outline,
                                      ),
                                      label: const Text('ADD'),
                                    )
                                  : OutlinedButton.icon(
                                      onPressed: () => _submit(true),
                                      icon: const Icon(
                                        Icons.add_circle_outline,
                                      ),
                                      label: const Text('ADD'),
                                    ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: defaultAddMode
                                  ? FilledButton.tonalIcon(
                                      onPressed: () => _submit(false),
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                      ),
                                      label: const Text('REMOVE'),
                                    )
                                  : FilledButton.icon(
                                      onPressed: () => _submit(false),
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                      ),
                                      label: const Text('REMOVE'),
                                    ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Make sure points never go below zero.',
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
