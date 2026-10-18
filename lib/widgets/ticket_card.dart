import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../theme.dart';
import 'dotted_divider.dart';

class TicketCard extends StatelessWidget {
  final String title;
  final String? imageUrl;
  final String? communityName;
  final String? communityAvatarUrl;
  final String? dateText;
  final String? venue;
  final String? attendeeName;
  final String ticketType;
  final int quantity;
  final String? bookingId;
  final String? qrData;
  final String status;

  const TicketCard({
    super.key,
    required this.title,
    this.imageUrl,
    this.communityName,
    this.communityAvatarUrl,
    this.dateText,
    this.venue,
    this.attendeeName,
    this.ticketType = 'Entry Pass',
    this.quantity = 1,
    this.bookingId,
    this.qrData,
    this.status = 'confirmed',
  });

  bool get _cancelled => status == 'cancelled';
  bool get _attended => status == 'attended';

  static const _greyscale = <double>[
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: context.cluvoSurface,
            border: Border.all(color: context.cluvoBorder),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _spine(),
                Expanded(child: _content(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _spine() {
    return Container(
      width: 30,
      color: CluvoTheme.primary,
      alignment: Alignment.center,
      child: const RotatedBox(
        quarterTurns: 3,
        child: Text(
          'CLUVO PASS',
          maxLines: 1,
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 3,
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _cover(context),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _statusPill(context),
                ],
              ),
              if (communityName != null && communityName!.isNotEmpty) ...[
                const SizedBox(height: 12),
                _communityChip(context),
              ],
              const SizedBox(height: 16),
              if (dateText != null && dateText!.isNotEmpty)
                _InfoLine(icon: Icons.calendar_today_outlined, text: dateText!),
              if (venue != null && venue!.isNotEmpty) ...[
                const SizedBox(height: 10),
                _InfoLine(icon: Icons.place_outlined, text: venue!),
              ],
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _InfoLine(
                      icon: Icons.person_outline,
                      text: (attendeeName == null || attendeeName!.isEmpty)
                          ? 'Attendee'
                          : attendeeName!,
                    ),
                  ),
                  Expanded(
                    child: _InfoLine(
                      icon: Icons.confirmation_number_outlined,
                      text: '$ticketType · $quantity',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              DottedDivider(color: context.cluvoBorder, notches: true),
              const SizedBox(height: 18),
              _stub(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _cover(BuildContext context) {
    Widget img;
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      img = CachedNetworkImage(
        imageUrl: imageUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: 152,
        placeholder: (_, _) => Container(color: context.cluvoChipFill),
        errorWidget: (_, _, _) => _coverFallback(),
      );
    } else {
      img = _coverFallback();
    }
    if (_cancelled) {
      img = ColorFiltered(
        colorFilter: const ColorFilter.matrix(_greyscale),
        child: img,
      );
    }
    return SizedBox(height: 152, width: double.infinity, child: img);
  }

  Widget _coverFallback() {
    return Container(
      height: 152,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [CluvoTheme.primary, CluvoTheme.primaryLight],
        ),
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.local_activity_outlined,
        size: 44,
        color: Colors.white70,
      ),
    );
  }

  Widget _statusPill(BuildContext context) {
    late final Color color;
    late final String label;
    late final IconData icon;
    if (_cancelled) {
      color = CluvoTheme.error;
      label = 'Cancelled';
      icon = Icons.cancel_outlined;
    } else if (_attended) {
      color = const Color(0xFF2563EB);
      label = 'Checked in';
      icon = Icons.verified_outlined;
    } else {
      color = CluvoTheme.success;
      label = 'Confirmed';
      icon = Icons.check_circle_outline;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _communityChip(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 11,
          backgroundColor: context.cluvoChipFill,
          backgroundImage:
              (communityAvatarUrl != null && communityAvatarUrl!.isNotEmpty)
              ? CachedNetworkImageProvider(communityAvatarUrl!)
              : null,
          child: (communityAvatarUrl == null || communityAvatarUrl!.isEmpty)
              ? Icon(
                  Icons.groups_outlined,
                  size: 12,
                  color: context.cluvoTextSecondary,
                )
              : null,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            communityName!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: context.cluvoTextSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _stub(BuildContext context) {
    if (_cancelled) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(Icons.block, size: 52, color: context.cluvoTextSecondary),
            const SizedBox(height: 10),
            Text(
              'This ticket is no longer valid',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: context.cluvoTextSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (_attended) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified, size: 15, color: Color(0xFF2563EB)),
                SizedBox(width: 6),
                Text(
                  'CHECKED IN',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],
        _QrFrame(data: qrData),
        if (bookingId != null && bookingId!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'BOOKING ID',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 2,
              fontWeight: FontWeight.w600,
              color: context.cluvoTextSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            bookingId!,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              fontFamily: 'monospace',
            ),
          ),
        ],
        const SizedBox(height: 14),
        Text(
          'Show this QR code at the event entrance.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: context.cluvoTextSecondary),
        ),
      ],
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: CluvoTheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _QrFrame extends StatelessWidget {
  final String? data;
  const _QrFrame({this.data});

  @override
  Widget build(BuildContext context) {
    final hasData = data != null && data!.isNotEmpty;
    return SizedBox(
      height: 208,
      width: 208,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: 176,
            width: 176,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: hasData
                ? QrImageView(
                    data: data!,
                    version: QrVersions.auto,
                    backgroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                  )
                : Icon(
                    Icons.qr_code_2,
                    size: 120,
                    color: context.cluvoTextSecondary,
                  ),
          ),
          Positioned.fill(
            child: CustomPaint(painter: _BracketPainter(CluvoTheme.primary)),
          ),
        ],
      ),
    );
  }
}

class _BracketPainter extends CustomPainter {
  final Color color;
  _BracketPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    const arm = 20.0;
    final w = size.width;
    final h = size.height;
    canvas.drawPath(
      Path()
        ..moveTo(0, arm)
        ..lineTo(0, 0)
        ..lineTo(arm, 0),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w - arm, 0)
        ..lineTo(w, 0)
        ..lineTo(w, arm),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w, h - arm)
        ..lineTo(w, h)
        ..lineTo(w - arm, h),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(arm, h)
        ..lineTo(0, h)
        ..lineTo(0, h - arm),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _BracketPainter oldDelegate) =>
      oldDelegate.color != color;
}
