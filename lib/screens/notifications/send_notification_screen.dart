import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:summerschool/constants/user_roles.dart';
import 'package:summerschool/providers/auth_provider.dart';
import 'package:summerschool/services/notification_service.dart';

class SendNotificationScreen extends StatefulWidget {
  const SendNotificationScreen({super.key});

  @override
  State<SendNotificationScreen> createState() => _SendNotificationScreenState();
}

class _SendNotificationScreenState extends State<SendNotificationScreen> {
  final NotificationService _notificationService = NotificationService();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();

  final Set<String> _targetRoles = <String>{};
  final Set<String> _targetStages = <String>{};
  bool _isImportant = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _sendNotification() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.user;

    if (user == null) return;
    if (user.role == UserRole.member) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You are not allowed to send notifications.'),
        ),
      );
      return;
    }

    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter title and message.')),
      );
      return;
    }

    if (user.role == UserRole.manager &&
        _targetRoles.isEmpty &&
        _targetStages.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'If you select stages only, notifications will be sent to all roles within those stages.',
          ),
        ),
      );
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _notificationService.createNotification(
        sender: user,
        title: title,
        body: body,
        targetRoles: _targetRoles.toList(),
        targetStages: _targetStages.toList(),
        isImportant: _isImportant,
      );

      if (mounted) {
        _titleController.clear();
        _bodyController.clear();
        setState(() {
          _targetRoles.clear();
          _targetStages.clear();
          _isImportant = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('In-app notification sent successfully.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().user;
    final canSend = user != null && user.role != UserRole.member;
    final isManager = user?.role == UserRole.manager;

    return Scaffold(
      appBar: AppBar(title: const Text('Send In-App Notification')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!canSend)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'This page is available to managers and member managers only.',
                  ),
                ),
              )
            else ...[
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          labelText: 'Title',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          prefixIcon: const Icon(Icons.title_rounded),
                        ),
                        maxLength: 90,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _bodyController,
                        decoration: InputDecoration(
                          labelText: 'Message',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignLabelWithHint: true,
                        ),
                        maxLines: 5,
                        maxLength: 500,
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: _isImportant,
                        onChanged: (v) => setState(() => _isImportant = v),
                        title: const Text('Important Notification'),
                        subtitle: const Text(
                          'It will be marked as important in Notification Center.',
                        ),
                        secondary: Icon(
                          _isImportant
                              ? Icons.priority_high_rounded
                              : Icons.notifications_none_rounded,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (isManager) _buildManagerTargetsCard(context),
              if (!isManager)
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(14),
                    child: Text(
                      'It will be sent automatically to members in your class only.',
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _isLoading ? null : _sendNotification,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(_isLoading ? 'Sending...' : 'Send In-App'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildManagerTargetsCard(BuildContext context) {
    final roleOptions = <MapEntry<String, String>>[
      MapEntry(UserRole.manager.value, 'Managers'),
      MapEntry(UserRole.memberManager.value, 'Member Managers'),
      MapEntry(UserRole.member.value, 'Members'),
    ];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Target Roles',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: roleOptions.map((entry) {
                final selected = _targetRoles.contains(entry.key);
                return FilterChip(
                  selected: selected,
                  label: Text(entry.value),
                  onSelected: (v) {
                    setState(() {
                      if (v) {
                        _targetRoles.add(entry.key);
                      } else {
                        _targetRoles.remove(entry.key);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            Text(
              'Target Stages',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            StreamBuilder<List<String>>(
              stream: _notificationService.watchAvailableStages(),
              builder: (context, snap) {
                final stages = snap.data ?? const <String>[];
                if (stages.isEmpty) {
                  return const Text('No stages are currently available.');
                }
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: stages.map((stage) {
                    final selected = _targetStages.contains(stage);
                    return FilterChip(
                      selected: selected,
                      label: Text(stage),
                      onSelected: (v) {
                        setState(() {
                          if (v) {
                            _targetStages.add(stage);
                          } else {
                            _targetStages.remove(stage);
                          }
                        });
                      },
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 8),
            Text(
              'If no role or stage is selected, it will be sent to everyone.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
