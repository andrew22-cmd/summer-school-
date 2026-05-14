import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:summerschool/models/class_member_model.dart';
import 'package:summerschool/providers/auth_provider.dart';
import 'package:summerschool/providers/class_member_provider.dart';

class AddEditClassMemberScreen extends StatefulWidget {
  const AddEditClassMemberScreen({super.key, this.member});

  final ClassMemberModel? member;

  @override
  State<AddEditClassMemberScreen> createState() =>
      _AddEditClassMemberScreenState();
}

class _AddEditClassMemberScreenState extends State<AddEditClassMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _stage = TextEditingController();
  final _year = TextEditingController();
  final _phone = TextEditingController();
  final _parent = TextEditingController();
  final _confession = TextEditingController();
  final _points = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final m = widget.member;
    if (m != null) {
      _name.text = m.name;
      _stage.text = m.stage;
      _year.text = m.year;
      _phone.text = m.phone;
      _parent.text = m.parentPhone;
      _confession.text = m.confessionFather;
      _points.text = m.totalPoints.toString();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // If adding a new member, default the stage to the current manager's stage
    if (widget.member == null && _stage.text.trim().isEmpty) {
      try {
        final auth = context.read<AuthProvider>();
        final defaultStage = auth.user?.stage ?? '';
        if (defaultStage.isNotEmpty) _stage.text = defaultStage;
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _stage.dispose();
    _year.dispose();
    _phone.dispose();
    _parent.dispose();
    _confession.dispose();
    _points.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final auth = context.read<AuthProvider>();
    final provider = Provider.of<ClassMemberProvider>(context, listen: false);
    final now = DateTime.now();

    try {
      var data = ClassMemberModel(
        id: widget.member?.id ?? '',
        name: _name.text.trim(),
        stage: _stage.text.trim(),
        year: _year.text.trim(),
        phone: _phone.text.trim(),
        parentPhone: _parent.text.trim(),
        confessionFather: _confession.text.trim(),
        totalPoints: int.tryParse(_points.text.trim()) ?? 0,
        createdAt: widget.member?.createdAt ?? now,
        createdBy: widget.member?.createdBy ?? (auth.user?.id ?? ''),
      );

      if (widget.member == null) {
        final created = await provider.addMember(data);
        // if service returned an assigned id, use it
        if (created.id.isNotEmpty) data = created;
      } else {
        await provider.updateMember(data.id, data.toMap());
      }

      if (!mounted) return;
      Navigator.pop(context, data);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.member == null ? 'Add Student' : 'Edit Student'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _stage,
                  decoration: const InputDecoration(labelText: 'Stage'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _year,
                  decoration: const InputDecoration(labelText: 'Year'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _phone,
                  decoration: const InputDecoration(labelText: 'Phone'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _parent,
                  decoration: const InputDecoration(labelText: 'Parent Phone'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _confession,
                  decoration: const InputDecoration(
                    labelText: 'Confession Father',
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _points,
                  decoration: const InputDecoration(labelText: 'Total Points'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Save'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
