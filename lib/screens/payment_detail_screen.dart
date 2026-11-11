import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_client.dart';
import '../utils.dart';
import '../widgets/chigzo_logo.dart';
import '../widgets/payment_receipt.dart';

class PaymentDetailScreen extends StatefulWidget {
  final String? paymentId;
  final String? historyId;

  const PaymentDetailScreen({
    super.key,
    this.paymentId,
    this.historyId,
  }) : assert(paymentId != null || historyId != null, 'paymentId or historyId must be provided');

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
    if (widget.paymentId == null) return;
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
              value: widget.paymentId!,
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
      Map<String, dynamic> payment;
      List<dynamic> timeline = [];

      if (widget.historyId != null) {
        final res = await supabase
            .from('payment_refund_history')
            .select(
              '*, registrations!inner(*, events(title, start_date, image_url, status))',
            )
            .eq('id', widget.historyId!)
            .single();

        payment = {
          ...res,
          'status': 'refunded',
          'refund_status': res['refund_status'] ?? 'processed',
          'refunded_amount': res['amount'],
          'amount': res['payment_amount'] ?? res['amount'],
          'razorpay_payment_id': res['razorpay_refund_id'],
          'is_refund_history': true,
        };

        final payId = res['payment_id'] as String?;
        if (payId != null) {
          timeline = await _fetchTimeline(payId);
        }
      } else {
        payment = await supabase
            .from('payments')
            .select(
              '*, registrations!inner(*, events(title, start_date, image_url, status))',
            )
            .eq('id', widget.paymentId!)
            .single();
        timeline = await _fetchTimeline(widget.paymentId!);
      }

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

  Future<List<dynamic>> _fetchTimeline(String targetPaymentId) async {
    final res = await supabase
        .from('notifications')
        .select('*')
        .contains('payload', {'payment_id': targetPaymentId})
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
      final pid = widget.paymentId ?? (_payment?['payment_id'] as String?);
      if (pid == null) return;
      final timeline = await _fetchTimeline(pid);
      if (!mounted) return;
      setState(() => _timeline = timeline);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: ChigzoLogoTitle(widget.historyId != null ? 'Refund Details' : 'Payment Details'),
      ),
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
    final organizerSharePaise = (_payment!['organizer_share'] as num?)?.toInt();
    final refundStatus = _payment!['refund_status'] as String?;
    final refundedAmountPaise = (_payment!['refunded_amount'] as num?)?.toInt();

    // What the buyer actually gets back: the recorded refund when we have it.
    // Otherwise, if they were issued a ticket (organizer_share set) the ticket
    // price is refunded and the platform fee is kept — for a self-cancel and an
    // organizer-cancelled event alike. A never-confirmed capture (organizer_share
    // null) is refunded in full.
    int? refundDisplayPaise;
    if (refundStatus != null) {
      if (refundedAmountPaise != null && refundedAmountPaise > 0) {
        refundDisplayPaise = refundedAmountPaise;
      } else if (organizerSharePaise != null) {
        refundDisplayPaise = organizerSharePaise;
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
      paymentId: widget.paymentId ?? widget.historyId,
      orderId: _payment!['razorpay_order_id'] as String?,
      razorpayId: _payment!['razorpay_payment_id'] as String?,
      createdAtText: formatDateTime(
        safeParseDate(
          (_payment!['status'] == 'success' || _payment!['status'] == 'refunded')
              ? (_payment!['updated_at'] as String? ?? _payment!['created_at'] as String?)
              : (_payment!['created_at'] as String?),
        ),
      ),
      timeline: (_timeline ?? []).whereType<Map<String, dynamic>>().toList(),
    );
  }
}
