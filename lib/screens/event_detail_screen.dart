import 'package:flutter/foundation.dart';
import 'dart:async';
import '../theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../utils/external_links.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config.dart';
import '../supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/razorpay_web.dart';
import '../widgets/community_photo_grid.dart';
import '../widgets/dotted_divider.dart';
import '../widgets/event_discussion.dart';
import '../widgets/wishlist_button.dart';
import '../widgets/lifecycle_ticker.dart';
import '../providers/wishlist_provider.dart';
import '../models/models.dart';
import '../utils.dart';

class EventDetailScreen extends StatefulWidget {
  final String id;
  const EventDetailScreen({super.key, required this.id});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen>
    with LifecycleTickerMixin<EventDetailScreen> {
  Map<String, dynamic>? _event;
  List<Map<String, dynamic>> _media = [];
  bool _loading = true;
  String? _error;
  bool _isRegistered = false;
  String? _registrationStatus;
  String? _registrationId;
  bool _checkingRegistration = true;
  bool _registering = false;
  bool _processingPayment = false;
  bool _pollActive = false;
  bool _paidButUnconfirmed = false;
  bool _discussionEnabled = false;
  bool _discussionRestricted = false;
  bool _isAdmin = false;
  String _selectedSection = 'discussion';
  int _descTabIndex = 0;
  Razorpay? _razorpay;
  RealtimeChannel? _eventChannel;
  RealtimeChannel? _regChannel;
  Timer? _realtimeDebounce;

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
    startLifecycleTick();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _eventChannel?.unsubscribe();
    _regChannel?.unsubscribe();
    _realtimeDebounce?.cancel();
    if (!kIsWeb) _razorpay?.clear();
    super.dispose();
  }

  // 60s tick: the action button flips Pay/Register -> Live -> Event Closed as
  // start/end dates pass, without any refresh.
  @override
  void onLifecycleTick() {
    if (!mounted) return;
    setState(() {});
  }

  void _subscribeRealtime() {
    _eventChannel = supabase
        .channel('event-detail-${widget.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'events',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.id,
          ),
          callback: (payload) {
            final newRow = payload.newRecord;
            if (!mounted || _event == null) return;
            setState(() {
              _event = Map<String, dynamic>.from(_event!)
                ..addAll(Map<String, dynamic>.from(newRow));
            });
          },
        )
        .subscribe();

