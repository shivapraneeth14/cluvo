import 'package:flutter/material.dart';
import '../supabase_client.dart';

class PaymentDetailScreen extends StatefulWidget {
  final String paymentId;

  const PaymentDetailScreen({super.key, required this.paymentId});

  @override
  State<PaymentDetailScreen> createState() => _PaymentDetailScreenState();
}

class _PaymentDetailScreenState extends State<PaymentDetailScreen> {
  Map<String, dynamic>? _payment;
  List<dynamic>? _auditLog;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        supabase
            .from('payments')
            .select('*, registrations!inner(*, events!inner(title, start_date, status))')
            .eq('id', widget.paymentId)
            .single(),
        supabase
            .from('payment_audit_log')
            .select('*')
            .eq('payment_id', widget.paymentId)
            .order('created_at'),
      ]);
      if (!mounted) return;
      setState(() {
        _payment = results[0] as Map<String, dynamic>?;
        _auditLog = results[1] as List<dynamic>?;
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

  Color _statusColor(String status) {
    switch (status) {
      case 'success':
      case 'confirmed':
      case 'processed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'failed':
      case 'refunded':
      case 'reversed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'success':
      case 'confirmed':
      case 'processed':
        return Icons.check_circle;
      case 'pending':
        return Icons.schedule;
      case 'failed':
      case 'refunded':
      case 'reversed':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return dateStr;
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Details'),
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
          child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
        ),
      );
    }
    if (_payment == null) {
      return const Center(child: Text('Payment not found'));
    }

    final reg = _payment!['registrations'] as Map<String, dynamic>?;
    final ev = reg?['events'] as Map<String, dynamic>?;
    final title = ev?['title'] as String? ?? 'Unknown Event';
    final startDate = ev?['start_date'] as String?;
    final amount = (_payment!['amount'] as num?)?.toInt() ?? 0;
    final status = _payment!['status'] as String? ?? 'pending';
    final refundStatus = _payment!['refund_status'] as String?;
    final razorpayOrderId = _payment!['razorpay_order_id'] as String?;
    final razorpayPaymentId = _payment!['razorpay_payment_id'] as String?;
    final createdAt = _payment!['created_at'] as String?;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                if (startDate != null) ...[
                  const SizedBox(height: 4),
                  Text(_formatDate(startDate),
                      style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard('Payment', [
          _row('Amount', '₹${(amount / 100).toStringAsFixed(0)}'),
          _row('Payment ID', widget.paymentId),
          if (razorpayOrderId != null) _row('Order ID', razorpayOrderId),
          if (razorpayPaymentId != null) _row('Razorpay ID', razorpayPaymentId),
          _row('Date', _formatDate(createdAt)),
          _statusRow('Status', status),
          if (refundStatus != null) _statusRow('Refund', refundStatus),
        ]),
        if (_auditLog != null && _auditLog!.isNotEmpty) ...[
          const SizedBox(height: 12),
          _sectionCard('Activity Log', [
            for (final entry in _auditLog!)
              _auditEntry(entry as Map<String, dynamic>),
          ]),
        ],
      ],
    );
  }

  Widget _sectionCard(String title, List<Widget> children) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _statusRow(String label, String status) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_statusIcon(status), size: 14, color: _statusColor(status)),
              const SizedBox(width: 4),
              Text(
                status[0].toUpperCase() + status.substring(1),
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _statusColor(status)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _auditEntry(Map<String, dynamic> entry) {
    final action = entry['action'] as String? ?? '';
    final entryDate = entry['created_at'] as String?;
    final details = entry['details'] as Map<String, dynamic>?;
    final actionLabel = action
        .split('_')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 5),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(actionLabel,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                if (details != null && details['note'] != null)
                  Text(details['note'].toString(),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                Text(_formatDate(entryDate),
                    style: TextStyle(fontSize: 11, color: Colors.grey[400])),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
