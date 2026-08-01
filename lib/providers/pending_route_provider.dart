import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _pendingRouteKey = 'pending_route';

final pendingRouteProvider = StateProvider<String?>((ref) => null);

Future<String?> restorePendingRoute() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_pendingRouteKey);
}

Future<void> savePendingRoute(String route) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_pendingRouteKey, route);
}

Future<void> clearPendingRoute() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_pendingRouteKey);
}
