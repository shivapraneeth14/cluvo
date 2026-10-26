import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../supabase_client.dart';
import '../services/location_matching.dart';
import '../services/location_service.dart';

/// Distinct cities drawn from real, visible communities. Used as the option
/// list for the location selectors and as the candidates for GPS matching.
final locationOptionsProvider = FutureProvider<List<String>>((ref) async {
  final res = await supabase
      .from('communities')
      .select('city')
      .eq('is_hidden', false)
      .isFilter('deleted_at', null)
      .not('city', 'is', null);
  final set = <String>{};
  for (final row in (res as List)) {
    final city = ((row as Map<String, dynamic>)['city'] as String?)?.trim();
    if (city != null && city.isNotEmpty) set.add(city);
  }
  final list = set.toList()..sort();
  return list;
});

enum LocationStatus {
  idle,
  detecting,
  ready,
  noMatch,
  denied,
  deniedForever,
  serviceDisabled,
}

/// The single source of truth for the user's location.
///
/// Two independent concepts live here on purpose:
/// * [city] — the display city. Only ever used to *prioritise* the display
///   (city-matching items first) and label the location button. Never hides
///   items, and never affects distance numbers.
/// * [gpsLat]/[gpsLng] — the **device GPS location only**. This is the sole
///   origin for distance sorting and the distance badges. A manually picked
///   city deliberately does NOT populate these, so "Near to Far" always
///   measures from where the user actually is.
@immutable
class LocationState {
  final String? city;
  final LocationStatus status;
  final double? gpsLat;
  final double? gpsLng;

  const LocationState({
    this.city,
    this.status = LocationStatus.idle,
    this.gpsLat,
    this.gpsLng,
  });

  bool get hasCity => city != null && city!.isNotEmpty;
  bool get hasGps => gpsLat != null && gpsLng != null;

  @override
  bool operator ==(Object other) =>
      other is LocationState &&
      other.city == city &&
      other.status == status &&
      other.gpsLat == gpsLat &&
      other.gpsLng == gpsLng;

  @override
  int get hashCode => Object.hash(city, status, gpsLat, gpsLng);
}

final locationControllerProvider =
    NotifierProvider<LocationController, LocationState>(LocationController.new);

/// Resolves the device city (GPS → reverse geocode → match), and allows a
/// manual override for the current session. State is intentionally in-memory:
/// the city is re-detected on every app launch.
class LocationController extends Notifier<LocationState> {
  bool _detecting = false;
  bool _disposed = false;

  @override
  LocationState build() {
    ref.onDispose(() => _disposed = true);
    return const LocationState();
  }

  /// Manual override from the location selector. Display-only: it changes the
  /// prioritised [city] and never the GPS coordinates, so distance sorting
  /// keeps measuring from the user's real location. Passing null/empty clears
  /// the prioritisation (GPS coordinates are retained).
  void select(String? city) {
    final next = (city == null || city.trim().isEmpty) ? null : city.trim();
    state = LocationState(
      city: next,
      status: next == null ? LocationStatus.idle : LocationStatus.ready,
      gpsLat: state.gpsLat,
      gpsLng: state.gpsLng,
    );
  }

  /// Runs once per app launch. Concurrent calls are ignored.
  Future<void> detectOnLaunch() => _detect();

  /// Re-runs detection from an explicit "Use my location" tap.
  Future<void> useMyLocation() => _detect();

  Future<void> _detect() async {
    if (_detecting) return;
    _detecting = true;
    final prior = state.city;
    final priorLat = state.gpsLat;
    final priorLon = state.gpsLng;
    state = LocationState(
      city: prior,
      status: LocationStatus.detecting,
      gpsLat: priorLat,
      gpsLng: priorLon,
    );
    try {
      final resolution = await ref.read(locationServiceProvider).resolveCity();
      switch (resolution.access) {
        case LocationAccess.serviceDisabled:
          state = LocationState(
            city: prior,
            status: LocationStatus.serviceDisabled,
            gpsLat: priorLat,
            gpsLng: priorLon,
          );
          return;
        case LocationAccess.denied:
          state = LocationState(
            city: prior,
            status: LocationStatus.denied,
            gpsLat: priorLat,
            gpsLng: priorLon,
          );
          return;
        case LocationAccess.deniedForever:
          state = LocationState(
            city: prior,
            status: LocationStatus.deniedForever,
            gpsLat: priorLat,
            gpsLng: priorLon,
          );
          return;
        case LocationAccess.granted:
          break;
      }

      final options = await ref.read(locationOptionsProvider.future);
      if (_disposed) return;
      final matched = matchCity(resolution.city, options);
      state = matched == null
          ? LocationState(
              city: prior,
              status: LocationStatus.noMatch,
              gpsLat: resolution.latitude,
              gpsLng: resolution.longitude,
            )
          : LocationState(
              city: matched,
              status: LocationStatus.ready,
              gpsLat: resolution.latitude,
              gpsLng: resolution.longitude,
            );
    } catch (_) {
      if (!_disposed) {
        state = LocationState(
          city: prior,
          status: LocationStatus.idle,
          gpsLat: priorLat,
          gpsLng: priorLon,
        );
      }
    } finally {
      _detecting = false;
    }
  }
}
