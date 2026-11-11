import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../supabase_client.dart';

Future<List<Map<String, dynamic>>> _fetchMyRegistrations() async {
  final session = supabase.auth.currentSession;
  if (session == null) return [];
  final res = await supabase
      .from('registrations')
      .select(
        '*, events!inner(title, start_date, status, price, communities!inner(name)), payments(status, refund_status, refund_claim_state, amount, refunded_amount, platform_fee, organizer_share))',
      )
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
      .select(
        '*, registrations!inner(user_id, events(title, start_date, status))',
      )
      .eq('registrations.user_id', session.user.id)
      .order('created_at', ascending: false);
  final payments = (res as List).cast<Map<String, dynamic>>();

  // A payment row is REUSED across cancel -> rebook cycles, so a previous
  // refund would vanish from this list once the row is re-quoted for a new
  // sale. The server archives every issued refund in payment_refund_history;
  // show an archived card only when the live row no longer displays that
  // refund (i.e. it was re-quoted) — never duplicate the live one.
  List<Map<String, dynamic>> history = [];
  try {
    final hres = await supabase
        .from('payment_refund_history')
        .select(
          '*, registrations!inner(user_id, events(title, start_date, status))',
        )
        .eq('registrations.user_id', session.user.id)
        .order('created_at', ascending: false);
    history = (hres as List).cast<Map<String, dynamic>>();
  } catch (_) {
    // Table missing on older backends — list still works without history.
  }
  if (history.isEmpty) return payments;

  // A live refund must hide only ITSELF from the archive, not every archived
  // refund on the same reused payment row. Deduplicate by provider refund id;
  // for an id-less in-flight claim, hide at most the newest archived row.
  final liveRefundIds = <String>{
    for (final p in payments)
      if (p['razorpay_refund_id'] != null)
        p['razorpay_refund_id'] as String,
  };
  final liveIdlessPayments = <String>{
    for (final p in payments)
      if (p['refund_status'] != null && p['razorpay_refund_id'] == null)
        p['id'] as String,
  };
  final skippedIdless = <String>{};
  final archived = <Map<String, dynamic>>[];
  for (final h in history) {
    final refundId = h['razorpay_refund_id'] as String?;
    if (refundId != null && liveRefundIds.contains(refundId)) continue;
    final paymentId = h['payment_id'] as String?;
    if (refundId == null &&
        paymentId != null &&
        liveIdlessPayments.contains(paymentId) &&
        skippedIdless.add(paymentId)) {
      continue;
    }
    archived.add({
      ...h,
      'status': 'refunded',
      'refund_status': h['refund_status'] ?? 'processed',
      'refunded_amount':
          h['refund_amount'] ?? h['organizer_clawed'] ?? h['amount'],
      'amount': h['payment_amount'] ?? h['amount'],
      'is_refund_history': true,
    });
  }

  final merged = [...payments, ...archived];
  merged.sort((a, b) => (b['created_at'] as String? ?? '')
      .compareTo(a['created_at'] as String? ?? ''));
  return merged;
}

final myPaymentsProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => _fetchMyPayments(),
);
