import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_client.dart';
import '../utils.dart';
import '../widgets/payment_receipt.dart';

class PaymentDetailScreen extends StatefulWidget {
  final String paymentId;

  const PaymentDetailScreen({super.key, required this.paymentId});

  @override
  State<PaymentDetailScreen> createState() => _PaymentDetailScreenState();
}

class _PaymentDetailScreenState extends State<PaymentDetailScreen> {
  Map<String, dynamic>? _payment;
  List<dynamic>? _timeline;
  bool _loading = true;
  String? _error;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _load();
    _subscribe();
  }

  @override
  void dispose() {
    final ch = _channel;
    if (ch != null) supabase.removeChannel(ch);
    super.dispose();
  }

  void _subscribe() {
    try {
      _channel = supabase
          .channel('payment-detail-${widget.paymentId}')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'payments',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: widget.paymentId,
            ),
            callback: (payload) {
              final newRow = payload.newRecord;
              if (!mounted) return;
              setState(() {
                _payment = {...?_payment, ...newRow};
              });
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: supabase.auth.currentUser?.id ?? '',
            ),
            callback: (payload) async {
              final row = payload.newRecord;
              final payId = (row['payload'] as Map?)?.remove('payment_id');
              if (payId != widget.paymentId) return;
              await _loadTimelineOnly();
            },
          )
          .subscribe();
    } catch (_) {
      // realtime unavailable — manual navigation still works
    }
  }

  Future<void> _load() async {
    try {
      final payment = await supabase
          .from('payments')
          .select(
            '*, registrations!inner(*, events(title, start_date, image_url, status))',
          )
          .eq('id', widget.paymentId)
          .single();
      final timeline = await _fetchTimeline();
      if (!mounted) return;
      setState(() {
        _payment = payment;
        _timeline = timeline;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<List<dynamic>> _fetchTimeline() async {
    final res = await supabase
        .from('notifications')
        .select('*')
        .contains('payload', {'payment_id': widget.paymentId})
        .inFilter('type', [
          'registration_confirmed',
          'refund_initiated',
          'refund_completed',
        ])
        .order('created_at');
    return res as List<dynamic>? ?? [];
  }

  Future<void> _loadTimelineOnly() async {
    try {
      final timeline = await _fetchTimeline();
      if (!mounted) return;
      setState(() => _timeline = timeline);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment Details')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            _error!,
            style: const TextStyle(color: Colors.red, fontSize: 13),
          ),
        ),
      );
    }
    if (_payment == null) {
      return const Center(child: Text('Payment not found'));
    }

    final reg = _payment!['registrations'] as Map<String, dynamic>?;
    final ev = reg?['events'] as Map<String, dynamic>?;

    final amountPaise = (_payment!['amount'] as num?)?.toInt() ?? 0;
    final platformFeePaise = (_payment!['platform_fee'] as num?)?.toInt();
    final refundStatus = _payment!['refund_status'] as String?;
    final refundedAmountPaise = (_payment!['refunded_amount'] as num?)?.toInt();
    final eventCancelled = ev?['status'] == 'cancelled';

    // What the buyer actually gets back: the recorded refund when we have it,
    // otherwise the full amount for an organizer-cancelled event, otherwise the
    // ticket price (platform fee kept) for a self-cancel.
    int? refundDisplayPaise;
    if (refundStatus != null) {
      if (refundedAmountPaise != null && refundedAmountPaise > 0) {
        refundDisplayPaise = refundedAmountPaise;
      } else if (eventCancelled) {
        refundDisplayPaise = amountPaise;
      } else if (platformFeePaise != null &&
          amountPaise - platformFeePaise > 0) {
        refundDisplayPaise = amountPaise - platformFeePaise;
      } else {
        refundDisplayPaise = amountPaise;
      }
    }

    return PaymentReceipt(
      status: _payment!['status'] as String? ?? 'pending',
      refundStatus: refundStatus,
      amountPaise: amountPaise,
      platformFeePaise: platformFeePaise,
      feeGstPaise: (_payment!['platform_fee_gst'] as num?)?.toInt(),
      refundedAmountPaise: refundDisplayPaise,
      eventTitle: ev?['title'] as String? ?? 'Unknown Event',
      eventImageUrl: ev?['image_url'] as String?,
      eventDateText: formatDayDate(ev?['start_date'] as String?),
      paymentId: widget.paymentId,
      orderId: _payment!['razorpay_order_id'] as String?,
      razorpayId: _payment!['razorpay_payment_id'] as String?,
      createdAtText: formatDateTime(
        safeParseDate(_payment!['created_at'] as String?),
      ),
      timeline: (_timeline ?? []).whereType<Map<String, dynamic>>().toList(),
    );
  }
}
