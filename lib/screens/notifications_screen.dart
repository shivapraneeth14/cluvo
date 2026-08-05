import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/notification_provider.dart';
import '../supabase_client.dart';
import '../theme.dart';
import '../models/models.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/communities');
            }
          },
        ),
      ),
      body: notifications.when(
        data: (data) {
          if (data.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_none, size: 48, color: context.cluvoTextSecondary),
                  SizedBox(height: 12),
                  Text('No notifications yet.',
                      style: TextStyle(color: context.cluvoTextSecondary)),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(notificationsProvider);
              ref.invalidate(unreadCountProvider);
              await ref.read(notificationsProvider.future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: data.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 16),
              itemBuilder: (context, index) {
                final n = data[index];
                final isRead = n.read;
                final type = n.type;

                return ListTile(
                  leading: _iconForType(context, type, isRead),
                  title: Text(
                    n.title,
                    style: TextStyle(
                      fontWeight: isRead ? FontWeight.normal : FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    n.body ?? '',
                    style: TextStyle(fontSize: 12, color: context.cluvoTextSecondary),
                  ),
                  trailing: Text(
                    _timeAgo(n),
                    style: TextStyle(fontSize: 11, color: context.cluvoTextSecondary),
                  ),
                  onTap: () => _openNotification(context, n, ref),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text('Could not load notifications.\n$e',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.cluvoTextSecondary)),
          ),
        ),
      ),
    );
  }

  Widget _iconForType(BuildContext context, String type, bool isRead) {
    IconData icon;
    Color color;
    switch (type) {
      case 'new_event':
        icon = Icons.event;
        color = CluvoTheme.primary;
        break;
      case 'new_media':
        icon = Icons.photo_library;
        color = Colors.blue;
        break;
      case 'registration_confirmed':
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case 'event_cancelled':
        icon = Icons.cancel;
        color = Colors.red;
        break;
      case 'removed_from_community':
        icon = Icons.person_remove;
        color = Colors.red;
        break;
      default:
        icon = Icons.notifications;
        color = context.cluvoTextSecondary;
    }
    return CircleAvatar(
      radius: 18,
      backgroundColor: color.withValues(alpha: 0.15),
      child: Icon(icon, size: 18, color: color),
    );
  }

  Future<void> _openNotification(
      BuildContext context, AppNotification n, WidgetRef ref) async {
    if (!n.read) {
      try {
        await supabase.from('notifications').update({'read': true}).eq('id', n.id);
        if (!context.mounted) return;
        ref.invalidate(unreadCountProvider);
        ref.invalidate(notificationsProvider);
      } catch (_) {
      }
    }
    final payload = n.payload;
    if (payload == null) return;
    if (payload['type'] == 'community') {
      final id = payload['id'];
      if (id != null) context.push('/communities/$id');
    } else {
      final eventId = payload['id'] ?? payload['event_id'];
      if (eventId != null) context.push('/events/$eventId');
    }
  }

  String _timeAgo(AppNotification notification) {
    final dt = notification.createdAt;
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.day}/${dt.month}';
  }
}
