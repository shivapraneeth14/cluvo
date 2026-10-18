import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

/// Permission/service outcome, mapped to an app-owned enum so no `geolocator`
/// type leaks into providers, widgets, or tests.
enum LocationAccess { granted, denied, deniedForever, serviceDisabled }

/// The result of one resolution attempt: the access outcome plus the raw
/// reverse-geocoded city (null when coordinates or the geocoder were
/// unavailable). The raw city is matched against real cities by the caller.
class LocationResolution {
  final LocationAccess access;
  final String? city;
  final double? latitude;
  final double? longitude;

  const LocationResolution(
    this.access, {
    this.city,
    this.latitude,
    this.longitude,
  });

  const LocationResolution.granted(this.city, {this.latitude, this.longitude})
    : access = LocationAccess.granted;
}

/// Thin abstraction over the device location and reverse-geocoding plugins.
/// Kept behind an interface so widgets/providers never touch plugins directly
/// and so tests can inject a fake.
abstract class LocationService {
  Future<LocationResolution> resolveCity();
  Future<void> openAppSettings();
  Future<void> openLocationSettings();
}

class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService();

  static const _timeLimit = Duration(seconds: 8);
  static final _geocoding = Geocoding();

  @override
  Future<LocationResolution> resolveCity() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationResolution(LocationAccess.serviceDisabled);
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationResolution(LocationAccess.deniedForever);
      }
      if (permission == LocationPermission.denied) {
        return const LocationResolution(LocationAccess.denied);
      }

      final position = await _position();
      if (position == null) {
        return const LocationResolution.granted(null);
      }
      return LocationResolution.granted(
        await _cityFor(position),
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (_) {
      // Any plugin/geocoder failure degrades to "no city" (no prioritisation),
      // never a crash.
      return const LocationResolution.granted(null);
    }
  }

  Future<Position?> _position() async {
    final last = await Geolocator.getLastKnownPosition();
    if (last != null) return last;
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: _timeLimit,
      ),
    );
  }

  Future<String?> _cityFor(Position position) async {
    final placemarks = await _geocoding.placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );
    if (placemarks.isEmpty) return null;
    final place = placemarks.first;
    for (final candidate in [
      place.locality,
      place.subAdministrativeArea,
      place.administrativeArea,
    ]) {
      final value = candidate?.trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  @override
  Future<void> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<void> openLocationSettings() => Geolocator.openLocationSettings();
}

/// Overridden with a fake in tests.
final locationServiceProvider = Provider<LocationService>(
  (ref) => const GeolocatorLocationService(),
);
