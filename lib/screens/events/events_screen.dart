import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:summerschool/providers/event_provider.dart';
import 'package:summerschool/services/event_service.dart';
import 'package:summerschool/models/event_model.dart';
import 'event_details_screen.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  late final EventProvider _provider;
  late final Stream<List<EventModel>> _stream;

  @override
  void initState() {
    super.initState();
    final service = EventService();
    _provider = EventProvider(service);
    _stream = service.watchEvents();
  }

  Future<void> _onRefresh() async {
    await _provider.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<EventProvider>.value(
      value: _provider,
      child: Scaffold(
        appBar: AppBar(title: const Text('Events')),
        body: StreamBuilder<List<EventModel>>(
          stream: _stream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final events = snapshot.data ?? [];
            if (events.isEmpty) {
              return RefreshIndicator(
                onRefresh: _onRefresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 200),
                    Center(child: Text('No events yet')),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: _onRefresh,
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: events.length,
                itemBuilder: (context, index) {
                  final e = events[index];
                  return _EventCard(event: e);
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});
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
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => EventDetailsScreen(event: event)),
      ),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.event, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_dayName(event.date)} - ${_formatDate(event.date)}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      event.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
