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
    final status = p['status'] as String? ?? 'pending';
    final refundStatus = p['refund_status'] as String?;
    final date = p['created_at'] as String?;
    final paymentId = p['id'] as String?;

    final refundLabels = {
      'processed': 'Refunded',
      'pending': 'Refund Processing',
      'queued': 'Refund Queued',
      'requested': 'Refund Requested',
      'failed': 'Refund Failed',
    };
    final refundLabel = refundStatus != null ? refundLabels[refundStatus] : null;
    final chipLabel = refundLabel ?? status[0].toUpperCase() + status.substring(1);
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
                ? (refundStatus == 'processed' ? Icons.assignment_turned_in : Icons.schedule)
                : payStatusIcon(status),
            color: chipColor,
            size: 20,
          ),
        ),
      ),
      title: title,
      subtitle: date != null ? formatDate(date) : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            amount == 0 ? 'Free' : '₹${(amount / 100).toStringAsFixed(0)}',
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
      onTap: paymentId != null ? () => context.push('/payments/$paymentId') : null,
    );
  }
}