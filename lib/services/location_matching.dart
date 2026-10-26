import 'dart:math' as math;
import '../models/community.dart';
import '../models/event.dart';

/// Pure, dependency-free location helpers.
///
/// Location is only ever used to *prioritise* the display (city-matching items
/// first) — never to filter. Keeping the logic here, free of Flutter/Riverpod
/// and plugins, makes it trivially unit-testable and safe to reuse everywhere.

const Map<String, String> _cityAliases = {
  'bangalore': 'bengaluru',
  'bombay': 'mumbai',
  'madras': 'chennai',
  'calcutta': 'kolkata',
  'gurgaon': 'gurugram',
  'cochin': 'kochi',
  'mysore': 'mysuru',
};

/// Normalises a free-form place name for comparison: lower-cased, punctuation
/// stripped, and whitespace collapsed.
String normalizeCity(String? value) {
  if (value == null) return '';
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _canonicalToken(String token) => _cityAliases[token] ?? token;

/// True when two free-form place strings refer to the same city. Handles exact
/// matches, common spelling aliases (Bangalore/Bengaluru), and multi-word
/// strings such as `"Koramangala, Bengaluru"`.
bool cityMatches(String? a, String? b) {
  final na = normalizeCity(a);
  final nb = normalizeCity(b);
  if (na.isEmpty || nb.isEmpty) return false;
  if (na == nb) return true;

  final tokensA = na.split(' ').map(_canonicalToken).toSet();
  final tokensB = nb.split(' ').map(_canonicalToken).toSet();
  if (tokensA.intersection(tokensB).isNotEmpty) return true;

  return na.contains(nb) || nb.contains(na);
}

/// Matches a reverse-geocoded city against the real, visible community cities.
/// Returns the original option (so callers keep the exact stored spelling) or
/// null when nothing matches.
String? matchCity(String? geocoded, List<String> options) {
  final target = normalizeCity(geocoded);
  if (target.isEmpty) return null;

  String? loose;
  for (final option in options) {
    final norm = normalizeCity(option);
    if (norm.isEmpty) continue;
    if (norm == target) return option;
    loose ??= cityMatches(option, geocoded) ? option : null;
  }
  return loose;
}

/// Returns [items] unchanged when they are already city-first; otherwise a new
/// list with the matching items first and the rest after, preserving the
/// relative order of both groups. Always returns every item.
List<T> partitionLocalFirst<T>(List<T> items, bool Function(T item) isLocal) {
  if (items.isEmpty) return items;
  final local = <T>[];
  final rest = <T>[];
  for (final item in items) {
    (isLocal(item) ? local : rest).add(item);
  }
  if (local.isEmpty || rest.isEmpty) return items;
  return [...local, ...rest];
}

/// Whether an event is in the user's city. Events store a free-form location.
bool isEventLocal(Event event, String? city) =>
    cityMatches(event.location, city);

/// Whether a community is in the user's city (prefers the structured `city`,
/// falls back to the free-form `location`).
bool isCommunityLocal(Community community, String? city) =>
    cityMatches(community.city, city) || cityMatches(community.location, city);

/// Haversine distance in km between two points.
double distanceKm(double lat1, double lon1, double lat2, double lon2) {
  const R = 6371.0;
  final dLat = (lat2 - lat1) * math.pi / 180;
  final dLon = (lon2 - lon1) * math.pi / 180;
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * math.pi / 180) *
          math.cos(lat2 * math.pi / 180) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return R * c;
}

double? eventDistanceKm(Event event, double? userLat, double? userLon) {
  if (userLat == null ||
      userLon == null ||
      event.latitude == null ||
      event.longitude == null) {
    return null;
  }
  return distanceKm(userLat, userLon, event.latitude!, event.longitude!);
}

/// Human-readable distance for cards: one decimal below 10 km, whole numbers
/// beyond, and an explicit "Under 1 km" for walking distances.
String formatDistance(double km) {
  if (km < 1) return 'Under 1 km away';
  if (km < 10) return '${km.toStringAsFixed(1)} km away';
  return '${km.round()} km away';
}
