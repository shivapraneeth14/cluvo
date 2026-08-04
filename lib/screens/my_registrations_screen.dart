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
            final isEventCancelled = events?['status'] == 'cancelled';
            return r['deleted_at'] == null || isEventCancelled;
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

    String? refundNotice;
    if (isEventCancelled) {
      final raw = r['payments'];
      Map<String, dynamic>? payment;
      if (raw is Map<String, dynamic>) {
        payment = raw;
      } else if (raw is List && raw.isNotEmpty) {
        payment = raw.first as Map<String, dynamic>?;
      }
      final paymentStatus = payment?['status'] as String?;
      final refundStatus = payment?['refund_status'] as String?;
      if (paymentStatus == 'refunded') {
        refundNotice = 'Refunded';
      } else if (refundStatus == 'requested') {
        refundNotice = 'Refund in progress';
      } else {
        refundNotice = 'Event cancelled — money will be refunded';
      }
    }

    final subtitle = [
      formatDate(startDate),
      ?refundNotice,
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
          child: Icon(
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
          color: regStatusColor(context, status).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          status[0].toUpperCase() + status.substring(1),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: regStatusColor(context, status),
          ),
        ),
      ),
      onTap: eventId != null ? () => context.push('/events/$eventId') : null,
    );
  }
}