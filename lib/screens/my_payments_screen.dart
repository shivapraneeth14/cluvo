import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme.dart';
import '../providers/activity_provider.dart';
import '../utils.dart';
import '../widgets/list_page_scaffold.dart';

class MyPaymentsScreen extends ConsumerWidget {
  const MyPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myPaymentsProvider);

    return ListPageScaffold(
      title: 'My Payments',
      onRefresh: () async {
        ref.invalidate(myPaymentsProvider);
        await ref.read(myPaymentsProvider.future);
      },
      child: async.when(
        data: (payments) {
          if (payments.isEmpty) {
            return const EmptyState(
              icon: Icons.payments_outlined,
              message: 'No payments yet.',
            );
          }
          return Column(
            children: [for (final p in payments) _buildPayCard(context, p)],
          );
        },
        loading: () => const SizedBox(
          height: 120,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (e, _) => Center(
          child: Text(
            'Could not load payments.',
            style: TextStyle(color: context.cluvoTextSecondary, fontSize: 13),
          ),
        ),
      ),
    );
  }

  Widget _buildPayCard(BuildContext context, Map<String, dynamic> p) {
    final reg = p['registrations'] as Map<String, dynamic>?;
    final ev = reg?['events'] as Map<String, dynamic>?;
    final title = ev?['title'] as String? ?? 'Unknown Event';
    final amount = (p['amount'] as num?)?.toDouble() ?? 0;
    final organizerShare = (p['organizer_share'] as num?)?.toDouble();
    final refundedAmount = (p['refunded_amount'] as num?)?.toDouble();
    final status = p['status'] as String? ?? 'pending';
    final refundStatus = p['refund_status'] as String?;
    final date = (status == 'success' || status == 'refunded')
        ? (p['updated_at'] as String? ?? p['created_at'] as String?)
        : (p['created_at'] as String?);
    final paymentId = p['id'] as String?;
    final isHistory = p['is_refund_history'] == true;

    // A refunded row shows what the buyer gets back, not the gross payment:
    // the recorded refund when we have it; otherwise the ticket price
    // (organizer_share) if they were issued a ticket — the platform fee is kept
    // for a self-cancel and an organizer-cancelled event alike; a never-confirmed
    // capture (organizer_share null) is refunded in full.
    var displayAmount = amount;
    if (refundStatus != null && refundStatus != 'failed') {
      if (refundedAmount != null && refundedAmount > 0) {
        displayAmount = refundedAmount;
      } else if (organizerShare != null) {
        displayAmount = organizerShare;
      }
    }

    final refundLabels = {
      'processed': 'Refunded',
      'pending': 'Refund Processing',
      'queued': 'Refund Queued',
      'requested': 'Refund Requested',
      'failed': 'Refund Failed',
    };
    final refundLabel = refundStatus != null
        ? refundLabels[refundStatus]
        : null;
    final chipLabel =
        refundLabel ?? status[0].toUpperCase() + status.substring(1);
    final chipColor = refundLabel != null
        ? (refundStatus == 'processed'
              ? Colors.green
              : refundStatus == 'failed'
              ? Colors.red
              : Colors.orange)
        : payStatusColor(status);

    return ActivityCard(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: chipColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Icon(
            refundLabel != null
                ? (refundStatus == 'processed'
                      ? Icons.assignment_turned_in
                      : Icons.schedule)
                : payStatusIcon(status),
            color: chipColor,
            size: 20,
          ),
        ),
      ),
      title: title,
      subtitle: isHistory
          ? [
              date != null ? formatDate(date) : null,
              'Previous refund',
            ].whereType<String>().join(' · ')
          : (date != null ? formatDate(date) : null),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            displayAmount == 0
                ? 'Free'
                : '₹${(displayAmount / 100).toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: chipColor,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: chipColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              chipLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: chipColor,
              ),
            ),
          ),
        ],
      ),
      // An archived refund points at a payment row that has since been reused
      // for a NEW sale — navigate to its immutable refund history detail view.
      onTap: paymentId != null
          ? () => context.push(isHistory ? '/refunds/$paymentId' : '/payments/$paymentId')
          : null,
    );
  }
}
