import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'main.dart';
import 'providers/auth_provider.dart';
import 'providers/consent_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/pending_route_provider.dart';
import 'providers/theme_provider.dart';
import 'theme.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/consent_gate_screen.dart';
import 'screens/main_shell.dart';
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';
import 'screens/communities_screen.dart';
import 'screens/community_detail_screen.dart';
import 'screens/events_screen.dart';
import 'screens/events_browse_screen.dart';
import 'screens/event_detail_screen.dart';
import 'screens/dine_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/communities_browse_screen.dart';
import 'screens/my_communities_screen.dart';
import 'screens/my_registrations_screen.dart';
import 'screens/my_payments_screen.dart';
import 'screens/payment_detail_screen.dart';
import 'screens/ticket_screen.dart';
import 'screens/wishlist_screen.dart';
import 'providers/location_provider.dart';

class CluvoApp extends ConsumerStatefulWidget {
  const CluvoApp({super.key});

  @override
  ConsumerState<CluvoApp> createState() => _CluvoAppState();
}

class _CluvoAppState extends ConsumerState<CluvoApp> {
  late GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = GoRouter(
      initialLocation: '/splash',
      redirect: _redirect,
      errorBuilder: (context, state) => Scaffold(
        backgroundColor: context.cluvoBackground,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.link_off,
                    size: 48,
                    color: context.cluvoTextSecondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Page not found: "${state.uri.toString()}"',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.cluvoTextSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      routes: [
        GoRoute(path: '/', redirect: (_, _) => '/splash'),
        GoRoute(
          path: '/splash',
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: '/login',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const LoginScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return SlideTransition(
                    position:
                        Tween<Offset>(
                          begin: const Offset(0, 1),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOut,
                          ),
                        ),
                    child: child,
                  );
                },
          ),
        ),
        GoRoute(
          path: '/signup',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const LoginScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return SlideTransition(
                    position:
                        Tween<Offset>(
                          begin: const Offset(0, 1),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOut,
                          ),
                        ),
                    child: child,
                  );
                },
          ),
        ),
        GoRoute(
          path: '/consent',
          builder: (context, state) => const ConsentGateScreen(),
        ),
        GoRoute(
          path: '/edit-profile',
          builder: (context, state) => const EditProfileScreen(),
        ),
        GoRoute(
          path: '/notifications',
          builder: (context, state) => const NotificationsScreen(),
        ),
        GoRoute(
          path: '/search',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: SearchScreen(initialQuery: state.uri.queryParameters['q']),
            transitionDuration: const Duration(milliseconds: 380),
            reverseTransitionDuration: const Duration(milliseconds: 300),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  final curved = CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                    reverseCurve: Curves.easeInCubic,
                  );
                  return FadeTransition(
                    opacity: curved,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.06),
                        end: Offset.zero,
                      ).animate(curved),
                      child: child,
                    ),
                  );
                },
          ),
        ),
        GoRoute(
          path: '/payments/:id',
          builder: (context, state) =>
              PaymentDetailScreen(paymentId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/ticket/:id',
          builder: (context, state) =>
              TicketScreen(registrationId: state.pathParameters['id']!),
        ),
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              MainShell(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/home',
                  builder: (context, state) => const HomeScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/communities',
                  builder: (context, state) => const CommunitiesScreen(),
                ),
                GoRoute(
                  path: '/communities/all',
                  builder: (context, state) => const CommunitiesBrowseScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/events',
                  builder: (context, state) => const EventsScreen(),
                ),
                GoRoute(
                  path: '/events/all',
                  builder: (context, state) => const EventsBrowseScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/dine',
                  builder: (context, state) => const DineScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/profile',
                  builder: (context, state) => const ProfileScreen(),
                  routes: [
                    GoRoute(
                      path: 'communities',
                      builder: (context, state) => const MyCommunitiesScreen(),
                    ),
                    GoRoute(
                      path: 'registrations',
                      builder: (context, state) =>
                          const MyRegistrationsScreen(),
                    ),
                    GoRoute(
                      path: 'payments',
                      builder: (context, state) => const MyPaymentsScreen(),
                    ),
                    GoRoute(
                      path: 'wishlist',
                      builder: (context, state) => const WishlistScreen(),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        // Detail screens live at the top level (outside the StatefulShellRoute)
        // so they can be pushed from any context — including root-level routes
        // like `/search`. Pushing a shell-branch route while another shell is
        // mounted below triggers a Navigator key collision, so these must not
        // be nested inside the shell branches.
        //
        // They must also be declared AFTER the shell route: go_router matches
        // top-level routes in declaration order (first non-empty wins) and does
        // not prefer static segments, so `/events/:id` declared earlier would
        // shadow the shell's literal `/events/all` listing route (and likewise
        // `/communities/:id` vs `/communities/all`).
        GoRoute(
          path: '/events/:id',
          builder: (context, state) =>
              EventDetailScreen(id: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/communities/:id',
          builder: (context, state) =>
              CommunityDetailScreen(id: state.pathParameters['id']!),
        ),
      ],
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(locationControllerProvider.notifier).detectOnLaunch();
    });
  }

  String? _redirect(BuildContext context, GoRouterState state) {
    final auth = ref.read(authProvider);
    final loggedIn = auth.session != null;
    final location = state.uri.toString();
    final pendingRoute = ref.read(pendingRouteProvider);
    final consent = ref.read(consentProvider);

    if (location == '/') return '/splash';

    final authPaths = ['/splash', '/login', '/signup'];

    if (!loggedIn && !authPaths.contains(location) && _isSharePath(location)) {
      ref.read(pendingRouteProvider.notifier).state = location;
      unawaited(savePendingRoute(location));
      return '/login';
    }

    if (loggedIn) {
      // If consent status unknown or not up to date, force consent gate
      if (consent.upToDate != true && location != '/consent') {
        return '/consent';
      }
      if (consent.upToDate == true && location == '/consent') {
        if (pendingRoute != null) {
          ref.read(pendingRouteProvider.notifier).state = null;
          unawaited(clearPendingRoute());
          return location == pendingRoute ? '/home' : pendingRoute;
        }
        return '/home';
      }
      if (pendingRoute != null && location != '/consent') {
        ref.read(pendingRouteProvider.notifier).state = null;
        unawaited(clearPendingRoute());
        return location == pendingRoute ? null : pendingRoute;
      }
      if (authPaths.contains(location)) {
        return '/home';
      }
    }
    if (!loggedIn && !authPaths.contains(location)) {
      return '/login';
    }
    return null;
  }

  bool _isSharePath(String location) =>
      location.startsWith('/communities') || location.startsWith('/events');

  /// Check server-side consent status for the current session.
  Future<void> _syncConsent() async {
    final notifier = ref.read(consentProvider.notifier);
    await notifier.check();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    ref.listen<AuthState>(authProvider, (_, next) {
      ref.read(notificationsRealtimeProvider).sync(next.session?.user.id);
      if (next.session != null && !next.session!.isExpired) {
        unawaited(
          _syncConsent().then((_) {
            if (mounted) _router.refresh();
          }),
        );
      }
      _router.refresh();
    });
    ref.listen<ConsentState>(consentProvider, (_, _) {
      if (mounted) _router.refresh();
    });
    ref
        .read(notificationsRealtimeProvider)
        .sync(ref.read(authProvider).session?.user.id);
    return MaterialApp.router(
      key: navigatorKey,
      title: 'Cluvo',
      debugShowCheckedModeBanner: false,
      theme: CluvoTheme.lightTheme,
      darkTheme: CluvoTheme.darkTheme,
      themeMode: themeMode,
      builder: (context, child) {
        ErrorWidget.builder = (errorDetails) => Scaffold(
          backgroundColor: context.cluvoBackground,
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: context.cluvoTextSecondary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Something went wrong. Please restart the app.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: context.cluvoTextSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        return child!;
      },
      routerConfig: _router,
    );
  }
}
