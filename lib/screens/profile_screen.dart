import 'package:flutter/material.dart';
import '../theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../widgets/notification_bell.dart';
import '../widgets/theme_toggle_button.dart';
import '../widgets/list_page_scaffold.dart';
import '../utils.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'CLUVO',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            color: CluvoTheme.primary,
          ),
        ),
        actions: const [ThemeToggleButton(), NotificationBell()],
      ),
      body: profile.when(
        data: (data) {
          final email = authState.session?.user.email ?? '';
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(profileProvider);
              await ref.read(profileProvider.future);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: CluvoTheme.primary.withValues(alpha: 0.15),
                    backgroundImage: data != null && data.avatarUrl != null && data.avatarUrl!.isNotEmpty
                        ? NetworkImage(data.avatarUrl!)
                        : null,
                    child: data == null || data.avatarUrl == null || data.avatarUrl!.isEmpty
                        ? Text(
                            email.isNotEmpty ? email[0].toUpperCase() : 'U',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: CluvoTheme.primary,
                            ),
                          )
                        : null,
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
                    style: TextStyle(color: context.cluvoTextSecondary, fontSize: 14),
                  ),
                  if (data != null && data.username != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '@${data.username}',
                      style: TextStyle(color: context.cluvoTextSecondary, fontSize: 13),
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
                        foregroundColor: CluvoTheme.primary,
                        side: BorderSide(color: CluvoTheme.primary),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: context.cluvoSurface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 16, color: context.cluvoTextSecondary),
                        const SizedBox(width: 8),
                        Text(
                          'Joined ${data != null ? formatDate(data.createdAt.toIso8601String()) : ''}',
                          style: TextStyle(
                              color: context.cluvoTextSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Your Activity',
                      style: TextStyle(
                        fontFamily: 'PlayfairDisplay',
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: context.cluvoTextPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ActivityCard(
                    leading: _menuLeading(Icons.groups_outlined),
                    title: 'Communities',
                    subtitle: "Communities you've joined",
                    onTap: () => context.push('/profile/communities'),
                  ),
                  ActivityCard(
                    leading: _menuLeading(Icons.event_available_outlined),
                    title: 'Registrations',
                    subtitle: 'Events you\u2019re registered for',
                    onTap: () => context.push('/profile/registrations'),
                  ),
                  ActivityCard(
                    leading: _menuLeading(Icons.payments_outlined),
                    title: 'Payments',
                    subtitle: 'Your payment history',
                    onTap: () => context.push('/profile/payments'),
                  ),
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
        loading: () => _buildSkeleton(context),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 40, color: context.cluvoTextSecondary),
                const SizedBox(height: 12),
                Text('Error: $e',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.cluvoTextSecondary)),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => ref.invalidate(profileProvider),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Tap to Retry'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: CluvoTheme.primary,
                    side: BorderSide(color: CluvoTheme.primary),
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

  Widget _menuLeading(IconData icon) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: CluvoTheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: CluvoTheme.primary, size: 22),
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 20),
        CircleAvatar(radius: 40, backgroundColor: context.cluvoChipFill),
        const SizedBox(height: 16),
        Center(child: Container(height: 16, width: 160, decoration: BoxDecoration(color: context.cluvoChipFill, borderRadius: BorderRadius.circular(4)))),
        const SizedBox(height: 6),
        Center(child: Container(height: 12, width: 200, decoration: BoxDecoration(color: context.cluvoChipFill, borderRadius: BorderRadius.circular(4)))),
        const SizedBox(height: 24),
        Container(
          height: 48,
          decoration: BoxDecoration(color: context.cluvoChipFill, borderRadius: BorderRadius.circular(16)),
        ),
        const SizedBox(height: 28),
        Container(height: 16, width: 120, decoration: BoxDecoration(color: context.cluvoChipFill, borderRadius: BorderRadius.circular(4))),
        const SizedBox(height: 12),
        Container(
          height: 76,
          decoration: BoxDecoration(color: context.cluvoChipFill, borderRadius: BorderRadius.circular(16)),
        ),
        const SizedBox(height: 12),
        Container(
          height: 76,
          decoration: BoxDecoration(color: context.cluvoChipFill, borderRadius: BorderRadius.circular(16)),
        ),
        const SizedBox(height: 12),
        Container(
          height: 76,
          decoration: BoxDecoration(color: context.cluvoChipFill, borderRadius: BorderRadius.circular(16)),
        ),
      ],
    );
  }
}