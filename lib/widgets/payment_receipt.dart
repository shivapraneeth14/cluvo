import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../utils.dart';
import 'dotted_divider.dart';

class PaymentReceipt extends StatelessWidget {
  final String status;
  final String? refundStatus;
  final int amountPaise;
  final int? platformFeePaise;
  final int? feeGstPaise;
  final int? refundedAmountPaise;
  final String eventTitle;
  final String? eventImageUrl;
  final String? eventDateText;
  final String? paymentId;
  final String? orderId;
  final String? razorpayId;
  final String? createdAtText;
  final List<Map<String, dynamic>> timeline;

  const PaymentReceipt({
    super.key,
    required this.status,
    this.refundStatus,
    required this.amountPaise,
    this.platformFeePaise,
    this.feeGstPaise,
    this.refundedAmountPaise,
    required this.eventTitle,
    this.eventImageUrl,
    this.eventDateText,
    this.paymentId,
    this.orderId,
    this.razorpayId,
    this.createdAtText,
    this.timeline = const [],
  });

  static const _refundLabels = {
    'processed': 'Refunded',
    'pending': 'Refund processing',
    'queued': 'Refund queued',
    'requested': 'Refund requested',
    'failed': 'Refund failed',
  };

  bool get _isSuccess =>
      const ['success', 'confirmed', 'processed'].contains(status);
  bool get _isRefunded => const ['refunded', 'reversed'].contains(status);

  // The refund only actually completed when Razorpay processed it. The payment
  // row is marked status=refunded the moment a refund is issued, so gating the
  // "Refunded" title on refundStatus (not status) avoids a receipt that reads
  // "Refunded" while the refund row still says "processing".
  bool get _refundProcessed => refundStatus == 'processed';
  bool get _refunding =>
      refundStatus != null &&
      refundStatus != 'processed' &&
      refundStatus != 'failed';

