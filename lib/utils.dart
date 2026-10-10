import 'package:flutter/material.dart';
import 'theme.dart';

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

// ── Fee-on-top money math (all paise) ─────────────────────────────────────
// Mirrors supabase/functions/_shared/fees.ts — keep both in sync:
//   total charged = ticket + flat fee + 18% GST on the fee
//   organizer receives 100% of the ticket; the fee is NOT part of it.
const int kPlatformFeeGstPercent = 18;
const int kDefaultPlatformFeePaise = 2000; // ₹20 flat, pre-GST

int gstForPlatformFee(int netPaise) =>
    (netPaise * kPlatformFeeGstPercent / 100).round();

/// Total platform fee charged to the customer (flat fee + GST), in paise.
int platformFeeTotal(int? feeAmountPaise) {
  final net = feeAmountPaise ?? kDefaultPlatformFeePaise;
  return net + gstForPlatformFee(net);
}

/// ₹ for a paise amount — omits decimals only when the value is whole.
String formatRupees(num paise) {
  final value = paise / 100;
  return value == value.roundToDouble()
      ? '₹${value.toStringAsFixed(0)}'
      : '₹${value.toStringAsFixed(2)}';
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
