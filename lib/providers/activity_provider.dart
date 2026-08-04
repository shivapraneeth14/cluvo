import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../supabase_client.dart';

Future<List<Map<String, dynamic>>> _fetchMyRegistrations() async {
  final session = supabase.auth.currentSession;
  if (session == null) return [];
  final res = await supabase
      .from('registrations')
      .select('*, events!inner(title, start_date, status, communities!inner(name)), payments(status, refund_status)')
      .eq('user_id', session.user.id)
      .eq('events.communities.is_hidden', false)
      .order('registered_at', ascending: false);
  return (res as List).cast<Map<String, dynamic>>();
}

final myRegistrationsProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => _fetchMyRegistrations(),
);

Future<List<Map<String, dynamic>>> _fetchMyPayments() async {
  final session = supabase.auth.currentSession;
  if (session == null) return [];
  final res = await supabase
      .from('payments')
      .select('*, registrations!inner(user_id, events!inner(title, start_date))')
      .eq('registrations.user_id', session.user.id)
      .order('created_at', ascending: false);
  return (res as List).cast<Map<String, dynamic>>();
}

final myPaymentsProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => _fetchMyPayments(),
);