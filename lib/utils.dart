import 'package:flutter/material.dart';
import 'theme.dart';

/// Removes characters that would break a PostgREST `or(...)` filter string.
String sanitizeSearchQuery(String q) => q
    .replaceAll('\\', '')
    .replaceAll('%', '')
    .replaceAll(',', ' ')
    .replaceAll('(', ' ')
    .replaceAll(')', ' ')
    .trim();

DateTime? safeParseDate(String? iso) {
  if (iso == null || iso.isEmpty) return null;
  try {
    final dt = DateTime.parse(iso);
    return dt.isUtc ? dt.toLocal() : dt;
  } catch (_) {
    return null;
  }
}

DateTime? getParsedDate(Map<String, dynamic> map, String key) {
  if (map['_parsed_$key'] is DateTime) return map['_parsed_$key'] as DateTime;
  final parsed = safeParseDate(map[key] as String?);
  if (parsed != null) map['_parsed_$key'] = parsed;
  return parsed;
}

void preParseEventDates(List<Map<String, dynamic>> events) {
  for (final e in events) {
    getParsedDate(e, 'start_date');
    getParsedDate(e, 'end_date');
    getParsedDate(e, 'created_at');
  }
}

String formatDate(String? iso) {
  final dt = safeParseDate(iso);
  if (dt == null) return '';
  return '${dt.day}/${dt.month}/${dt.year}';
}

String formatDateTime(DateTime? dt) {
  if (dt == null) return '';
  final local = dt.isUtc ? dt.toLocal() : dt;
  return '${local.day}/${local.month}/${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
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

String formatTime(DateTime? dt) {
  if (dt == null) return '';
  final local = dt.isUtc ? dt.toLocal() : dt;
  final h12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  return '$h12:$minute ${local.hour < 12 ? 'AM' : 'PM'}';
}

String formatDayDate(String? iso) {
  final dt = safeParseDate(iso);
  if (dt == null) return '';
  return '${_weekdays[dt.weekday - 1]}, ${dt.day} ${_months[dt.month - 1]} ${dt.year} · ${formatTime(dt)}';
}

String formatDayDateRange(String? startIso, String? endIso) {
  final start = safeParseDate(startIso);
  if (start == null) return '';
  final base =
      '${_weekdays[start.weekday - 1]}, ${start.day} ${_months[start.month - 1]} ${start.year} · ${formatTime(start)}';
  final end = safeParseDate(endIso);
  if (end != null && end.isAfter(start)) {
    return '$base – ${formatTime(end)}';
  }
  return base;
}

// ── Fee-on-top money math (all paise) ─────────────────────────────────────
// Mirrors supabase/functions/_shared/fees.ts — keep both in sync:
//   total charged = ticket + round(ticket * commission_percent / 100)
//   organizer receives 100% of the ticket; the fee is NOT part of it. No GST.
const num kDefaultCommissionPercent = 6;

/// Platform fee charged to the customer for one ticket, in paise.
int platformFeeTotal(int ticketPaise, num? commissionPercent) {
  final pct = commissionPercent ?? kDefaultCommissionPercent;
  return ((ticketPaise * pct) / 100).round();
}

/// ₹ for a paise amount — omits decimals only when the value is whole.
String formatRupees(num paise) {
  final value = paise / 100;
  return value == value.roundToDouble()
      ? '₹${value.toStringAsFixed(0)}'
      : '₹${value.toStringAsFixed(2)}';
}

/// True when a payment row records money actually moving — a capture, a
/// refund, or a refund the provider is still working on.
///
/// Mirrors the backend rule that decides whether a cancelled registration may
/// be silently reused (`supabase/functions/_shared/payments.ts`:
/// `paymentNonRequotableReason` + `refundFieldsPresent`), so the app never
/// hides a booking the server still treats as financially live.
bool paymentHasMoneyTrail(Map<String, dynamic>? payment) {
  if (payment == null) return false;
  final status = payment['status'] as String?;
  if (status == 'success' || status == 'refunded') return true;
  if (payment['refund_status'] != null) return true;
  final claim = payment['refund_claim_state'] as String?;
  if (claim != null && claim != 'none') return true;
  final refunded = payment['refunded_amount'] as num?;
  return refunded != null && refunded > 0;
}

/// The payment embedded on a registration, tolerating both the object and
/// array shapes PostgREST returns for an embedded one-to-many relation.
Map<String, dynamic>? embeddedPayment(Map<String, dynamic> registration) {
  final raw = registration['payments'];
  if (raw is Map<String, dynamic>) return raw;
  if (raw is List && raw.isNotEmpty) {
    return raw.first as Map<String, dynamic>?;
  }
  return null;
}

/// A registration is *noise* only when it is an abandoned checkout: soft
/// deleted, the event itself not cancelled, and no money ever captured.
///
/// A cancelled booking with a refund — or a free-event booking the user
/// cancelled — is history the owner must keep seeing.
bool isAbandonedCheckout({
  required Map<String, dynamic> registration,
  required Map<String, dynamic>? payment,
  required Map<String, dynamic>? event,
}) {
  if (registration['deleted_at'] == null) return false;
  if (event?['status'] == 'cancelled') return false;
  if (paymentHasMoneyTrail(payment)) return false;
  if (payment == null) {
    // No payment row: a free-event booking the user cancelled stays visible;
    // a paid event whose order never started is an abandoned checkout.
    return ((event?['price'] as num?) ?? 0) > 0;
  }
  // A payment row exists but never succeeded (failed/pending): abandoned.
  return true;
}

Color regStatusColor(BuildContext context, String status) {
  switch (status) {
    case 'confirmed':
      return Colors.green;
    case 'attended':
      return Colors.blue;
    case 'cancelled':
      return context.cluvoTextSecondary;
    default:
      return Colors.orange;
  }
}

IconData regStatusIcon(String status) {
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

Color payStatusColor(String status) {
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

IconData payStatusIcon(String status) {
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
