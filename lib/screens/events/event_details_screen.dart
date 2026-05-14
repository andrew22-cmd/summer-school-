import 'package:flutter/material.dart';
// No external date package used; simple formatting below.
import 'package:summerschool/models/event_model.dart';
import 'package:summerschool/core/constants/app_colors.dart';

class EventDetailsScreen extends StatelessWidget {
  const EventDetailsScreen({super.key, required this.event});

  final EventModel event;

  String _formatDate(DateTime d) =>
      '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

  String _dayName(DateTime d) {
    const names = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return names[(d.weekday - 1) % 7];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Event Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Icon(Icons.event, size: 64, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              event.title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              '${_dayName(event.date)} • ${_formatDate(event.date)} • ${event.time}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            if ((event.createdByName ?? '').trim().isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.person, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    'Added by: ${event.createdByName}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            if (event.location.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.location_on, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(event.location)),
                ],
              ),
              const SizedBox(height: 12),
            ],
            Text(event.description),
          ],
        ),
      ),
    );
  }
}
