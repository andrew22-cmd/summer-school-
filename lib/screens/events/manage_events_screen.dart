import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:summerschool/core/constants/app_colors.dart';
import 'package:summerschool/models/event_model.dart';
import 'package:summerschool/providers/event_provider.dart';
import 'package:summerschool/services/event_service.dart';
import 'edit_event_screen.dart';

class ManageEventsScreen extends StatefulWidget {
  const ManageEventsScreen({super.key});

  @override
  State<ManageEventsScreen> createState() => _ManageEventsScreenState();
}

class _ManageEventsScreenState extends State<ManageEventsScreen> {
  late final EventProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = EventProvider(EventService());
    _provider.startListening();
  }

  @override
  void dispose() {
    _provider.stopListening();
    super.dispose();
  }

  Future<void> _confirmDelete(EventModel e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete event?'),
        content: const Text(
          'Are you sure you want to delete this event? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (ok == true) {
      try {
        await _provider.deleteEvent(e.id);
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Event deleted')));
      } catch (err) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: ${err.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<EventProvider>.value(
      value: _provider,
      child: Scaffold(
        appBar: AppBar(title: const Text('Manage Events')),
        floatingActionButton: FloatingActionButton(
          backgroundColor: AppColors.primary,
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          onPressed: () => Navigator.pushNamed(context, '/add-event'),
          child: const Icon(Icons.add, color: Colors.white),
        ),
        body: Consumer<EventProvider>(
          builder: (context, prov, _) {
            if (prov.isLoading)
              return const Center(child: CircularProgressIndicator());
            final events = prov.events;
            if (events.isEmpty)
              return const Center(child: Text('No events found'));
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: events.length,
              itemBuilder: (context, i) {
                final e = events[i];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.event, color: AppColors.primary),
                    ),
                    title: Text(
                      e.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        Text(
                          '${e.dayName} - ${e.date.year}/${e.date.month.toString().padLeft(2, '0')}/${e.date.day.toString().padLeft(2, '0')}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          e.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if ((e.createdByName ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Added by: ${e.createdByName}',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.orange),
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EditEventScreen(event: e),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _confirmDelete(e),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
