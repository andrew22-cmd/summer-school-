import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:summerschool/constants/user_roles.dart';
import 'package:summerschool/providers/auth_provider.dart';
import 'package:summerschool/services/notification_service.dart';
import 'package:summerschool/core/localization/app_localizations.dart';

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
        SnackBar(
          content: Text(context.tr('not_allowed_send')),
        ),
      );
      return;
    }

    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('enter_title_body'))),
      );
      return;
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
        targetStages: [],
        isImportant: _isImportant,
      );

      if (mounted) {
        _titleController.clear();
        _bodyController.clear();
        setState(() {
          _targetRoles.clear();
          _isImportant = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('notification_sent_success')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.tr('notification_send_error')}: ${e.toString()}'),
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
      appBar: AppBar(title: Text(context.tr('send_notification_title'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!canSend)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    context.tr('page_for_managers'),
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
                          labelText: context.tr('notification_title'),
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
                          labelText: context.tr('notification_body'),
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
                        title: Text(context.tr('important_notification')),
                        subtitle: Text(
                          context.tr('important_notification_desc'),
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
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      context.tr('sent_to_class_only'),
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
                label: Text(_isLoading ? context.tr('sending') : context.tr('send_in_app')),
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
      MapEntry(UserRole.manager.value, context.tr('role_managers')),
      MapEntry(UserRole.memberManager.value, context.tr('role_member_managers')),
      MapEntry(UserRole.member.value, context.tr('role_members')),
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
              context.tr('target_roles_label'),
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
            const SizedBox(height: 8),
            Text(
              context.tr('no_roles_send_all'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
