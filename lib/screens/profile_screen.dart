import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/community_provider.dart';
import '../widgets/notification_bell.dart';
import '../models/models.dart';
import '../supabase_client.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  int _profileTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final authState = ref.watch(authProvider);
    final myCommunities = ref.watch(myCommunitiesProvider);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'CLUVO',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            color: const Color(0xFFC2185B),
          ),
        ),
        actions: [const NotificationBell()],
      ),
      body: profile.when(
        data: (data) {
          final email = authState.session?.user.email ?? '';
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(profileProvider);
              ref.invalidate(myCommunitiesProvider);
              await ref.read(profileProvider.future);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: const Color(0xFFC2185B).withValues(alpha: 0.15),
                        backgroundImage: data != null && data.avatarUrl != null && data.avatarUrl!.isNotEmpty
                            ? NetworkImage(data.avatarUrl!)
                            : null,
                        child: data == null || data.avatarUrl == null || data.avatarUrl!.isEmpty
                            ? Text(
                                email.isNotEmpty ? email[0].toUpperCase() : 'U',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFC2185B),
                                ),
                              )
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    data != null
                        ? '${data.firstName ?? ''} ${data.lastName ?? ''}'
                        : email,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: TextStyle(color: Colors.grey[500], fontSize: 14),
                  ),
                  if (data != null && data.username != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '@${data.username}',
                      style: TextStyle(color: Colors.grey[400], fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/edit-profile'),
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Edit Profile', style: TextStyle(fontSize: 14)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFC2185B),
                        side: const BorderSide(color: Color(0xFFC2185B)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today,
                              size: 16, color: Colors.grey[500]),
                          const SizedBox(width: 8),
                          Text(
                            'Joined ${data != null ? _formatDate(data.createdAt.toIso8601String()) : ''}',
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildTabBar(),
                  const SizedBox(height: 16),
                  if (_profileTabIndex == 0)
                    _buildCommunitiesTab(myCommunities)
                  else if (_profileTabIndex == 1)
                    _buildRegistrationsTab(authState)
                  else
                    _buildPaymentsTab(authState),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await ref.read(authProvider.notifier).signOut();
                        if (context.mounted) context.go('/login');
                      },
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text('Sign Out'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
        loading: () => _buildSkeleton(),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 40, color: Colors.grey),
                const SizedBox(height: 12),
                Text('Error: $e',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600])),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    ref.invalidate(profileProvider);
                    ref.invalidate(myCommunitiesProvider);
                  },
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Tap to Retry'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFC2185B),
                    side: const BorderSide(color: Color(0xFFC2185B)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        ),
      );
    }

  Widget _buildTabBar() {
    final tabs = ['Communities', 'Registrations', 'Payments'];
    return Row(
      children: tabs.asMap().entries.map((entry) {
        final idx = entry.key;
        final label = entry.value;
        final selected = _profileTabIndex == idx;
        return GestureDetector(
          onTap: () => setState(() => _profileTabIndex = idx),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: selected ? const Color(0xFF1976D2) : Colors.transparent,
                  width: 2.5,
                ),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? const Color(0xFF1976D2) : Colors.grey[500],
              ),
            ),
          ),
        );
          }).toList(),
    );
  }

  Widget _buildCommunitiesTab(AsyncValue<List<Community>> myCommunities) {
    return myCommunities.when(
      data: (communities) {
        if (communities.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            ...communities.map((c) => _buildCommunityCard(context, c)),
          ],
        );
      },
      loading: () => const SizedBox(
        height: 40,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          children: [
            Text('Could not load communities.',
                style: TextStyle(color: Colors.grey[500], fontSize: 13)),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => ref.invalidate(myCommunitiesProvider),
              icon: const Icon(Icons.refresh, size: 14),
              label: const Text('Retry', style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegistrationsTab(AuthState authState) {
    final userId = authState.session?.user.id;
    if (userId == null) return SizedBox.shrink();

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: supabase
          .from('registrations')
          .select('*, events!inner(title, start_date, status, communities!inner(name)), payments(status, refund_status)')
          .eq('user_id', userId)
          .eq('events.communities.is_hidden', false)
          .order('registered_at', ascending: false),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: 80,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Could not load registrations.',
                style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          );
        }
        final registrations = snapshot.data ?? [];
        if (registrations.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Center(
              child: Text('No registrations yet.',
                  style: TextStyle(color: Colors.grey[400], fontSize: 13)),
            ),
          );
        }
        return Column(
          children: registrations.map((r) {
            final events = r['events'] as Map<String, dynamic>?;
            final title = events?['title'] as String? ?? 'Unknown Event';
            final startDate = events?['start_date'] as String?;
            final status = r['status'] as String? ?? 'pending';
            final eventId = r['event_id'] as String?;
            final isEventCancelled = events?['status'] == 'cancelled';
            if (r['deleted_at'] != null && !isEventCancelled) {
              return const SizedBox.shrink();
            }

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

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                onTap: eventId != null ? () => context.push('/events/$eventId') : null,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _regStatusColor(status).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Icon(
                            _regStatusIcon(status),
                            color: _regStatusColor(status),
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600)),
                            if (startDate != null)
                              Text(_formatDate(startDate),
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey[500])),
                            if (refundNotice != null) ...[
                              const SizedBox(height: 4),
                              Text(refundNotice,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey[600])),
                            ],
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _regStatusColor(status).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          status[0].toUpperCase() + status.substring(1),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _regStatusColor(status),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildPaymentsTab(AuthState authState) {
    final userId = authState.session?.user.id;
    if (userId == null) return SizedBox.shrink();

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: supabase
          .from('payments')
          .select('*, registrations!inner(user_id, events!inner(title, start_date))')
          .eq('registrations.user_id', userId)
          .order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: 80,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Could not load payments.',
                style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          );
        }
        final payments = snapshot.data ?? [];
        if (payments.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Center(
              child: Text('No payments yet.',
                  style: TextStyle(color: Colors.grey[400], fontSize: 13)),
            ),
          );
        }
        return Column(
          children: payments.map((p) {
            final reg = p['registrations'] as Map<String, dynamic>?;
            final ev = reg?['events'] as Map<String, dynamic>?;
            final title = ev?['title'] as String? ?? 'Unknown Event';
            final amount = (p['amount'] as num?)?.toDouble() ?? 0;
            final status = p['status'] as String? ?? 'pending';
            final date = p['created_at'] as String?;
            final paymentId = p['id'] as String?;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                onTap: paymentId != null ? () => context.push('/payments/$paymentId') : null,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _payStatusColor(status).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Icon(
                            _payStatusIcon(status),
                            color: _payStatusColor(status),
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600)),
                            if (date != null)
                              Text(_formatDate(date),
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey[500])),
                          ],
                        ),
                      ),
                      Text(
                        amount == 0 ? 'Free' : '₹${(amount / 100).toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _payStatusColor(status),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _payStatusColor(status).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          status[0].toUpperCase() + status.substring(1),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _payStatusColor(status),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            );
          }).toList(),
        );
      },
    );
  }

  Color _regStatusColor(String status) {
    switch (status) {
      case 'confirmed':
        return Colors.green;
      case 'attended':
        return Colors.blue;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  IconData _regStatusIcon(String status) {
    switch (status) {
      case 'confirmed':
        return Icons.check_circle_outline;
      case 'attended':
        return Icons.star_outline;
      case 'cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.schedule;
    }
  }

  Color _payStatusColor(String status) {
    switch (status) {
      case 'success':
        return Colors.green;
      case 'refunded':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  IconData _payStatusIcon(String status) {
    switch (status) {
      case 'success':
        return Icons.check_circle_outline;
      case 'refunded':
        return Icons.replay_outlined;
      case 'failed':
        return Icons.error_outline;
      default:
        return Icons.schedule;
    }
  }

  Widget _buildSkeleton() {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 20),
        CircleAvatar(radius: 40, backgroundColor: Colors.grey[200]),
        const SizedBox(height: 16),
        Center(child: Container(height: 16, width: 160, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)))),
        const SizedBox(height: 6),
        Center(child: Container(height: 12, width: 200, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)))),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Container(height: 14, width: 120, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4))),
          ),
        ),
      ],
    );
  }

  Widget _buildCommunityCard(BuildContext context, Community c) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => context.push('/communities/${c.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFC2185B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    c.name.isNotEmpty
                        ? c.name[0].toUpperCase()
                        : 'C',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFC2185B),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (c.city != null || c.country != null)
                      Text(
                        '${c.city ?? ''}${c.city != null && c.country != null ? ', ' : ''}${c.country ?? ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                '${c.memberCount} members',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[400],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
