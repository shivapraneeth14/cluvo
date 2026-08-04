import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_client.dart';

class NotificationsRealtime {
  NotificationsRealtime(this.onChange);

  final void Function() onChange;
  RealtimeChannel? _channel;
  String? _uid;

  void sync(String? uid) {
    if (uid == _uid) return;
    _uid = uid;
    _channel?.unsubscribe();
    _channel = null;
    if (uid == null) return;
    _channel = supabase.channel('notifications-$uid');
    _channel!.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'notifications',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: uid,
      ),
      callback: (_) => onChange(),
    );
    _channel!.subscribe();
  }

  void dispose() {
    _channel?.unsubscribe();
    _channel = null;
    _uid = null;
  }
}