  @override
  Widget build(BuildContext context) {
    final color = _refundProcessed
        ? const Color(0xFFF59E0B)
        : _isSuccess
        ? CluvoTheme.success
        : status == 'failed'
        ? CluvoTheme.error
        : const Color(0xFFF59E0B);
    final icon = _refundProcessed
        ? Icons.replay_circle_filled_outlined
        : _isSuccess
        ? Icons.check_circle
        : status == 'failed'
        ? Icons.cancel
        : Icons.schedule;
    final title = _refundProcessed
        ? 'Refunded'
        : _isSuccess
        ? 'Payment Successful'
        : status == 'failed'
        ? 'Payment Failed'
        : _refunding
        ? 'Refund in progress'
        : _isRefunded
        ? 'Refunded'
        : 'Payment Pending';
    // When a refund exists, the headline figure is what the customer actually
    // gets back: the ticket only on a self-cancel (platform fee kept) or the
    // full amount when the organizer cancelled the event.
    final headlineAmount = (refundStatus != null && refundedAmountPaise != null)
        ? refundedAmountPaise!
        : amountPaise;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(18, 24, 18, 20),
          decoration: _cardDecoration(context),
          child: Column(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                formatRupees(headlineAmount),
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              if (refundStatus != null) ...[
                const SizedBox(height: 4),
                Text(
                  _refundProcessed
                      ? 'Refunded to you'
                      : (_refunding ? 'Refund in progress' : 'Refund failed'),
                  style: TextStyle(
                    fontSize: 12.5,
                    color: context.cluvoTextSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              DottedDivider(color: context.cluvoBorder),
              const SizedBox(height: 16),
              _eventRow(context),
              const SizedBox(height: 16),
              DottedDivider(color: context.cluvoBorder),
              const SizedBox(height: 16),
              _breakup(context),
              const SizedBox(height: 16),
              DottedDivider(color: context.cluvoBorder),
              const SizedBox(height: 16),
              _details(context),
            ],
          ),
        ),
        if (timeline.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
            decoration: _cardDecoration(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Activity',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 14),
                _activity(context),
              ],
            ),
          ),
        ],
      ],
    );
  }

  BoxDecoration _cardDecoration(BuildContext context) {
    return BoxDecoration(
      color: context.cluvoSurface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: context.cluvoBorder),
    );
  }

  Widget _eventRow(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 48,
            height: 48,
            child: (eventImageUrl != null && eventImageUrl!.isNotEmpty)
                ? CachedNetworkImage(
                    imageUrl: eventImageUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => _eventThumbFallback(),
                    placeholder: (_, _) =>
                        Container(color: context.cluvoChipFill),
                  )
                : _eventThumbFallback(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eventTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
              if (eventDateText != null && eventDateText!.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  eventDateText!,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: context.cluvoTextSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _eventThumbFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [CluvoTheme.primary, CluvoTheme.primaryLight],
        ),
      ),
      child: const Icon(
        Icons.local_activity_outlined,
        color: Colors.white70,
        size: 22,
      ),
    );
  }

  Widget _breakup(BuildContext context) {
    final rows = <Widget>[];
    if (platformFeePaise != null) {
      rows.add(
        _amountRow(
          context,
          'Ticket',
          formatRupees(amountPaise - platformFeePaise!),
        ),
      );
      rows.add(const SizedBox(height: 10));
      rows.add(
        _amountRow(
          context,
          'Platform fee',
          feeGstPaise != null && feeGstPaise! > 0
              ? '${formatRupees(platformFeePaise!)} (incl. GST ${formatRupees(feeGstPaise!)})'
              : formatRupees(platformFeePaise!),
          muted: true,
        ),
      );
    } else {
      rows.add(
        _amountRow(context, 'Amount', formatRupees(amountPaise), muted: true),
      );
    }
    return Column(
      children: [
        ...rows,
        const SizedBox(height: 12),
        Container(height: 1, color: context.cluvoBorder),
        const SizedBox(height: 12),
        _amountRow(context, 'Total', formatRupees(amountPaise), bold: true),
        if (refundStatus != null && refundedAmountPaise != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _amountRow(
              context,
              _refundProcessed ? 'Refunded to you' : 'Refund (processing)',
              formatRupees(refundedAmountPaise!),
              bold: true,
            ),
          ),
      ],
    );
  }

  Widget _amountRow(
    BuildContext context,
    String label,
    String value, {
    bool bold = false,
    bool muted = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: bold ? 15 : 13.5,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: muted ? context.cluvoTextSecondary : null,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 15 : 13.5,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color: muted ? context.cluvoTextSecondary : null,
          ),
        ),
      ],
    );
  }

  Widget _details(BuildContext context) {
    final r = <Widget>[];
    if (paymentId != null) r.add(_detailRow(context, 'Payment ID', paymentId!));
    if (orderId != null) r.add(_detailRow(context, 'Order ID', orderId!));
    if (razorpayId != null) {
      r.add(_detailRow(context, 'Razorpay ID', razorpayId!));
    }
    if (createdAtText != null) {
      r.add(_detailRow(context, 'Date', createdAtText!));
    }
    r.add(_statusRow(context, 'Status', _statusLabel()));
    if (refundStatus != null) {
      final label = _refundLabels[refundStatus] ?? refundStatus!;
      final value = (refundedAmountPaise != null && refundedAmountPaise! > 0)
          ? '$label · ${formatRupees(refundedAmountPaise!)}'
          : label;
      r.add(_statusRow(context, 'Refund', value));
    }
    return Column(
      children: [
        for (var i = 0; i < r.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          r[i],
        ],
      ],
    );
  }

  String _statusLabel() {
    if (_isRefunded) return 'Refunded';
    switch (status) {
      case 'success':
      case 'confirmed':
      case 'processed':
        return 'Success';
      case 'failed':
        return 'Failed';
      default:
        return 'Pending';
    }
  }

  Widget _detailRow(BuildContext context, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: context.cluvoTextSecondary),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _statusRow(BuildContext context, String label, String value) {
    final color = _refundProcessed
        ? const Color(0xFFF59E0B)
        : _isSuccess
        ? CluvoTheme.success
        : status == 'failed'
        ? CluvoTheme.error
        : const Color(0xFFF59E0B);
    return Row(
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: context.cluvoTextSecondary),
          ),
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.max,
            children: [
              Icon(
                _refundProcessed
                    ? Icons.replay
                    : _isSuccess
                    ? Icons.check_circle
                    : status == 'failed'
                    ? Icons.cancel
                    : Icons.schedule,
                size: 14,
                color: color,
              ),
              const SizedBox(width: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _activity(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < timeline.length; i++)
          _activityEntry(
            context,
            timeline[i],
            isLast: i == timeline.length - 1,
          ),
      ],
    );
  }

  Widget _activityEntry(
    BuildContext context,
    Map<String, dynamic> entry, {
    required bool isLast,
  }) {
    final type = entry['type'] as String? ?? '';
    final body = entry['body'] as String? ?? '';
    final rawDate = entry['created_at'] as String?;
    final isCompleted = type == 'refund_completed';
    final isRefund = type.startsWith('refund_');
    final color = isCompleted
        ? CluvoTheme.success
        : isRefund
        ? const Color(0xFFF59E0B)
        : CluvoTheme.primary;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    color: context.cluvoBorder,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 12 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    body,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (rawDate != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      formatDateTime(safeParseDate(rawDate)),
                      style: TextStyle(
                        fontSize: 11.5,
                        color: context.cluvoTextSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
