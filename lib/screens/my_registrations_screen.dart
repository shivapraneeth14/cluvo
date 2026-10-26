import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme.dart';
import '../providers/activity_provider.dart';
import '../utils.dart';
import '../widgets/list_page_scaffold.dart';

class MyRegistrationsScreen extends ConsumerWidget {
  const MyRegistrationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myRegistrationsProvider);

    return ListPageScaffold(
      title: 'My Registrations',
      onRefresh: () async {
        ref.invalidate(myRegistrationsProvider);
        await ref.read(myRegistrationsProvider.future);
      },
      child: async.when(
        data: (registrations) {
          final visible = registrations.where((r) {
            final events = r['events'] as Map<String, dynamic>?;
            return !isAbandonedCheckout(
              registration: r,
              payment: embeddedPayment(r),
              event: events,
            );
          }).toList();
          if (visible.isEmpty) {
            return const EmptyState(
              icon: Icons.event_available_outlined,
              message: 'No registrations yet.',
            );
          }
          return Column(
            children: [for (final r in visible) _buildRegCard(context, r)],
          );
        },
        loading: () => const SizedBox(
          height: 120,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (e, _) => Center(
          child: Text(
            'Could not load registrations.',
            style: TextStyle(color: context.cluvoTextSecondary, fontSize: 13),
          ),
        ),
      ),
    );
  }

  Widget _buildRegCard(BuildContext context, Map<String, dynamic> r) {
    final events = r['events'] as Map<String, dynamic>?;
    final title = events?['title'] as String? ?? 'Unknown Event';
    final startDate = events?['start_date'] as String?;
    final status = r['status'] as String? ?? 'pending';
    final eventId = r['event_id'] as String?;
    final isEventCancelled = events?['status'] == 'cancelled';

    Map<String, dynamic>? payment = embeddedPayment(r);
    final paymentStatus = payment?['status'] as String?;
    final refundStatus = payment?['refund_status'] as String?;
    final paidAmount = payment?['amount'] as num?;
    final refundedAmount = payment?['refunded_amount'] as num?;
    final platformFee = payment?['platform_fee'] as num?;
    final qrCode = r['qr_code'] as String?;

    final refundLabels = {
      'processed': 'Refunded',
      'pending': 'Refund processing',
      'queued': 'Refund queued',
      'requested': 'Refund in progress',
      'failed': 'Refund failed — support will contact you',
    };

    // Amount the buyer gets back: the recorded refund, else the full amount for
    // an organizer-cancelled event, else the ticket price (platform fee kept)
    // for a self-cancel.
    num? refundDisplay;
    if (refundedAmount is num && refundedAmount > 0) {
      refundDisplay = refundedAmount;
    } else if (isEventCancelled && paidAmount is num) {
      refundDisplay = paidAmount;
    } else if (paidAmount is num &&
        platformFee is num &&
        paidAmount - platformFee > 0) {
      refundDisplay = paidAmount - platformFee;
    } else if (paidAmount is num) {
      refundDisplay = paidAmount;
    }
    final amtText = (refundDisplay is num && refundDisplay > 0)
        ? ' ₹${(refundDisplay / 100).toStringAsFixed(0)}'
        : '';

    String? refundNotice;
    final effectiveRefundLabel = (refundStatus != null)
        ? refundLabels[refundStatus]
        : null;
    if (isEventCancelled) {
      if (refundStatus == 'processed') {
        refundNotice = 'Refunded$amtText';
      } else if (effectiveRefundLabel != null) {
        refundNotice = '$effectiveRefundLabel$amtText';
      } else {
        refundNotice = 'Event cancelled — money will be refunded';
      }
    } else if (status == 'cancelled' && paymentStatus == 'refunded') {
      refundNotice = 'Cancelled · refunded$amtText';
    } else if (status == 'cancelled' && effectiveRefundLabel != null) {
      refundNotice = 'Cancelled · $effectiveRefundLabel$amtText';
    }

    final hasTicket =
        status == 'confirmed' && qrCode != null && !isEventCancelled;

    final subtitle = [
      formatDate(startDate),
      ?refundNotice,
      if (hasTicket) 'Tap to view your ticket',
    ].join('\n');

    return ActivityCard(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: regStatusColor(context, status).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: hasTicket
              ? const Icon(
                  Icons.confirmation_number_outlined,
                  color: Colors.green,
                  size: 20,
                )
              : Icon(
                  regStatusIcon(status),
                  color: regStatusColor(context, status),
                  size: 20,
                ),
        ),
      ),
      title: title,
      subtitle: subtitle.isEmpty ? null : subtitle,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: (hasTicket ? Colors.green : regStatusColor(context, status))
              .withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          hasTicket ? 'Ticket' : status[0].toUpperCase() + status.substring(1),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: hasTicket ? Colors.green : regStatusColor(context, status),
          ),
        ),
      ),
      onTap: hasTicket
          ? () => context.push('/ticket/${r['id']}')
          : eventId != null
          ? () => context.push('/events/$eventId')
          : null,
    );
  }
}
