import 'package:flutter/material.dart';
import 'theme.dart';

DateTime? safeParseDate(String? iso) {
  if (iso == null || iso.isEmpty) return null;
  try {
    return DateTime.parse(iso);
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
  final dt = DateTime.tryParse(iso ?? '');
  if (dt == null) return '';
  return '${dt.day}/${dt.month}/${dt.year}';
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
