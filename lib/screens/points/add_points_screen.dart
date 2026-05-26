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
  late PointsActionMode _selectedMode;
  String? _selectedAddReasonKey;

  static const List<_AddReasonOption> _addReasonOptions = [
    _AddReasonOption('monthly_meeting', 'حضور اللقاء الشهري', 50),
    _AddReasonOption('monthly_training', 'التدريب الشهري', 50),
    _AddReasonOption('spiritual_notebook', 'النوتة الروحية', 50),
    _AddReasonOption('memorization', 'الحفظ', null),
    _AddReasonOption('lent_competition', 'مسابقة الصوم الكبير', 100),
    _AddReasonOption('monthly_book', 'الكتاب الشهري', 100),
    _AddReasonOption(
      'events_attendance',
      'حضور المناسبات (كيهك / أسبوع الآلام)',
      50,
    ),
    _AddReasonOption('readings_prayer', 'تنزيل القراءات والصلاة', 20),
    _AddReasonOption('group_encouragement', 'التشجيع على الجروب', 10),
    _AddReasonOption('talents', 'المواهب', 10),
    _AddReasonOption('anti_doubt_video', 'فيديو حتى لا نتشكك', 20),
    _AddReasonOption(
      'participation_commitment',
      'المشاركة / الالتزام / التعاون / الطاعة',
      10,
    ),
    _AddReasonOption('gpo_competition', 'مسابقة جيم بي أو', null),
    _AddReasonOption('leader_of_day', 'قائد اليوم', 50),
    _AddReasonOption('other', 'Other', null),
  ];

  _AddReasonOption? get _selectedAddReason {
    final key = _selectedAddReasonKey;
    if (key == null) return null;
    for (final option in _addReasonOptions) {
      if (option.key == key) return option;
    }
    return null;
  }

  bool get _isOtherReasonSelected => _selectedAddReasonKey == 'other';

  @override
  void initState() {
    super.initState();
    _selectedStudentId = widget.selectedStudent?.id;
    _selectedMode = widget.initialMode;
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

    setState(() {
      _selectedMode = isAdd ? PointsActionMode.add : PointsActionMode.remove;
    });

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
    String reason = _reasonController.text.trim();

    if (isAdd) {
      final selectedReason = _selectedAddReason;
      if (selectedReason == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select add reason.')),
        );
        return;
      }

      if (!_isOtherReasonSelected) {
        reason = selectedReason.label;
        _reasonController.text = reason;
      } else {
        reason = _reasonController.text.trim();
      }
    }

    if (reason.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter reason.')));
      return;
    }
    final createdByUserId = auth.user?.id ?? 'local_admin';
    final createdByName = auth.user?.name.trim().isNotEmpty == true
        ? auth.user!.name.trim()
        : createdByUserId;

    debugPrint(
      '[AddPointsScreen._submit] ║ Student: ${student.first.name} (${student.first.id})',
    );
    debugPrint('[AddPointsScreen._submit] ║ Points: $points');
    debugPrint('[AddPointsScreen._submit] ║ Reason: $reason');
    debugPrint('[AddPointsScreen._submit] ║ CreatedByUserId: $createdByUserId');
    debugPrint('[AddPointsScreen._submit] ║ CreatedByName: $createdByName');
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
          createdByUserId: createdByUserId,
          createdByName: createdByName,
        );
      } else {
        await provider.removePoints(
          student: student.first,
          points: points,
          reason: reason,
          createdByUserId: createdByUserId,
          createdByName: createdByName,
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
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 50,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: students
                                  .map(
                                    (s) => Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: FilterChip(
                                        selected: _selectedStudentId == s.id,
                                        onSelected: (selected) {
                                          if (selected) {
                                            setState(
                                              () => _selectedStudentId = s.id,
                                            );
                                          }
                                        },
                                        label: Text(
                                          '${s.name}',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        selectedColor: AppColors.primary
                                            .withOpacity(0.7),
                                        backgroundColor: Colors.grey.shade200,
                                        labelStyle: TextStyle(
                                          color: _selectedStudentId == s.id
                                              ? Colors.white
                                              : Colors.black87,
                                          fontSize: 12,
                                        ),
                                        side: BorderSide(
                                          color: _selectedStudentId == s.id
                                              ? AppColors.primary
                                              : Colors.grey.shade300,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
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
                        SegmentedButton<PointsActionMode>(
                          segments: const [
                            ButtonSegment<PointsActionMode>(
                              value: PointsActionMode.add,
                              icon: Icon(Icons.add_circle_outline),
                              label: Text('Add Points'),
                            ),
                            ButtonSegment<PointsActionMode>(
                              value: PointsActionMode.remove,
                              icon: Icon(Icons.remove_circle_outline),
                              label: Text('Remove Points'),
                            ),
                          ],
                          selected: {_selectedMode},
                          onSelectionChanged: (value) {
                            if (value.isEmpty) return;
                            setState(() => _selectedMode = value.first);
                          },
                        ),
                        const SizedBox(height: 12),
                        if (_selectedMode == PointsActionMode.add)
                          DropdownMenu<String>(
                            width: double.infinity,
                            enableFilter: true,
                            requestFocusOnTap: true,
                            label: const Text('Select add reason *'),
                            initialSelection: _selectedAddReasonKey,
                            dropdownMenuEntries: _addReasonOptions
                                .map(
                                  (option) => DropdownMenuEntry<String>(
                                    value: option.key,
                                    label: option.points == null
                                        ? option.label
                                        : '${option.label} — ${option.points}',
                                  ),
                                )
                                .toList(),
                            onSelected: (value) {
                              if (value == null) return;
                              setState(() => _selectedAddReasonKey = value);
                              final selected = _selectedAddReason;
                              if (selected == null) return;
                              if (selected.points != null) {
                                _pointsController.text = selected.points!
                                    .toString();
                              }
                              if (selected.key != 'other') {
                                _reasonController.text = selected.label;
                              } else {
                                _reasonController.clear();
                              }
                            },
                          ),
                        if (_selectedMode == PointsActionMode.add)
                          const SizedBox(height: 12),
                        TextFormField(
                          controller: _pointsController,
                          keyboardType: TextInputType.number,
                          enabled:
                              _selectedMode == PointsActionMode.remove ||
                              _selectedAddReason?.points == null ||
                              _isOtherReasonSelected,
                          decoration: InputDecoration(
                            labelText: 'Enter Number *',
                            border: const OutlineInputBorder(),
                            filled:
                                _selectedMode == PointsActionMode.add &&
                                _selectedAddReason?.points != null &&
                                !_isOtherReasonSelected,
                            fillColor:
                                _selectedMode == PointsActionMode.add &&
                                    _selectedAddReason?.points != null &&
                                    !_isOtherReasonSelected
                                ? Colors.grey.shade200
                                : null,
                          ),
                          validator: (v) {
                            final n = int.tryParse((v ?? '').trim()) ?? 0;
                            if (n <= 0) return 'Enter a valid number';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        if (_selectedMode == PointsActionMode.remove ||
                            _isOtherReasonSelected)
                          TextFormField(
                            controller: _reasonController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText:
                                  _selectedMode == PointsActionMode.remove
                                  ? 'Reason *'
                                  : 'Custom reason *',
                              border: const OutlineInputBorder(),
                            ),
                            validator: (v) {
                              final required =
                                  _selectedMode == PointsActionMode.remove ||
                                  _isOtherReasonSelected;
                              if (!required) return null;
                              return v == null || v.trim().isEmpty
                                  ? 'Required'
                                  : null;
                            },
                          ),
                        if (_selectedMode == PointsActionMode.add &&
                            !_isOtherReasonSelected)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              'Reason: ${_selectedAddReason?.label ?? '-'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        const SizedBox(height: 18),
                        if (_selectedMode == PointsActionMode.add)
                          FilledButton.icon(
                            onPressed: () => _submit(true),
                            icon: const Icon(Icons.add_circle_outline),
                            label: const Text('ADD'),
                          )
                        else
                          FilledButton.icon(
                            onPressed: () => _submit(false),
                            icon: const Icon(Icons.remove_circle_outline),
                            label: const Text('REMOVE'),
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

class _AddReasonOption {
  const _AddReasonOption(this.key, this.label, this.points);

  final String key;
  final String label;
  final int? points;
}
