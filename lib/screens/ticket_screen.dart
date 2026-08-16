import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../supabase_client.dart';
import '../theme.dart';
import '../utils.dart';

class TicketScreen extends StatefulWidget {
  final String registrationId;

  const TicketScreen({super.key, required this.registrationId});

  @override
  State<TicketScreen> createState() => _TicketScreenState();
}

class _TicketScreenState extends State<TicketScreen> {
  Map<String, dynamic>? _registration;
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
          .select('*, events!inner(title, start_date, status), payments(status, refund_status)')
          .eq('id', widget.registrationId)
          .single();
      if (!mounted) return;
      setState(() {
        _registration = res;
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

    final events = _registration!['events'] as Map<String, dynamic>?;
    final title = events?['title'] as String? ?? 'Event';
    final startDate = events?['start_date'] as String?;
    final qrCode = _registration!['qr_code'] as String?;
    final status = _registration!['status'] as String?;
    final eventStatus = (events?['status'] as String?) ?? 'confirmed';
    final cancelled = status != 'confirmed';
    final eventCancelled = eventStatus == 'cancelled';
    final userEmail = supabase.auth.currentUser?.email ?? '';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              if (startDate != null) ...[
                const SizedBox(height: 4),
                Text(formatDate(startDate),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: context.cluvoTextSecondary)),
              ],
              const SizedBox(height: 20),
              if (cancelled || eventCancelled) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.cluvoSurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.block, size: 64, color: context.cluvoTextSecondary),
                      const SizedBox(height: 8),
                      Text(
                        eventCancelled ? 'Event cancelled' : 'Registration cancelled — this ticket is no longer valid',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ] else
                Center(
                  child: qrCode != null
                      ? QrImageView(
                          data: qrCode,
                          version: QrVersions.auto,
                          size: 200,
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.all(8),
                        )
                      : Icon(Icons.qr_code_2, size: 120, color: context.cluvoTextSecondary),
                ),
              const SizedBox(height: 16),
              Text('Ticket #${widget.registrationId.split('-').first}',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: context.cluvoTextSecondary)),
              if (userEmail.isNotEmpty)
                Text(userEmail,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Show this QR code at the event entrance. A screenshot works too.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: context.cluvoTextSecondary),
        ),
      ],
    );
  }
}