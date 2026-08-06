import 'package:flutter/foundation.dart';
import '../theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config.dart';
import '../supabase_client.dart';
import '../services/razorpay_web.dart';
import '../widgets/community_photo_grid.dart';
import '../widgets/event_discussion.dart';
import '../widgets/wishlist_button.dart';
import '../providers/wishlist_provider.dart';
import '../utils.dart';

class EventDetailScreen extends StatefulWidget {
  final String id;
  const EventDetailScreen({super.key, required this.id});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  Map<String, dynamic>? _event;
  List<Map<String, dynamic>> _media = [];
  bool _loading = true;
  String? _error;
  bool _isRegistered = false;
  String? _registrationStatus;
  bool _checkingRegistration = true;
  bool _registering = false;
  bool _processingPayment = false;
  bool _pollActive = false;
  bool _discussionEnabled = false;
  bool _discussionRestricted = false;
  bool _isAdmin = false;
  String _selectedSection = 'discussion';
  int _descTabIndex = 0;
  Razorpay? _razorpay;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _razorpay = Razorpay();
      _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
      _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
      _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    }
    _load();
  }

  @override
  void dispose() {
    if (!kIsWeb) _razorpay?.clear();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    debugPrint('Razorpay success: payment_id=${response.paymentId}, order_id=${response.orderId}');
    if (!mounted) return;
    setState(() => _processingPayment = true);
    _pollRegistrationStatus();
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint('Razorpay error: code=${response.code}, message=${response.message}');
    if (!mounted) return;
    setState(() {
      _processingPayment = false;
      _registering = false;
    });
    if (response.code == Razorpay.PAYMENT_CANCELLED) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment cancelled. You can try again.'), backgroundColor: Colors.orange),
      );
      _cleanupPendingBooking();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response.message ?? 'Payment failed. Try again.'), backgroundColor: Colors.red[700]),
      );
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint('Razorpay external wallet: ${response.walletName}');
    if (!mounted) return;
    setState(() => _processingPayment = true);
    _pollRegistrationStatus();
  }

  Future<void> _pollRegistrationStatus() async {
    _pollActive = true;
    for (var i = 0; i < 30; i++) {
      if (!_pollActive) return;
      await Future.delayed(const Duration(seconds: 2));
      try {
        final session = supabase.auth.currentSession;
        if (session == null) continue;
        final res = await supabase
            .from('registrations')
            .select('status')
            .eq('event_id', widget.id)
            .eq('user_id', session.user.id)
            .maybeSingle();
        if (res != null && res['status'] == 'confirmed') {
          _pollActive = false;
          setState(() {
            _isRegistered = true;
            _processingPayment = false;
            _registering = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Registration confirmed!'), backgroundColor: Color(0xFF10B981)),
            );
          }
          return;
        }
        if (res != null && res['status'] == 'cancelled') {
          _pollActive = false;
          setState(() => _processingPayment = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Registration could not be completed.'), backgroundColor: Colors.red[700]),
            );
          }
          return;
        }
      } catch (_) {
        // Retry on next iteration
      }
    }
    _pollActive = false;
    if (!mounted) return;
    setState(() => _processingPayment = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Payment verification taking longer than expected. Check your registrations.'), backgroundColor: Colors.orange),
    );
  }

  Future<void> _load() async {
    try {
      final session = supabase.auth.currentSession;
      final eventFuture = supabase
          .from('events')
          .select('*, communities!inner(name, community_avatar_url)')
          .eq('id', widget.id)
          .eq('communities.is_hidden', false)
          .inFilter('status', ['published', 'completed', 'cancelled'])
          .single();
      final mediaFuture = supabase
          .from('media')
          .select('*')
          .eq('mediable_type', 'event')
          .eq('mediable_id', widget.id)
          .order('sort_order');

      bool registered = false;
      bool isAdmin = false;
      if (session != null) {
        final results = await Future.wait([
          eventFuture,
          mediaFuture,
          supabase
              .from('registrations')
              .select('id, status')
              .eq('event_id', widget.id)
              .eq('user_id', session.user.id)
              .maybeSingle(),
        ]).timeout(const Duration(seconds: 30));
        if (!mounted) return;
        final regData = results[2] as Map<String, dynamic>?;
        registered = regData?['status'] == 'confirmed';
        _registrationStatus = regData?['status'] as String?;
        final event = results[0] as Map<String, dynamic>?;
        if (event != null) {
          getParsedDate(event, 'start_date');
          getParsedDate(event, 'end_date');
          final communityId = event['community_id'] as String?;
          if (communityId != null) {
            final memberRes = await supabase
                .from('community_members')
                .select('role')
                .eq('community_id', communityId)
                .eq('user_id', session.user.id)
                .maybeSingle();
            isAdmin = memberRes != null &&
                ['OWNER', 'ORGANIZER', 'MODERATOR']
                    .contains(memberRes['role'] as String?);
          }
        }
        setState(() {
          _event = event;
          _media = (results[1] as List).cast<Map<String, dynamic>>();
          _isRegistered = registered;
          _registrationStatus = _registrationStatus;
          _isAdmin = isAdmin;
          _discussionEnabled = (event?['discussion_enabled'] as bool?) ?? false;
          _discussionRestricted = (event?['discussion_restricted'] as bool?) ?? false;
          _loading = false;
          _checkingRegistration = false;
        });
      } else {
        final results = await Future.wait([eventFuture, mediaFuture]).timeout(const Duration(seconds: 30));
        if (!mounted) return;
        final event = results[0] as Map<String, dynamic>?;
        if (event != null) {
          getParsedDate(event, 'start_date');
          getParsedDate(event, 'end_date');
        }
        setState(() {
          _event = event;
          _media = (results[1] as List).cast<Map<String, dynamic>>();
          _loading = false;
          _checkingRegistration = false;
        });
      }


    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
        _checkingRegistration = false;
      });
    }
  }

  Future<void> _cleanupPendingBooking() async {
    try {
      final res = await supabase.functions
          .invoke('cleanup-booking', body: {'event_id': widget.id})
          .timeout(const Duration(seconds: 15));
      if (mounted && res.data != null && res.data['cleaned'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pending booking cancelled.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint('Cleanup booking failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not clean up your booking — it will auto-clear in a few minutes.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
    if (!mounted) return;
    setState(() {
      _registrationStatus = null;
    });
  }

  // Temporarily unused while paid registration shows "Coming Soon"
  // pending the Razorpay web integration fix.
  // ignore: unused_element
  Future<void> _payForEvent() async {
    if (_registering || _processingPayment) return;
    setState(() => _registering = true);
    try {
      final session = supabase.auth.currentSession;
      if (session == null) {
        setState(() => _registering = false);
        return;
      }

      if (AppConfig.razorpayKeyId.isEmpty) {
        _showError('Payment is not configured. Please contact support.');
        setState(() => _registering = false);
        return;
      }

      // Create booking + payment order in a single call
      final paymentRes = await supabase.functions
          .invoke('create-payment', body: {'event_id': widget.id})
          .timeout(const Duration(seconds: 30));
      if (!mounted) return;
      final registrationId = paymentRes.data['registration_id'] as String?;
      final orderId = paymentRes.data['razorpay_order_id'] as String?;
      final amount = paymentRes.data['amount'] as int?;
      if (registrationId == null || orderId == null || amount == null) {
        _showError(paymentRes.data['error'] as String? ?? 'Failed to create payment.');
        setState(() => _registering = false);
        return;
      }

      // Open Razorpay Checkout
      final userEmail = session.user.email ?? '';
      final userPhone = session.user.phone ?? '';

      setState(() {
        _registering = false;
        _processingPayment = true;
      });

      final options = {
        'key': AppConfig.razorpayKeyId,
        'amount': amount,
        'currency': 'INR',
        'order_id': orderId,
        'name': 'Cluvo',
        'description': _event?['title'] ?? 'Event Registration',
        'prefill': {'contact': userPhone, 'email': userEmail},
        'theme': {'color': '#C2185B'},
      };

      // Safety timer: if checkout doesn't complete in 90s, reset state
      Future.delayed(const Duration(seconds: 90), () {
        if (mounted && _pollActive) {
          _pollActive = false;
          setState(() {
            _processingPayment = false;
            _registering = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Confirmation timed out. Pull to refresh.'), backgroundColor: Colors.orange),
          );
        }
      });

      if (kIsWeb) {
        await openRazorpayCheckoutWeb(
          options: options,
          onSuccess: _handlePaymentSuccess,
          onError: _handlePaymentError,
        );
      } else {
        _razorpay?.open(options);
      }
    } catch (e) {
      debugPrint('Payment flow error: $e');
      if (!mounted) return;
      _showError('Payment failed. Please check your connection and try again.');
      setState(() {
        _registering = false;
        _processingPayment = false;
      });
    }
  }

  Future<void> _register() async {
    if (_registering) return;
    setState(() => _registering = true);
    try {
      final session = supabase.auth.currentSession;
      if (session == null) {
        setState(() => _registering = false);
        return;
      }
      final res = await supabase.functions
          .invoke(
            'register-for-event',
            body: {'event_id': widget.id},
          )
          .timeout(const Duration(seconds: 30));
      if (!mounted) return;
      if (res.data['success'] == true) {
        setState(() {
          _isRegistered = true;
          _registrationStatus = 'confirmed';
          _event!['booked_count'] = ((_event!['booked_count'] as num?) ?? 0) + 1;
        });
      } else {
        _showError(res.data['error'] ?? 'Registration failed.');
      }
    } catch (e) {
      if (!mounted) return;
      _showError('Something went wrong. Try again.');
    }
    if (mounted) setState(() => _registering = false);
  }

  Future<void> _cancelRegistration() async {
    if (_registering) return;
    setState(() => _registering = true);
    try {
      final res = await supabase.functions
          .invoke(
            'cancel-registration',
            body: {'event_id': widget.id},
          )
          .timeout(const Duration(seconds: 30));
      if (!mounted) return;
      if (res.data['success'] == true) {
        setState(() {
          _isRegistered = false;
          _registrationStatus = 'cancelled';
          _event!['booked_count'] = ((_event!['booked_count'] as num?) ?? 1) - 1;
        });
      } else {
        _showError(res.data['error'] ?? 'Cancellation failed.');
      }
    } catch (e) {
      if (!mounted) return;
      _showError('Something went wrong. Try again.');
    }
    if (mounted) setState(() => _registering = false);
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red[700]),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _checkingRegistration) {
      return Scaffold(body: _buildSkeleton());
    }

    if (_error != null || _event == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/communities');
              }
            },
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 40, color: context.cluvoTextSecondary),
                const SizedBox(height: 12),
                Text(_error != null ? 'Error: $_error' : 'Not found',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.cluvoTextSecondary)),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    _loading = true;
                    _checkingRegistration = true;
                    _load();
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
      );
    }

    final e = _event!;
    final title = e['title'] as String;
    final price = (e['price'] as num?) ?? 0;
    final capacity = e['capacity'] as int?;
    final booked = (e['booked_count'] as num?) ?? 0;
    final isFull = capacity != null && booked >= capacity;
    final eventStatus = e['status'] as String? ?? 'published';
    final start = e['start_date'] as String?;
    final closed = start != null && DateTime.parse(start).isBefore(DateTime.now());
    final communityName =
        (e['communities'] as Map<String, dynamic>?)?['name'] as String?;
    final communityAvatarUrl =
        (e['communities'] as Map<String, dynamic>?)?['community_avatar_url']
            as String?;

    return Scaffold(
      backgroundColor: context.cluvoBackground,
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: CustomScrollView(
                slivers: [
                  // ── App bar: back + share ─────────────────────────────
                  SliverAppBar(
                    pinned: true,
                    elevation: 0,
                    scrolledUnderElevation: 0,
                    backgroundColor: context.cluvoBackground,
                    foregroundColor: context.cluvoTextPrimary,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/communities');
                        }
                      },
                    ),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.share_outlined),
                        onPressed: () {
                          final url = buildShareUrl('events', widget.id);
                          Share.share('Check out $title on Cluvo!\n$url',
                              subject: 'Check out $title on Cluvo');
                        },
                      ),
                      WishlistButton(type: wishlistEvent, id: widget.id),
                      const SizedBox(width: 4),
                    ],
                  ),

                  // ── Hero: floating rounded image, title set into photo ─
                  SliverToBoxAdapter(child: _buildHero(e)),

                  // ── Content sheet ──────────────────────────────────────
                  SliverToBoxAdapter(
                    child: _buildSheet(
                        e, communityName, communityAvatarUrl, price),
                  ),

                  // ── Section body ───────────────────────────────────────
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                    sliver: _selectedSection == 'photos'
                        ? SliverToBoxAdapter(
                            child: CommunityPhotoGrid(media: _media),
                          )
                        : SliverToBoxAdapter(child: _buildDiscussionSection()),
                  ),
                ],
              ),
            ),
          ),

          // ── Floating bottom bar: price + action ─────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              decoration: BoxDecoration(
                color: context.cluvoSurface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Price',
                            style: TextStyle(
                              fontSize: 11,
                              color: context.cluvoTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            price > 0
                                ? '₹${(price / 100).toStringAsFixed(0)}'
                                : 'Free',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      _buildActionButton(price, isFull, eventStatus, closed),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── HERO — floating rounded image with title set into the photo ─────────

  Widget _buildHero(Map<String, dynamic> e) {
    final imageUrl = e['image_url'] as String?;
    final title = e['title'] as String;
    final start = e['start_date'] as String?;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        height: 300,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              imageUrl != null && imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => _buildBannerFallback(title),
                    )
                  : _buildBannerFallback(title),

              // Scrim for text legibility — stronger toward the bottom
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black38,
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black87,
                    ],
                    stops: [0.0, 0.28, 0.55, 1.0],
                  ),
                ),
              ),

              // Title + date, set directly into the image
              Positioned(
                left: 20,
                right: 20,
                bottom: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'PlayfairDisplay',
                        fontSize: 30,
                        height: 1.1,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        shadows: [
                          Shadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 2)),
                          Shadow(color: Colors.black26, blurRadius: 14, offset: Offset(0, 6)),
                        ],
                      ),
                    ),
                    if (start != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined,
                              size: 14, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(
                            _formatDateTime(e, 'start_date'),
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              shadows: [
                                Shadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 2)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── CONTENT SHEET — chips, description, segmented control ───────────────

  Widget _buildSheet(
      Map<String, dynamic> e, String? communityName, String? communityAvatarUrl, num price) {
    final location = e['location'] as String?;
    final lat = (e['latitude'] as num?)?.toDouble();
    final lng = (e['longitude'] as num?)?.toDouble();
    final start = e['start_date'] as String?;
    final capacity = e['capacity'] as int?;
    final booked = (e['booked_count'] as num?) ?? 0;

    final chips = <Widget>[
      if (start != null)
        _infoChip(Icons.calendar_today_outlined, _formatDateTime(e, 'start_date')),
      if (location != null && location.isNotEmpty)
        _locationChip(location, lat: lat, lng: lng),
      if (communityName != null)
        _communityChip(communityName, communityAvatarUrl),
      _priceChip(price),
      if (capacity != null) _infoChip(Icons.people_outline, '$booked/$capacity spots'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: context.cluvoBackground,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: chips.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => chips[i],
              ),
            ),
            if (e['description'] != null) ...[
              const SizedBox(height: 20),
              ..._buildDescSection(e['description'] as String),
            ],
            const SizedBox(height: 24),
            _buildSegmentedControl(),
          ],
        ),
      ),
    );
  }

  Widget _locationChip(String value, {double? lat, double? lng}) {
    Widget chip = _infoChip(Icons.location_on_outlined, value);
    if (lat == null || lng == null) return chip;
    return GestureDetector(
      onTap: () => _openInGoogleMaps(value, lat, lng),
      child: chip,
    );
  }

  Future<void> _openInGoogleMaps(String label, double lat, double lng) async {
    final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    final labelSheet = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    );
    if (!mounted) return;
    final open = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: context.cluvoBackground,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: context.cluvoPrimaryText.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text('Open location', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.cluvoPrimaryText)),
              const SizedBox(height: 8),
              labelSheet,
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.purple.shade800),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.map_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Open in Google Maps'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (open == true) {
      try {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }

  Widget _infoChip(IconData icon, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.cluvoChipFill,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: context.cluvoPrimaryText),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 170),
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: context.cluvoTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _communityChip(String name, String? avatarUrl) {
    final showAvatar = avatarUrl != null && avatarUrl.isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.cluvoChipFill,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showAvatar)
            ClipOval(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CachedNetworkImage(
                  imageUrl: avatarUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => Icon(
                    Icons.groups_outlined,
                    size: 15,
                    color: context.cluvoPrimaryText,
                  ),
                ),
              ),
            )
          else
            Icon(Icons.groups_outlined, size: 15, color: context.cluvoPrimaryText),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 170),
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: context.cluvoTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceChip(num price) {
    final paid = price > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: paid
            ? CluvoTheme.primary.withValues(alpha: 0.1)
            : CluvoTheme.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            paid ? Icons.currency_rupee : Icons.volunteer_activism_outlined,
            size: 15,
            color: paid ? CluvoTheme.primary : CluvoTheme.success,
          ),
          const SizedBox(width: 6),
          Text(
            paid ? '₹${(price / 100).toStringAsFixed(0)}' : 'Free',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: paid ? CluvoTheme.primary : CluvoTheme.success,
            ),
          ),
        ],
      ),
    );
  }

  // ── SEGMENTED CONTROL — animated underline instead of pill toggle ───────

  Widget _buildSegmentedControl() {
    return Row(
      children: [
        _segmentTab('Discussion', 'discussion'),
        const SizedBox(width: 28),
        _segmentTab('Photos', 'photos'),
      ],
    );
  }

  Widget _segmentTab(String label, String section) {
    final selected = _selectedSection == section;
    return GestureDetector(
      onTap: () => setState(() => _selectedSection = section),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? CluvoTheme.primary : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'PlayfairDisplay',
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: selected ? context.cluvoTextPrimary : context.cluvoTextSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(num price, bool isFull, String eventStatus, bool closed) {
    if (eventStatus == 'cancelled') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Event Cancelled',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.red,
              ),
            ),
            if (_registrationStatus != null) ...[
              const SizedBox(height: 4),
              Text(
                _registrationStatus == 'confirmed'
                    ? 'Your payment has been refunded.'
                    : 'This event has been cancelled.',
                style: TextStyle(fontSize: 12, color: Colors.red[700]),
              ),
            ],
          ],
        ),
      );
    }

    if (eventStatus == 'completed') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: _registrationStatus == 'confirmed' || _registrationStatus == 'attended'
              ? Colors.green.withValues(alpha: 0.1)
              : context.cluvoChipFill,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          _registrationStatus == 'confirmed' || _registrationStatus == 'attended'
              ? 'Thank you for coming!'
              : 'Event Ended',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _registrationStatus == 'confirmed' || _registrationStatus == 'attended'
                ? Colors.green
                : context.cluvoTextSecondary,
          ),
        ),
      );
    }

    if (_isRegistered) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, size: 16, color: Colors.green),
                const SizedBox(width: 6),
                const Text(
                  'Registered',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 36,
            child: OutlinedButton(
              onPressed: _registering ? null : _cancelRegistration,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _registering
                  ? const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red),
                    )
                  : const Text('Cancel', style: TextStyle(fontSize: 13)),
            ),
          ),
        ],
      );
    }

    if (closed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: context.cluvoChipFill,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          'Event Closed',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: context.cluvoTextSecondary,
          ),
        ),
      );
    }

    if (isFull && !_isRegistered) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: context.cluvoChipFill,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          'Event Full',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: context.cluvoTextSecondary,
          ),
        ),
      );
    }

    if (price > 0) {
      return SizedBox(
        height: 44,
        child: ElevatedButton.icon(
          onPressed: null,
          icon: (_registering || _processingPayment)
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.payment, size: 18),
          label: Text(
            (_registering || _processingPayment)
                ? 'Processing…'
                : 'Coming Soon',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFC2185B),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 28),
          ),
        ),
      );
    }

    return SizedBox(
      height: 44,
      child: ElevatedButton.icon(
        onPressed: _registering ? null : _register,
        icon: _registering
            ? const SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.event, size: 18),
        label: const Text(
          'Register',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFC2185B),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 28),
        ),
      ),
    );
  }

  Widget _buildBannerFallback(String title) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFC2185B), Color(0xFFE0407A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          title.isNotEmpty ? title[0].toUpperCase() : 'E',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 56,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      children: [
        const SizedBox(height: kToolbarHeight + 8),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Container(
            height: 300,
            decoration: BoxDecoration(
              color: context.cluvoChipFill,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: List.generate(3, (i) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Container(
                        height: 36,
                        width: 90,
                        decoration: BoxDecoration(
                          color: context.cluvoChipFill,
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                    )),
              ),
              const SizedBox(height: 20),
              Container(
                  height: 14,
                  width: double.infinity,
                  decoration: BoxDecoration(
                      color: context.cluvoChipFill,
                      borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 12),
              Container(
                  height: 14,
                  width: 240,
                  decoration: BoxDecoration(
                      color: context.cluvoChipFill,
                      borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 24),
              ...List.generate(4, (_) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                        height: 14,
                        width: double.infinity,
                        decoration: BoxDecoration(
                            color: context.cluvoChipFill,
                            borderRadius: BorderRadius.circular(4))),
                  )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDiscussionSection() {
    final session = supabase.auth.currentSession;
    if (session == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 40, color: context.cluvoTextSecondary),
              const SizedBox(height: 12),
              Text('Sign in to join the discussion.',
                  style: TextStyle(color: context.cluvoTextSecondary)),
            ],
          ),
        ),
      );
    }
    return SizedBox(
      height: 400,
      child: EventDiscussion(
        eventId: widget.id,
        communityId: _event?['community_id'] as String?,
        discussionEnabled: _discussionEnabled,
        discussionRestricted: _discussionRestricted,
        currentUserId: session.user.id,
        isAdmin: _isAdmin,
      ),
    );
  }

  List<MapEntry<String, String>> _parseDescSections(String description) {
    final sections = <MapEntry<String, String>>[];
    final lines = description.split('\n');
    String? currentTitle;
    final buf = StringBuffer();
    for (final line in lines) {
      if (line.startsWith('## ')) {
        if (currentTitle != null) {
          sections.add(MapEntry(currentTitle, buf.toString().trim()));
        }
        currentTitle = line.substring(3).trim();
        buf.clear();
      } else if (currentTitle != null) {
        if (buf.isNotEmpty) buf.write('\n');
        buf.write(line);
      }
    }
    if (currentTitle != null) {
      sections.add(MapEntry(currentTitle, buf.toString().trim()));
    }
    return sections;
  }

  List<Widget> _buildDescSection(String description) {
    final sections = _parseDescSections(description);
    if (sections.isEmpty) {
      return [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.cluvoChipFill,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(description,
              style: TextStyle(color: context.cluvoTextSecondary, fontSize: 14)),
        ),
      ];
    }
    if (sections.length == 1) {
      return [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.cluvoChipFill,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(sections[0].value,
              style: TextStyle(color: context.cluvoTextSecondary, fontSize: 14)),
        ),
      ];
    }
    return [
      _buildDescTabBar(sections),
      const SizedBox(height: 12),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.cluvoChipFill,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
            sections[_descTabIndex.clamp(0, sections.length - 1)].value,
            style: TextStyle(color: context.cluvoTextSecondary, fontSize: 14)),
      ),
    ];
  }

  Widget _buildDescTabBar(List<MapEntry<String, String>> sections) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: sections.asMap().entries.map((entry) {
          final idx = entry.key;
          final label = entry.value.key;
          final selected = _descTabIndex == idx;
          return GestureDetector(
            onTap: () => setState(() => _descTabIndex = idx),
            child: Padding(
              padding: const EdgeInsets.only(right: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
              color: selected ? context.cluvoTextPrimary : context.cluvoTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: 2.5,
                    width: label.length * 9.0,
                    decoration: BoxDecoration(
                      color: selected ? CluvoTheme.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _formatDateTime(Map<String, dynamic> event, String key) {
    final dt = getParsedDate(event, key);
    if (dt == null) return '';
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
