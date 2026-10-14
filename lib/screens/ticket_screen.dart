import 'package:flutter/material.dart';
import '../supabase_client.dart';
import '../utils.dart';
import '../widgets/ticket_card.dart';

class TicketScreen extends StatefulWidget {
  final String registrationId;

  const TicketScreen({super.key, required this.registrationId});

  @override
  State<TicketScreen> createState() => _TicketScreenState();
}

class _TicketScreenState extends State<TicketScreen> {
  Map<String, dynamic>? _registration;
  String? _attendeeName;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await supabase
          .from('registrations')
          .select(
              '*, profiles(first_name, last_name), events!inner(title, start_date, end_date, location, image_url, status, communities(name, community_avatar_url))')
          .eq('id', widget.registrationId)
          .single();
      if (!mounted) return;
      setState(() {
        _registration = res;
        _attendeeName = _nameFrom(res['profiles'] as Map<String, dynamic>?);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String? _nameFrom(Map<String, dynamic>? profile) {
    if (profile == null) return null;
    final first = (profile['first_name'] as String?)?.trim() ?? '';
    final last = (profile['last_name'] as String?)?.trim() ?? '';
    final full = '$first $last'.trim();
    return full.isEmpty ? null : full;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your Ticket')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
        ),
      );
    }
    if (_registration == null) {
      return const Center(child: Text('Ticket not found'));
    }

    final reg = _registration!;
    final event = reg['events'] as Map<String, dynamic>?;
    final community = event?['communities'] as Map<String, dynamic>?;
    final title = event?['title'] as String? ?? 'Event';
    final startDate = event?['start_date'] as String?;
    final endDate = event?['end_date'] as String?;
    final qrCode = reg['qr_code'] as String?;
    final regStatus = reg['status'] as String?;
    final eventStatus = event?['status'] as String? ?? 'published';
    final userEmail = supabase.auth.currentUser?.email ?? '';

    final status = (regStatus == 'cancelled' || eventStatus == 'cancelled')
        ? 'cancelled'
        : (regStatus == 'attended' ? 'attended' : 'confirmed');

    final attendee = _attendeeName ??
        (userEmail.isNotEmpty ? userEmail.split('@').first : null);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        TicketCard(
          title: title,
          imageUrl: event?['image_url'] as String?,
          communityName: community?['name'] as String?,
          communityAvatarUrl: community?['community_avatar_url'] as String?,
          dateText: formatDayDateRange(startDate, endDate),
          venue: event?['location'] as String?,
          attendeeName: attendee,
          bookingId: widget.registrationId.split('-').first.toUpperCase(),
          qrData: qrCode,
          status: status,
        ),
      ],
    );
  }
}
