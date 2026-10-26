import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';
import '../providers/profile_provider.dart';
import '../supabase_client.dart';

class MainShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  bool _gracePromptShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybePromptGrace());
  }

  /// If the signed-in account is in its 30-day deletion grace period, show a
  /// one-time prompt right after login. User must choose: keep account or
  /// delete anyway. If they choose delete anyway, they are signed out and
  /// cannot use the app; deletion continues.
  Future<void> _maybePromptGrace() async {
    if (_gracePromptShown || !mounted) return;
    _gracePromptShown = true;
    try {
      final profile = await ref.read(profileProvider.future);
      if (profile == null || !profile.deletionPending || !mounted) return;
      final keep = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Your account is scheduled for deletion'),
          content: const Text(
            'Your account is scheduled for deletion. Do you want to keep your account or delete it anyway?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Delete anyway'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Keep my account'),
            ),
          ],
        ),
      );
      if (keep == true) {
        await _keepAccount();
        return;
      }
      // Delete anyway - do not cancel, sign out and block entry
      try {
        await supabase.auth.signOut();
      } catch (_) {}
      if (!mounted) return;
      context.go('/login');
    } catch (_) {
      // Profile may still be loading — fallback remains
    }
  }

  Future<void> _keepAccount() async {
    try {
      final res = await supabase.functions.invoke('cancel-account-deletion');
      if (res.data?['success'] == true) {
        ref.invalidate(profileProvider);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Welcome back — your account is kept.')),
        );
      }
    } catch (e) {
      final msg = e is FunctionException && e.details is Map
          ? ((e.details as Map)['error'] as String? ??
                'Could not restore your account.')
          : 'Could not restore your account. Please try again.';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(
              color: CluvoTheme.borderLavender,
              width: CluvoTheme.hairline,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: widget.navigationShell.currentIndex,
          onDestinationSelected: (index) =>
              widget.navigationShell.goBranch(index),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            _destination(
              index: 0,
              icon: Icons.home_outlined,
              selectedIcon: Icons.home_rounded,
              label: 'Home',
            ),
            _destination(
              index: 1,
              icon: Icons.groups_outlined,
              selectedIcon: Icons.groups,
              label: 'Communities',
            ),
            _destination(
              index: 2,
              icon: Icons.event_outlined,
              selectedIcon: Icons.event,
              label: 'Events',
            ),
            _destination(
              index: 3,
              icon: Icons.restaurant_outlined,
              selectedIcon: Icons.restaurant,
              label: 'Dine',
            ),
            _destination(
              index: 4,
              icon: Icons.person_outline,
              selectedIcon: Icons.person,
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  NavigationDestination _destination({
    required int index,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
  }) {
    return NavigationDestination(
      icon: Icon(icon),
      selectedIcon: Icon(selectedIcon),
      label: label,
    );
  }
}
