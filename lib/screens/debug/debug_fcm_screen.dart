import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:summerschool/constants/user_roles.dart';
import 'package:summerschool/providers/auth_provider.dart';
import 'package:summerschool/services/fcm_service.dart';

class DebugFcmScreen extends StatefulWidget {
  const DebugFcmScreen({super.key});

  @override
  State<DebugFcmScreen> createState() => _DebugFcmScreenState();
}

class _DebugFcmScreenState extends State<DebugFcmScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final fcm = context.read<FcmService>();
      debugPrint(
        '[FCM][DebugScreen] EXACT CURRENT TOKEN => ${fcm.currentToken}',
      );
    });
  }

  Future<void> _refreshAndResubscribe() async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    final fcm = context.read<FcmService>();

    if (user == null) return;

    await fcm.subscribeToUserTopics(
      user.role.value,
      user.stage.isEmpty ? null : user.stage,
    );
    await fcm.syncTokenWithUser(user);

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final fcm = context.read<FcmService>();

    return Scaffold(
      appBar: AppBar(title: const Text('FCM Debug')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _InfoCard(
            title: 'Permission status',
            value: fcm.permissionStatus ?? 'unknown',
          ),
          const SizedBox(height: 12),
          _InfoCard(
            title: 'Current token',
            value: fcm.currentToken ?? 'No token yet',
            trailing: FilledButton.tonalIcon(
              onPressed: fcm.currentToken == null
                  ? null
                  : () async {
                      debugPrint(
                        '[FCM][DebugScreen] COPY TOKEN => ${fcm.currentToken}',
                      );
                      await Clipboard.setData(
                        ClipboardData(text: fcm.currentToken!),
                      );
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('FCM token copied')),
                      );
                    },
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copy FCM Token'),
            ),
          ),
          const SizedBox(height: 12),
          _InfoCard(
            title: 'Subscribed topics',
            value: fcm.subscribedTopics.isEmpty
                ? 'No subscriptions'
                : fcm.subscribedTopics.join(', '),
          ),
          const SizedBox(height: 12),
          _InfoCard(
            title: 'Last received message',
            value: fcm.lastReceivedMessage ?? 'No message received yet',
          ),
          const SizedBox(height: 12),
          _InfoCard(
            title: 'Last received at',
            value: fcm.lastReceivedAt == null
                ? 'Never'
                : fcm.lastReceivedAt!.toLocal().toString(),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: user == null ? null : _refreshAndResubscribe,
            icon: const Icon(Icons.sync_rounded),
            label: const Text('Re-subscribe topics'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              await fcm.showTestNotification();
              if (!mounted) return;
              setState(() {});
            },
            icon: const Icon(Icons.notifications_active_rounded),
            label: const Text('Test local notification'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              await fcm.simulateIncomingMessage(
                title: 'Simulated',
                body: 'This is a simulated FCM message',
                data: {'simulated': 'true'},
              );
              if (!mounted) return;
              setState(() {});
            },
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Simulate Incoming FCM'),
          ),
          const SizedBox(height: 12),
          Text(
            user == null
                ? 'No logged-in user.'
                : 'Current user: ${user.name} (${user.role.value})',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.value, this.trailing});

  final String title;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(value),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
