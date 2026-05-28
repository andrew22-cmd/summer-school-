import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:summerschool/providers/auth_provider.dart';
import 'package:summerschool/screens/notifications/notification_center_screen.dart';
import 'package:summerschool/services/notification_service.dart';

class NotificationPopup extends StatelessWidget {
  final double width;
  final double maxHeight;
  final NotificationService? service;

  const NotificationPopup({
    super.key,
    this.width = 350,
    this.maxHeight = 400,
    this.service,
  });

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().user;
    final notificationService = service ?? NotificationService();

    if (user == null) {
      return const SizedBox(
        width: 300,
        child: Center(child: Text('Please sign in first')),
      );
    }

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      color: Colors.white,
      child: SizedBox(
        width: width,
        height: maxHeight,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Notifications',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: NotificationCenterContent(
                userId: user.id,
                service: notificationService,
                useScrollbar: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
