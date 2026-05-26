import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:summerschool/core/constants/app_colors.dart';
import 'package:summerschool/providers/auth_provider.dart';
import 'package:summerschool/providers/spiritual_note_provider.dart';
import 'package:summerschool/services/spiritual_note_service.dart';

class MemberSpiritualNoteScreen extends StatelessWidget {
  const MemberSpiritualNoteScreen({
    super.key,
    required this.selectedUserId,
    required this.selectedUserName,
    required this.selectedUserRole,
    required this.selectedUserStage,
  });

  final String selectedUserId;
  final String selectedUserName;
  final String selectedUserRole;
  final String selectedUserStage;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) =>
          SpiritualNoteProvider(SpiritualNoteService())
            ..startListening(selectedUserId),
      child: _MemberSpiritualNoteView(
        selectedUserId: selectedUserId,
        selectedUserName: selectedUserName,
        selectedUserRole: selectedUserRole,
        selectedUserStage: selectedUserStage,
      ),
    );
  }
}

class _MemberSpiritualNoteView extends StatefulWidget {
  const _MemberSpiritualNoteView({
    required this.selectedUserId,
    required this.selectedUserName,
    required this.selectedUserRole,
    required this.selectedUserStage,
  });

  final String selectedUserId;
  final String selectedUserName;
  final String selectedUserRole;
  final String selectedUserStage;

  @override
  State<_MemberSpiritualNoteView> createState() =>
      _MemberSpiritualNoteViewState();
}

class _MemberSpiritualNoteViewState extends State<_MemberSpiritualNoteView> {
  final TextEditingController _controller = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final provider = context.watch<SpiritualNoteProvider>();

    if (!auth.isManager) {
      return Scaffold(
        appBar: AppBar(title: const Text('Spiritual Notes')),
        body: const Center(child: Text('Only manager can access notes.')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surfaceSoft,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        title: const Text('Member Spiritual Notes'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.selectedUserName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('Role: ${widget.selectedUserRole}'),
                      Text('Stage: ${widget.selectedUserStage}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      TextField(
                        controller: _controller,
                        minLines: 2,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          hintText: 'Write private spiritual note...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: ElevatedButton.icon(
                          onPressed: _saving
                              ? null
                              : () async {
                                  final text = _controller.text.trim();
                                  if (text.isEmpty) return;
                                  setState(() => _saving = true);
                                  try {
                                    await provider.addNote(
                                      userId: widget.selectedUserId,
                                      userName: widget.selectedUserName,
                                      note: text,
                                      createdBy: auth.user?.id ?? 'manager',
                                    );
                                    debugPrint(
                                      '[Manager][Notes] note added userId=${widget.selectedUserId}',
                                    );
                                    _controller.clear();
                                  } finally {
                                    if (mounted) {
                                      setState(() => _saving = false);
                                    }
                                  }
                                },
                          icon: _saving
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.add),
                          label: const Text('Add Note'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: provider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : provider.error != null
                    ? Center(
                        child: Text(
                          'Error: ${provider.error}',
                          style: const TextStyle(color: Colors.red),
                        ),
                      )
                    : provider.notes.isEmpty
                    ? const Center(child: Text('No notes yet.'))
                    : ListView.separated(
                        itemCount: provider.notes.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final n = provider.notes[index];
                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                            child: ListTile(
                              title: Text(n.note),
                              subtitle: Text('By: ${n.createdBy}'),
                              trailing: Wrap(
                                spacing: 4,
                                children: [
                                  IconButton(
                                    tooltip: 'Edit note',
                                    onPressed: () =>
                                        _editNote(context, n.id, n.note),
                                    icon: const Icon(Icons.edit_rounded),
                                  ),
                                  IconButton(
                                    tooltip: 'Delete note',
                                    onPressed: () => _deleteNote(context, n.id),
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      color: Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ),
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

  Future<void> _editNote(
    BuildContext context,
    String id,
    String oldText,
  ) async {
    final provider = context.read<SpiritualNoteProvider>();
    final ctrl = TextEditingController(text: oldText);

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit note'),
        content: TextField(
          controller: ctrl,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    await provider.updateNote(id: id, note: ctrl.text);
    debugPrint('[Manager][Notes] note updated id=$id');
  }

  Future<void> _deleteNote(BuildContext context, String id) async {
    final provider = context.read<SpiritualNoteProvider>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete note'),
        content: const Text('Are you sure you want to delete this note?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    await provider.deleteNote(id);
    debugPrint('[Manager][Notes] note deleted id=$id');
  }
}
