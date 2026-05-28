import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:summerschool/models/weekly_schedule_item_model.dart';
import 'package:summerschool/providers/auth_provider.dart';
import 'package:summerschool/providers/weekly_schedule_provider.dart';
import 'package:summerschool/services/weekly_schedule_service.dart';

class AddWeeklyScheduleItemScreen extends StatefulWidget {
  const AddWeeklyScheduleItemScreen({
    super.key,
    required this.stage,
    this.item,
    this.initialDay,
  });

  final String stage;
  final WeeklyScheduleItemModel? item;
  final String? initialDay;

  @override
  State<AddWeeklyScheduleItemScreen> createState() =>
      _AddWeeklyScheduleItemScreenState();
}

class _AddWeeklyScheduleItemScreenState
    extends State<AddWeeklyScheduleItemScreen> {
  final _formKey = GlobalKey<FormState>();

  static const List<String> _subjects = [
    'Bible',
    'Development',
    'Talk About God',
    'Rites',
    'Stay Aware',
    'Discoveries',
    'Doctrine',
    'Coptic and Hymns',
    'Role Model',
    'First Aid',
    'Your Health',
    'Learn from Nature',
    'Other',
  ];

  late String _day;
  late String _subject;
  late final TextEditingController _customSubjectController;
  late final TextEditingController _servantNameController;
  late final TextEditingController _notesController;

  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _saving = false;

  bool get _isEdit => widget.item != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.item;
    _day = existing?.day ?? widget.initialDay ?? WeeklyScheduleDays.sunday;
    _subject = existing?.subject ?? _subjects.first;
    _customSubjectController = TextEditingController(
      text: existing?.customSubject ?? '',
    );
    _servantNameController = TextEditingController(
      text: existing?.servantName ?? '',
    );
    _notesController = TextEditingController(text: existing?.notes ?? '');

    if (existing != null) {
      _startTime = _minutesToTimeOfDay(existing.startTime);
      _endTime = _minutesToTimeOfDay(existing.endTime);
    }
  }

  @override
  void dispose() {
    _customSubjectController.dispose();
    _servantNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? const TimeOfDay(hour: 17, minute: 0),
    );
    if (picked == null) return;
    setState(() => _startTime = picked);
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime ?? const TimeOfDay(hour: 17, minute: 30),
    );
    if (picked == null) return;
    setState(() => _endTime = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startTime == null || _endTime == null) {
      _showError('Please select both start and end time.');
      return;
    }

    final startMinutes = _timeOfDayToMinutes(_startTime!);
    final endMinutes = _timeOfDayToMinutes(_endTime!);
    if (startMinutes >= endMinutes) {
      _showError('Invalid time range: end time must be after start time.');
      return;
    }

    final provider = context.read<WeeklyScheduleProvider>();
    final auth = context.read<AuthProvider>();
    final stageNorm = WeeklyScheduleService.normalizeStage(widget.stage);

    final item = WeeklyScheduleItemModel(
      id: widget.item?.id ?? provider.generateId(),
      stage: widget.stage,
      stageNorm: stageNorm,
      day: _day,
      subject: _subject,
      customSubject: _subject == 'Other'
          ? _customSubjectController.text.trim()
          : null,
      startTime: startMinutes,
      endTime: endMinutes,
      servantName: _servantNameController.text.trim().isEmpty
          ? null
          : _servantNameController.text.trim(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      createdAt: widget.item?.createdAt ?? DateTime.now(),
      createdBy: widget.item?.createdBy ?? (auth.user?.id ?? ''),
    );

    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await provider.updateItem(item);
      } else {
        await provider.addItem(item);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final existing = widget.item;
    if (existing == null) return;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete item'),
        content: const Text(
          'Are you sure you want to delete this schedule item?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    setState(() => _saving = true);
    try {
      await context.read<WeeklyScheduleProvider>().deleteItem(existing.id);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = true;
    return Directionality(
      textDirection: isRtl ? TextDirection.ltr : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEdit ? 'Edit Schedule Item' : 'Add Schedule Item'),
          actions: [
            if (_isEdit)
              IconButton(
                tooltip: 'Delete',
                onPressed: _saving ? null : _delete,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    value: _day,
                    decoration: const InputDecoration(labelText: 'Day'),
                    items: WeeklyScheduleDays.values
                        .map(
                          (d) => DropdownMenuItem(
                            value: d,
                            child: Text(WeeklyScheduleDays.arabicLabel(d)),
                          ),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (v) {
                            if (v == null) return;
                            setState(() => _day = v);
                          },
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: _subject,
                    decoration: const InputDecoration(labelText: 'Subject'),
                    items: _subjects
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (v) {
                            if (v == null) return;
                            setState(() => _subject = v);
                          },
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'Subject is required.';
                      }
                      return null;
                    },
                  ),
                  if (_subject == 'Other') ...[
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _customSubjectController,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: 'Enter custom subject',
                      ),
                      validator: (value) {
                        if (_subject != 'Other') return null;
                        if ((value ?? '').trim().isEmpty) {
                          return 'Please enter a custom subject.';
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _saving ? null : _pickStartTime,
                          icon: const Icon(Icons.access_time_rounded),
                          label: Text(
                            _startTime == null
                                ? 'Start Time'
                                : _formatTime(_startTime!),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _saving ? null : _pickEndTime,
                          icon: const Icon(Icons.access_time_filled_rounded),
                          label: Text(
                            _endTime == null
                                ? 'End Time'
                                : _formatTime(_endTime!),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _servantNameController,
                    enabled: !_saving,
                    decoration: const InputDecoration(
                      labelText: 'Servant Name (Optional)',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _notesController,
                    enabled: !_saving,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Notes (Optional)',
                    ),
                  ),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_rounded),
                    label: Text(_isEdit ? 'Save Changes' : 'Add'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static int _timeOfDayToMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

  static TimeOfDay _minutesToTimeOfDay(int minutes) =>
      TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);

  String _formatTime(TimeOfDay time) {
    final localizations = MaterialLocalizations.of(context);
    return localizations.formatTimeOfDay(time, alwaysUse24HourFormat: false);
  }
}
