import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:summerschool/models/schedule_subject_model.dart';
import 'package:summerschool/models/weekly_schedule_item_model.dart';
import 'package:summerschool/providers/auth_provider.dart';
import 'package:summerschool/providers/weekly_schedule_provider.dart';
import 'package:summerschool/services/schedule_subject_service.dart';
import 'package:summerschool/services/weekly_schedule_service.dart';
import 'package:summerschool/core/localization/app_localizations.dart';

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
  final _scheduleSubjectService = ScheduleSubjectService();
  List<ScheduleSubjectOption> _subjects = const [];

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
    _subject = existing?.subject ?? 'Bible';
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

    _loadSubjects();
  }

  @override
  void dispose() {
    _customSubjectController.dispose();
    _servantNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadSubjects() async {
    try {
      await _scheduleSubjectService.ensureDefaults();
      final subjects = await _scheduleSubjectService.getSubjects();
      if (!mounted) return;
      setState(() {
        _subjects = subjects;
        if (_subjects.isNotEmpty &&
            (_subject.isEmpty ||
                !_subjects.any((subject) => subject.value == _subject))) {
          _subject = _subjects.first.value;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _subjects = ScheduleSubjectService.defaultSubjects.toList();
        if (_subject.isEmpty ||
            !_subjects.any((subject) => subject.value == _subject)) {
          _subject = _subjects.first.value;
        }
      });
    }
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
      _showError(context.tr('both_times_required'));
      return;
    }

    final startMinutes = _timeOfDayToMinutes(_startTime!);
    final endMinutes = _timeOfDayToMinutes(_endTime!);
    if (startMinutes >= endMinutes) {
      _showError(context.tr('invalid_time_range'));
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
        title: Text(context.tr('delete_item_title')),
        content: Text(context.tr('delete_item_content')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(context.tr('delete')),
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

  String _localizedSubject(String value) {
    final option = _subjects.firstWhere(
      (subject) => subject.value == value,
      orElse: () => ScheduleSubjectOption(
        id: value,
        value: value,
        arabicLabel: value,
        sortOrder: 0,
      ),
    );

    final locale = Localizations.localeOf(context).languageCode;
    return locale == 'ar' && option.arabicLabel.isNotEmpty
        ? option.arabicLabel
        : option.value;
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = true;
    return Directionality(
      textDirection: isRtl ? TextDirection.ltr : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _isEdit
                ? context.tr('edit_schedule_item')
                : context.tr('add_schedule_item'),
          ),
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
                    decoration: InputDecoration(labelText: context.tr('day')),
                    items: WeeklyScheduleDays.values
                        .map(
                          (d) => DropdownMenuItem(
                            value: d,
                            child: Text(
                              context.tr(WeeklyScheduleDays.arabicLabel(d)),
                            ),
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
                    decoration: InputDecoration(
                      labelText: context.tr('subject'),
                    ),
                    items: _subjects
                        .map(
                          (option) => DropdownMenuItem(
                            value: option.value,
                            child: Text(_localizedSubject(option.value)),
                          ),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (v) {
                            if (v == null) return;
                            setState(() => _subject = v);
                          },
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return context.tr('subject_required');
                      }
                      return null;
                    },
                  ),
                  if (_subject == 'Other') ...[
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _customSubjectController,
                      enabled: !_saving,
                      decoration: InputDecoration(
                        labelText: context.tr('enter_custom_subject'),
                      ),
                      validator: (value) {
                        if (_subject != 'Other') return null;
                        if ((value ?? '').trim().isEmpty) {
                          return context.tr('custom_subject_required');
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
                                ? context.tr('start_time')
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
                                ? context.tr('end_time')
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
                    decoration: InputDecoration(
                      labelText: context.tr('servant_optional'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _notesController,
                    enabled: !_saving,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: context.tr('notes_optional'),
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
                    label: Text(
                      _isEdit ? context.tr('save_changes') : context.tr('add'),
                    ),
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