    final session = supabase.auth.currentSession;
    if (session == null) return;
    _regChannel = supabase
        .channel('event-detail-reg-${session.user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'registrations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: session.user.id,
          ),
          callback: (payload) {
            final row = Map<String, dynamic>.from(payload.newRecord);
            if (row['event_id'] != widget.id) return;
            _realtimeDebounce?.cancel();
            _realtimeDebounce = Timer(const Duration(milliseconds: 500), () {
              if (mounted) _load();
            });
          },
        )
        .subscribe();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    if (kDebugMode) debugPrint('Razorpay payment success');
    if (!mounted) return;
    setState(() => _processingPayment = true);
    _pollRegistrationStatus();
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (kDebugMode) debugPrint('Razorpay error code=${response.code}');
    if (!mounted) return;
    setState(() {
      _processingPayment = false;
      _registering = false;
    });
    if (response.code == Razorpay.PAYMENT_CANCELLED) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment cancelled. You can try again.'),
          backgroundColor: Colors.orange,
        ),
      );
      _cleanupPendingBooking();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.message ?? 'Payment failed. Try again.'),
          backgroundColor: Colors.red[700],
        ),
      );
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    if (kDebugMode) debugPrint('Razorpay external wallet used');
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
            .select('id, status')
            .eq('event_id', widget.id)
            .eq('user_id', session.user.id)
            .maybeSingle();
        if (res != null && res['status'] == 'confirmed') {
          _pollActive = false;
          setState(() {
            _isRegistered = true;
            _registrationId = res['id'] as String?;
            _processingPayment = false;
            _registering = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Registration confirmed!'),
                backgroundColor: Color(0xFF10B981),
              ),
            );
          }
          return;
        }
        if (res != null && res['status'] == 'cancelled') {
          _pollActive = false;
          setState(() => _processingPayment = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Registration could not be completed.'),
                backgroundColor: Colors.red[700],
              ),
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
    if (_isRegistered) {
      setState(() => _processingPayment = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration confirmed!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
      return;
    }
    // Poll exhausted without a confirmed registration — ask the server (it
    // checks Razorpay directly, so a lost payment.captured webhook can still
    // be resolved here instead of leaving the user stuck).
    await _verifyPayment();
    if (!mounted) return;
    setState(() => _processingPayment = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Payment verification taking longer than expected. Check your registrations.',
        ),
        backgroundColor: Colors.orange,
      ),
    );
  }

  // Server-side verification: resolves a payment whose status transition may
  // have been lost (webhook miss). Confirms against Razorpay directly. It only
  // confirms — refunds stay server-side. Never throws; state is best-effort.
  Future<void> _verifyPayment() async {
    try {
      final session = supabase.auth.currentSession;
      if (session == null) return;
      final res = await supabase.functions
          .invoke('verify-payment', body: {'event_id': widget.id})
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      final state = res.data['state'] as String?;
      if (state == 'confirmed') {
        setState(() {
          _isRegistered = true;
          _registrationStatus = 'confirmed';
          _processingPayment = false;
          _registering = false;
        });
      } else if (state == 'paid_needs_repair') {
        // Money was captured but the booking row is unconfirmed — a legacy
        // stuck row. Never show Pay for it again; the server repairs it.
        setState(() {
          _paidButUnconfirmed = true;
          _processingPayment = false;
          _registering = false;
        });
      }
    } catch (_) {
      // Best-effort — the poll/reload will retry.
    }
  }

  Future<void> _openTicket() async {
    var id = _registrationId;
    if (id == null) {
      final session = supabase.auth.currentSession;
      if (session == null) return;
      try {
        final res = await supabase
            .from('registrations')
            .select('id')
            .eq('event_id', widget.id)
            .eq('user_id', session.user.id)
            .maybeSingle();
        id = res?['id'] as String?;
        if (id != null && mounted) setState(() => _registrationId = id);
      } catch (_) {
        return;
      }
    }
    if (id == null || !mounted) return;
    context.push('/ticket/$id');
  }

  Future<void> _load() async {
    try {
      final session = supabase.auth.currentSession;
      final eventFuture = supabase
          .from('events')
          .select(
            '*, communities!inner(name, community_avatar_url, commission_percent)',
          )
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
        registered = ['confirmed', 'attended'].contains(regData?['status']);
        _registrationStatus = regData?['status'] as String?;
        _registrationId = regData?['id'] as String?;
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
            isAdmin =
                memberRes != null &&
                [
                  'OWNER',
                  'ORGANIZER',
                  'MODERATOR',
                ].contains(memberRes['role'] as String?);
          }
        }
        setState(() {
          _event = event;
          _media = (results[1] as List).cast<Map<String, dynamic>>();
          _isRegistered = registered;
          _registrationStatus = _registrationStatus;
          _isAdmin = isAdmin;
          _paidButUnconfirmed = false;
          _discussionEnabled = (event?['discussion_enabled'] as bool?) ?? false;
          _discussionRestricted =
              (event?['discussion_restricted'] as bool?) ?? false;
          _loading = false;
          _checkingRegistration = false;
        });
        if (regData != null && regData['status'] == 'pending') {
          _verifyPayment();
        }
      } else {
        final results = await Future.wait([
          eventFuture,
          mediaFuture,
        ]).timeout(const Duration(seconds: 30));
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
      if (kDebugMode) debugPrint('Cleanup booking failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not clean up your booking — it will auto-clear in a few minutes.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
    }
    if (!mounted) return;
    setState(() {
      _registrationStatus = null;
    });
  }

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

      // Payment review — breakdown + cancellation policy. No order is created
      // until the attendee explicitly confirms and accepts the 24-hour rule.
      final ticketPaise = ((_event?['price'] as num?) ?? 0).toInt();
      final acknowledged = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        isDismissible: true,
        enableDrag: true,
        useSafeArea: true,
        backgroundColor: context.cluvoBackground,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) => _CancellationPolicySheet(
          ticketPaise: ticketPaise,
          platformFeePaise: _feeAmountPaise(ticketPaise),
        ),
      );
      if (!mounted) return;
      if (acknowledged != true) {
        setState(() => _registering = false);
        return;
      }

      // Create booking + payment order in a single call
      final paymentRes = await supabase.functions
          .invoke('create-payment', body: {'event_id': widget.id})
          .timeout(const Duration(seconds: 30));
      if (!mounted) return;

      // Path C: the server discovered the money already landed (webhook was
      // lost) and confirmed the booking — no checkout step needed.
      final existsResponse = paymentRes.data['exists'] == true;
      final serverPaymentStatus = paymentRes.data['payment_status'] as String?;
      if (existsResponse && serverPaymentStatus == 'confirmed') {
        setState(() {
          _isRegistered = true;
          _registrationStatus = 'confirmed';
          _registering = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration confirmed!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        return;
      }

      final errorCode = paymentRes.data['code'] as String?;
      if (errorCode == 'already_paid' || errorCode == 'refund_in_progress') {
        // Payment already captured — the Pay button must never re-surface.
        // Resolve with the server and mirror its real state.
        setState(() => _registering = false);
        await _verifyPayment();
        return;
      }

      final registrationId = paymentRes.data['registration_id'] as String?;
      final orderId = paymentRes.data['razorpay_order_id'] as String?;
      final amount = paymentRes.data['amount'] as int?;
      if (registrationId == null || orderId == null || amount == null) {
        _showError(
          paymentRes.data['error'] as String? ?? 'Failed to create payment.',
        );
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
        'theme': {'color': '#111111'},
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
            const SnackBar(
              content: Text('Confirmation timed out. Pull to refresh.'),
              backgroundColor: Colors.orange,
            ),
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
      if (kDebugMode) debugPrint('Payment flow error: $e');
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
          .invoke('register-for-event', body: {'event_id': widget.id})
          .timeout(const Duration(seconds: 30));
      if (!mounted) return;
      if (res.data['success'] == true) {
        setState(() {
          _isRegistered = true;
          _registrationStatus = 'confirmed';
          _event!['booked_count'] =
              ((_event!['booked_count'] as num?) ?? 0) + 1;
        });
      } else {
        _showError(res.data['error'] ?? 'Registration failed.');
      }
    } catch (e) {
      if (!mounted) return;
      _showError(_functionErrorMessage(e, 'Something went wrong. Try again.'));
    }
    if (mounted) setState(() => _registering = false);
  }

  bool _cancellationClosed() {
    final e = _event;
    if (e == null) return false;
    final start = getParsedDate(e, 'start_date');
    if (start == null) return false;
    return !DateTime.now().isBefore(start.subtract(const Duration(hours: 24)));
  }

  Future<void> _cancelRegistration() async {
    if (_registering) return;
    if (_cancellationClosed()) {
      _showError('Cancellations close 24 hours before the event starts.');
      return;
    }

    final reg = supabase.auth.currentUser != null
        ? await supabase
              .from('registrations')
              .select('payments(amount, platform_fee, refund_status)')
              .eq('event_id', widget.id)
              .eq('user_id', supabase.auth.currentUser!.id)
              .eq('status', 'confirmed')
              .maybeSingle()
              .catchError((_) => null)
        : null;
    final payRaw = reg?['payments'];
    Map<String, dynamic>? payment;
    if (payRaw is Map<String, dynamic>) {
      payment = payRaw;
    } else if (payRaw is List && payRaw.isNotEmpty) {
      payment = payRaw.first as Map<String, dynamic>?;
    }
    final paid = (payment?['amount'] as num?)?.toInt() ?? 0;
    // Self-cancel refunds the ticket; the fee (persisted at order creation)
    // stays with the platform.
    final feeKept = paid > 0
        ? ((payment?['platform_fee'] as num?)?.toInt() ?? 0)
        : 0;
    final expectedRefund = paid > 0 ? (paid - feeKept).clamp(0, paid) : 0;

    final confirmed = !mounted
        ? null
        : await showDialog<bool>(
            context: context,
            builder: (ctx) => _CancelRegistrationDialog(
              paid: paid,
              feeKept: feeKept,
              expectedRefund: expectedRefund,
            ),
          );
    if (confirmed != true) return;

    setState(() => _registering = true);
    try {
      final res = await supabase.functions
          .invoke(
            'cancel-registration',
            body: {'event_id': widget.id, 'policy_acknowledged': true},
          )
          .timeout(const Duration(seconds: 30));
      if (!mounted) return;
      if (res.data['success'] == true) {
        final refund = res.data['refund'];
        final refundedAmount = refund is Map<String, dynamic>
            ? refund['amount'] as num?
            : null;
        setState(() {
          _isRegistered = false;
          _registrationStatus = 'cancelled';
          _event!['booked_count'] =
              ((_event!['booked_count'] as num?) ?? 1) - 1;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              refundedAmount != null && refundedAmount > 0
                  ? 'Registration cancelled. Refund of ₹${(refundedAmount / 100).toStringAsFixed(0)} initiated.'
                  : 'Registration cancelled.',
            ),
            backgroundColor: Colors.green[700],
          ),
        );
      } else {
        _showError(res.data['error'] ?? 'Cancellation failed.');
      }
    } catch (e) {
      if (!mounted) return;
      _showError(_functionErrorMessage(e, 'Something went wrong. Try again.'));
    }
    if (mounted) setState(() => _registering = false);
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red[700]),
    );
  }

  String _functionErrorMessage(Object error, String fallback) {
    if (error is FunctionException) {
      final details = error.details;
      if (details is Map) {
        final msg = details['error'];
        if (msg is String && msg.trim().isNotEmpty) return msg;
      }
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _checkingRegistration) {
      return Scaffold(body: _buildSkeleton());
    }

    if (_error != null || _event == null) {
      return Scaffold(
        backgroundColor: context.cluvoBackground,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _goBack,
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: context.cluvoChipFill,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.error_outline_rounded,
                    size: 30,
                    color: context.cluvoTextSecondary,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  "We couldn't load this event",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: context.cluvoTextPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please check your connection and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.4,
                    color: context.cluvoTextSecondary,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: context.cluvoTextSecondary.withValues(alpha: 0.7),
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: () => setState(() {
                    _loading = true;
                    _checkingRegistration = true;
                    _error = null;
                    _load();
                  }),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Try again'),
                  style: FilledButton.styleFrom(
                    backgroundColor: CluvoTheme.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
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
    final lifecycle = _lifecycleOf(e);
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
                    toolbarHeight: 52,
                    backgroundColor: Colors.white,
                    foregroundColor: CluvoTheme.textPrimaryColor,
                    systemOverlayStyle: SystemUiOverlayStyle.dark,
                    shape: const Border(
                      bottom: BorderSide(
                        color: CluvoTheme.borderLavender,
                        width: CluvoTheme.hairline,
                      ),
                    ),
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: _goBack,
                    ),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.share_outlined),
                        tooltip: 'Share event',
                        onPressed: () {
                          final url = buildShareUrl('events', widget.id);
                          Share.share(
                            'Check out $title on Cluvo!\n$url',
                            subject: 'Check out $title on Cluvo',
                          );
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
                      e,
                      communityName,
                      communityAvatarUrl,
                      price,
                    ),
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
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Container(
              decoration: BoxDecoration(
                color: context.cluvoSurface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(22),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 24,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: ClipRRect(
                // Clips the perforation notch circles into semicircles at the edges.
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(22),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isRegistered)
                        _registeredActionArea(
                          price,
                          _registrationStatus == 'attended',
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              _priceColumn(price),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: _buildActionButton(
                                    price,
                                    isFull,
                                    eventStatus,
                                    lifecycle,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (price > 0 &&
                          !_isRegistered &&
                          eventStatus != 'cancelled') ...[
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: _buildRefundDisclosure(price),
                        ),
                      ],
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
    final height = (MediaQuery.of(context).size.height * 0.36).clamp(
      250.0,
      320.0,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 28,
              offset: const Offset(0, 10),
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
                      placeholder: (_, _) => _buildBannerFallback(title),
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

              // Status badge (Live / Ended / Cancelled) when relevant
              Positioned(top: 14, right: 14, child: _heroStatusBadge(e)),

              // Title + date, set directly into the image
              Positioned(
                left: 20,
                right: 20,
                bottom: 18,
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
                        fontSize: 29,
                        height: 1.12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black45,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                          Shadow(
                            color: Colors.black26,
                            blurRadius: 14,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                    ),
                    if (start != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _formatDateTime(e, 'start_date'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    color: Colors.black45,
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
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

  // Compact glass badge over the hero for non-active lifecycle states.
  Widget _heroStatusBadge(Map<String, dynamic> e) {
    final lifecycle = _lifecycleOf(e);
    final Color color;
    final String label;
    final IconData icon;
    switch (lifecycle) {
      case EventLifecycle.cancelled:
        color = CluvoTheme.error;
        label = 'Cancelled';
        icon = Icons.event_busy_outlined;
      case EventLifecycle.closed:
        color = CluvoTheme.neutral;
        label = 'Ended';
        icon = Icons.event_available_outlined;
      case EventLifecycle.live:
        color = CluvoTheme.live;
        label = 'Live';
        icon = Icons.circle;
      case EventLifecycle.active:
        return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ── CONTENT SHEET — chips, description, segmented control ───────────────

  Widget _buildSheet(
    Map<String, dynamic> e,
    String? communityName,
    String? communityAvatarUrl,
    num price,
  ) {
    final location = e['location'] as String?;
    final lat = (e['latitude'] as num?)?.toDouble();
    final lng = (e['longitude'] as num?)?.toDouble();
    final start = e['start_date'] as String?;
    final category = e['category'] as String?;
    final capacity = e['capacity'] as int?;
    final booked = (e['booked_count'] as num?) ?? 0;

    final chips = <Widget>[
      if (start != null)
        _infoChip(
          Icons.calendar_today_outlined,
          _formatDateTime(e, 'start_date'),
        ),
      if (location != null && location.isNotEmpty)
        _locationChip(location, lat: lat, lng: lng)
      else if (lat != null && lng != null)
        _locationChip('View on map', lat: lat, lng: lng),
      if (communityName != null)
        _communityChip(communityName, communityAvatarUrl),
      if (category != null && category.isNotEmpty)
        _infoChip(Icons.local_offer_outlined, category),
      _priceChip(price),
      if (capacity != null) _spotsChip(booked.toInt(), capacity),
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.cluvoPrimaryText.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Open location',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: context.cluvoPrimaryText,
                ),
              ),
              const SizedBox(height: 8),
              labelSheet,
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: CluvoTheme.deepNavy,
                    foregroundColor: Colors.white,
                  ),
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
      await openExternalLink(url);
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
            constraints: const BoxConstraints(maxWidth: 220),
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
            Icon(
              Icons.groups_outlined,
              size: 15,
              color: context.cluvoPrimaryText,
            ),
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

  Widget _spotsChip(int booked, int capacity) {
    final full = booked >= capacity;
    final color = full ? CluvoTheme.error : CluvoTheme.neutral;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: full
            ? CluvoTheme.error.withValues(alpha: 0.08)
            : context.cluvoChipFill,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_outline, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            full ? 'Event full' : '$booked/$capacity spots',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: color,
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
            color: selected
                ? context.cluvoTextPrimary
                : context.cluvoTextSecondary,
          ),
        ),
      ),
    );
  }

  // Platform fee as a percent of the (post-coupon) ticket, in paise. No GST.
  int _feeAmountPaise(int ticketPaise) {
    final community = _event?['communities'] as Map<String, dynamic>?;
    final commissionPercent =
        (community?['commission_percent'] as num?)?.toDouble();
    return platformFeeTotal(ticketPaise, commissionPercent);
  }

  Widget _buildRefundDisclosure(num price) {
    final fee = _feeAmountPaise(price.toInt());
    final total = price + fee;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.cluvoChipFill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.shield_outlined,
            size: 15,
            color: context.cluvoTextSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Free cancellation up to 24h before start. Self-cancelling refunds '
              'your ticket ${formatRupees(price)} (platform fee ${formatRupees(fee)} is kept); '
              'if the organizer cancels, you get the full ${formatRupees(total)} back.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: context.cluvoTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Shared tinted panel for non-interactive event/booking states.
  Widget _statusPanel({
    required Color color,
    required IconData icon,
    required String title,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.3,
                      color: context.cluvoTextSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    num price,
    bool isFull,
    String eventStatus,
    EventLifecycle lifecycle,
  ) {
    if (eventStatus == 'cancelled') {
      return _statusPanel(
        color: CluvoTheme.error,
        icon: Icons.event_busy_outlined,
        title: 'Event cancelled',
        subtitle: _registrationStatus == 'confirmed'
            ? 'Any eligible refund will appear in your payments.'
            : 'Bookings are closed for this event.',
      );
    }

    if (eventStatus == 'completed') {
      final attended =
          _registrationStatus == 'confirmed' ||
          _registrationStatus == 'attended';
      return _statusPanel(
        color: attended ? CluvoTheme.success : CluvoTheme.neutral,
        icon: attended
            ? Icons.celebration_outlined
            : Icons.event_available_outlined,
        title: attended ? 'Thank you for attending!' : 'Event ended',
      );
    }

    if (_isRegistered) {
      // Rendered by _registeredActionArea() in the bottom bar; never reached via
      // _buildActionButton, which only handles the non-registered states.
      return const SizedBox.shrink();
    }

    if (lifecycle == EventLifecycle.live) {
      return _statusPanel(
        color: CluvoTheme.live,
        icon: Icons.circle,
        title: 'Live now',
        subtitle: 'Bookings are closed once the event has started.',
      );
    }

    if (lifecycle == EventLifecycle.closed) {
      return _statusPanel(
        color: CluvoTheme.neutral,
        icon: Icons.event_available_outlined,
        title: 'Event closed',
        subtitle: 'This event is no longer taking bookings.',
      );
    }

    if (isFull && !_isRegistered) {
      return _statusPanel(
        color: CluvoTheme.neutral,
        icon: Icons.confirmation_number_outlined,
        title: 'Event full',
        subtitle: 'All seats have been taken.',
      );
    }

    if (_paidButUnconfirmed) {
      return _statusPanel(
        color: CluvoTheme.primary,
        icon: Icons.hourglass_top,
        title: 'Payment received',
        subtitle:
            'We are confirming your booking — you will not be charged twice.',
      );
    }

    // An existing pending registration means a booking attempt is still being
    // resolved by the server (payment verification, webhook or reconciliation).
    // Show that state instead of an apparently active Pay action.
    if (_registrationStatus == 'pending') {
      return _statusPanel(
        color: CluvoTheme.primary,
        icon: Icons.hourglass_top,
        title: 'Confirming your booking',
        subtitle:
            'We are verifying your payment. This usually takes a few minutes.',
      );
    }

    if (price > 0) {
      final busy = _registering || _processingPayment;
      return SizedBox(
        height: 50,
        child: ElevatedButton.icon(
          onPressed: busy ? null : _payForEvent,
          icon: busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.payment_rounded, size: 18),
          label: Text(
            busy ? 'Processing…' : 'Pay ${formatRupees(price)}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: CluvoTheme.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: CluvoTheme.primary.withValues(alpha: 0.6),
            disabledForegroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 22),
          ),
        ),
      );
    }

    return SizedBox(
      height: 50,
      child: ElevatedButton.icon(
        onPressed: _registering ? null : _register,
        icon: _registering
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.event_rounded, size: 18),
        label: const Text(
          'Register',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: CluvoTheme.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: CluvoTheme.primary.withValues(alpha: 0.6),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 22),
        ),
      ),
    );
  }

  Widget _priceColumn(num price) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          price > 0 ? 'Ticket price' : 'Price',
          style: TextStyle(fontSize: 12, color: context.cluvoTextSecondary),
        ),
        const SizedBox(height: 2),
        Text(
          price > 0 ? formatRupees(price) : 'Free',
          style: const TextStyle(
            fontSize: 24,
            height: 1.1,
            fontWeight: FontWeight.w800,
            color: CluvoTheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _statusPill(bool isAttended) {
    final color = isAttended ? const Color(0xFF2563EB) : CluvoTheme.success;
    final label = isAttended ? 'Attended' : 'Registered';
    final icon = isAttended ? Icons.verified_outlined : Icons.check_circle;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // Two-row "ticket stub" bottom bar shown once the user is registered: status +
  // paid amount on top, a dotted perforation with semicircular edge notches, then
  // the View ticket / Cancel actions. When the organizer cancels the event the
  // Cancel action is withdrawn — the refund is handled by the platform.
  Widget _registeredActionArea(num price, bool isAttended) {
    final cancellationClosed = _cancellationClosed();
    final eventCancelled = _event?['status'] == 'cancelled';

    final cancelButton = OutlinedButton(
      onPressed: (_registering || cancellationClosed || eventCancelled)
          ? null
          : _cancelRegistration,
      style: OutlinedButton.styleFrom(
        foregroundColor: CluvoTheme.error,
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: BorderSide(
          color: cancellationClosed || eventCancelled
              ? context.cluvoBorder
              : CluvoTheme.error,
        ),
      ),
      child: _registering
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: CluvoTheme.error,
              ),
            )
          : Text(
              'Cancel',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: cancellationClosed || eventCancelled
                    ? context.cluvoTextSecondary
                    : null,
              ),
            ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              _statusPill(isAttended),
              const Spacer(),
              Text(
                price > 0 ? '${formatRupees(price)} paid' : 'Free',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.cluvoTextSecondary,
                ),
              ),
            ],
          ),
        ),
        _TicketPerforation(
          lineColor: context.cluvoBorder,
          notchColor: context.cluvoBackground,
        ),
        if (eventCancelled) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FilledButton.icon(
                  onPressed: _openTicket,
                  icon: const Icon(
                    Icons.confirmation_number_outlined,
                    size: 18,
                  ),
                  label: const Text('View ticket'),
                  style: FilledButton.styleFrom(
                    backgroundColor: CluvoTheme.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 48),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 14, color: CluvoTheme.error),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'This event was cancelled by the organizer. '
                        'Cancellation is disabled — any refund follows the '
                        'platform policy.',
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.35,
                          color: context.cluvoTextSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ] else
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _openTicket,
                    icon: const Icon(
                      Icons.confirmation_number_outlined,
                      size: 18,
                    ),
                    label: const Text('View ticket'),
                    style: FilledButton.styleFrom(
                      backgroundColor: CluvoTheme.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 48),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                if (!isAttended) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: cancellationClosed
                        ? Tooltip(
                            message:
                                'Cancellations close 24 hours before the event starts.',
                            child: cancelButton,
                          )
                        : cancelButton,
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildBannerFallback(String title) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [CluvoTheme.primary, CluvoTheme.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          title.isNotEmpty ? title[0].toUpperCase() : 'E',
          style: const TextStyle(
            fontFamily: 'PlayfairDisplay',
            color: Colors.white,
            fontSize: 72,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      children: [
        Container(
          height: 52,
          color: context.cluvoBackground,
          child: Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: _goBack,
            ),
          ),
        ),
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
                children: List.generate(
                  3,
                  (i) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Container(
                      height: 36,
                      width: 90,
                      decoration: BoxDecoration(
                        color: context.cluvoChipFill,
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                height: 14,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: context.cluvoChipFill,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                height: 14,
                width: 240,
                decoration: BoxDecoration(
                  color: context.cluvoChipFill,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 24),
              ...List.generate(
                4,
                (_) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    height: 14,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: context.cluvoChipFill,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
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
              Icon(
                Icons.lock_outline,
                size: 40,
                color: context.cluvoTextSecondary,
              ),
              const SizedBox(height: 12),
              Text(
                'Sign in to join the discussion.',
                style: TextStyle(color: context.cluvoTextSecondary),
              ),
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
          child: Text(
            description,
            style: TextStyle(
              color: context.cluvoTextPrimary,
              fontSize: 14.5,
              height: 1.55,
            ),
          ),
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
          child: Text(
            sections[0].value,
            style: TextStyle(
              color: context.cluvoTextPrimary,
              fontSize: 14.5,
              height: 1.55,
            ),
          ),
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
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          sections[_descTabIndex.clamp(0, sections.length - 1)].value,
          style: TextStyle(
            color: context.cluvoTextPrimary,
            fontSize: 14.5,
            height: 1.55,
          ),
        ),
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
                      color: selected
                          ? context.cluvoTextPrimary
                          : context.cluvoTextSecondary,
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

  // ── NAVIGATION + LIFECYCLE HELPERS ───────────────────────────────────────

  void _goBack() {
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/events');
    }
  }

  // Derives the display lifecycle from the raw event row. Order matters:
  // explicit cancellation/completion wins, then a passed end time, otherwise the
  // event is either upcoming (active) or has started (live).
  EventLifecycle _lifecycleOf(Map<String, dynamic> e) {
    final status = (e['status'] as String?)?.toLowerCase();
    if (status == 'cancelled') return EventLifecycle.cancelled;
    if (status == 'completed') return EventLifecycle.closed;

    final now = DateTime.now();
    final end = getParsedDate(e, 'end_date') ?? getParsedDate(e, 'start_date');
    if (end != null && now.isAfter(end)) return EventLifecycle.closed;

    final start = getParsedDate(e, 'start_date');
    if (start == null || now.isBefore(start)) return EventLifecycle.active;
    return EventLifecycle.live;
  }

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String _formatDateTime(Map<String, dynamic> event, String key) {
    final dt = getParsedDate(event, key);
    if (dt == null) return '';
    final month = _months[dt.month - 1];
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final meridiem = dt.hour < 12 ? 'AM' : 'PM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} $month ${dt.year} · $hour12:$minute $meridiem';
  }
}

class _CancellationPolicySheet extends StatefulWidget {
  final int ticketPaise;
  final int platformFeePaise;

  const _CancellationPolicySheet({
    required this.ticketPaise,
    required this.platformFeePaise,
  });

  @override
  State<_CancellationPolicySheet> createState() =>
      _CancellationPolicySheetState();
}

class _CancellationPolicySheetState extends State<_CancellationPolicySheet> {
  bool _acknowledged = false;

  Widget _row(String label, String value, {bool bold = false}) {
    final style = TextStyle(
      fontSize: bold ? 16 : 13.5,
      fontWeight: bold ? FontWeight.w800 : FontWeight.w400,
      color: bold ? CluvoTheme.primary : const Color(0xFF54606F),
    );
    return Padding(
      padding: EdgeInsets.symmetric(vertical: bold ? 4 : 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fee = widget.platformFeePaise;
    final total = widget.ticketPaise + fee;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.cluvoPrimaryText.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Before you pay',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: context.cluvoSurface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: context.cluvoBorder),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _row(
                            'Ticket price',
                            formatRupees(widget.ticketPaise),
                          ),
                          _row(
                            'Platform fee',
                            formatRupees(widget.platformFeePaise),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 6),
                            child: Divider(height: 1),
                          ),
                          _row(
                            'Total you pay',
                            formatRupees(total),
                            bold: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Cancellations are allowed only until 24 hours before the event starts. '
                      'Inside 24 hours, cancellation closes and your booking becomes non-refundable.',
                      style: TextStyle(fontSize: 13.5),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'If you cancel yourself, the ticket price is refunded but the platform fee is kept. '
                      'If the organizer cancels the event, you get the full amount back.',
                      style: TextStyle(fontSize: 12.5, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    CheckboxListTile(
                      value: _acknowledged,
                      onChanged: (v) =>
                          setState(() => _acknowledged = v ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text(
                        'I understand the cancellation policy',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Not now'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _acknowledged
                        ? () => Navigator.of(context).pop(true)
                        : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 50),
                      backgroundColor: CluvoTheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'Confirm ${formatRupees(total)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Full-width ticket perforation: a dotted line with a semicircular bite at each
// edge. The bites are circles centred on the bar's left/right edges; the parent
// ClipRRect slices them into half-circles.
class _TicketPerforation extends StatelessWidget {
  final Color lineColor;
  final Color notchColor;

  const _TicketPerforation({required this.lineColor, required this.notchColor});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 22,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DottedDivider(color: lineColor),
          ),
          Positioned(left: -11, child: _notch()),
          Positioned(right: -11, child: _notch()),
        ],
      ),
    );
  }

  Widget _notch() => Container(
    width: 22,
    height: 22,
    decoration: BoxDecoration(color: notchColor, shape: BoxShape.circle),
  );
}

/// Cancel-registration confirmation. Shows the refund breakdown and REQUIRES
/// the user to tick "I understand the cancellation and refund policy" before
/// the Confirm button is enabled. The acknowledgment is sent to the
/// cancel-registration edge function (policy_acknowledged) for the audit log.
class _CancelRegistrationDialog extends StatefulWidget {
  final int paid;
  final int feeKept;
  final int expectedRefund;

  const _CancelRegistrationDialog({
    required this.paid,
    required this.feeKept,
    required this.expectedRefund,
  });

  @override
  State<_CancelRegistrationDialog> createState() =>
      _CancelRegistrationDialogState();
}

class _CancelRegistrationDialogState extends State<_CancelRegistrationDialog> {
  bool _acknowledged = false;

  @override
  Widget build(BuildContext context) {
    final paid = widget.paid;
    final feeKept = widget.feeKept;
    final expectedRefund = widget.expectedRefund;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: CluvoTheme.error.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.event_busy_outlined,
              size: 20,
              color: CluvoTheme.error,
            ),
          ),
          const SizedBox(width: 10),
          const Flexible(child: Text('Cancel registration?')),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.5,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your registration will be cancelled.',
                style: TextStyle(fontSize: 14),
              ),
              if (paid > 0) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.cluvoChipFill,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'You will be refunded',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.cluvoTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatRupees(expectedRefund),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: CluvoTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Platform fee ${formatRupees(feeKept)} is not refundable on self-cancel.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.3,
                          color: context.cluvoTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Refunds appear in your payment details and take 3–5 business days to reach your account.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
              const SizedBox(height: 8),
              CheckboxListTile(
                value: _acknowledged,
                onChanged: (v) => setState(() => _acknowledged = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text(
                  'I understand the cancellation and refund policy',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Keep registration'),
        ),
        FilledButton(
          onPressed: _acknowledged
              ? () => Navigator.of(context).pop(true)
              : null,
          style: FilledButton.styleFrom(
            backgroundColor: CluvoTheme.error,
            foregroundColor: Colors.white,
            disabledBackgroundColor: CluvoTheme.error.withValues(alpha: 0.4),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Cancel & refund'),
        ),
      ],
    );
  }
}
