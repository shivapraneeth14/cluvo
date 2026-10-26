import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/providers/location_provider.dart';
import 'package:mobile/services/location_service.dart';

class _FakeLocationService implements LocationService {
  _FakeLocationService(this._resolution);

  final LocationResolution _resolution;

  @override
  Future<LocationResolution> resolveCity() async => _resolution;

  @override
  Future<void> openAppSettings() async {}

  @override
  Future<void> openLocationSettings() async {}
}

ProviderContainer _container(
  LocationResolution resolution, {
  List<String> options = const ['Bengaluru', 'Mumbai'],
  Future<List<String>> Function()? optionsLoader,
}) {
  return ProviderContainer(
    overrides: [
      locationServiceProvider.overrideWithValue(
        _FakeLocationService(resolution),
      ),
      locationOptionsProvider.overrideWith(
        (ref) => optionsLoader?.call() ?? Future.value(options),
      ),
    ],
  );
}

void main() {
  group('LocationController.select', () {
    test('sets and clears a manual city', () {
      final container = _container(
        const LocationResolution(LocationAccess.granted),
      );
      addTearDown(container.dispose);

      final controller = container.read(locationControllerProvider.notifier);
      expect(container.read(locationControllerProvider).hasCity, isFalse);

      controller.select('Mumbai');
      var state = container.read(locationControllerProvider);
      expect(state.city, 'Mumbai');
      expect(state.status, LocationStatus.ready);

      controller.select(null);
      state = container.read(locationControllerProvider);
      expect(state.city, isNull);
      expect(state.hasCity, isFalse);
    });

    test('select never sets GPS coordinates (display-only override)', () {
      final container = _container(
        const LocationResolution(LocationAccess.granted),
      );
      addTearDown(container.dispose);

      container.read(locationControllerProvider.notifier).select('Mumbai');
      final state = container.read(locationControllerProvider);
      expect(state.city, 'Mumbai');
      expect(state.gpsLat, isNull);
      expect(state.gpsLng, isNull);
      expect(state.hasGps, isFalse);
    });

    test('detected GPS coordinates survive a city override', () async {
      final container = _container(
        LocationResolution.granted(
          'Bengaluru',
          latitude: 12.9716,
          longitude: 77.5946,
        ),
      );
      addTearDown(container.dispose);

      final controller = container.read(locationControllerProvider.notifier);
      await controller.detectOnLaunch();
      controller.select('Mumbai');
      final state = container.read(locationControllerProvider);
      expect(state.city, 'Mumbai');
      expect(state.gpsLat, 12.9716);
      expect(state.gpsLng, 77.5946);
    });

    test('select(null) keeps detected GPS coordinates', () async {
      final container = _container(
        LocationResolution.granted(
          'Bengaluru',
          latitude: 12.9716,
          longitude: 77.5946,
        ),
      );
      addTearDown(container.dispose);

      final controller = container.read(locationControllerProvider.notifier);
      await controller.detectOnLaunch();
      controller.select(null);
      final state = container.read(locationControllerProvider);
      expect(state.city, isNull);
      expect(state.gpsLat, 12.9716);
      expect(state.gpsLng, 77.5946);
    });
  });

  group('LocationController.detectOnLaunch', () {
    test('matches a geocoded city to a stored option', () async {
      final container = _container(
        const LocationResolution.granted('Bengaluru'),
      );
      addTearDown(container.dispose);

      await container
          .read(locationControllerProvider.notifier)
          .detectOnLaunch();
      final state = container.read(locationControllerProvider);
      expect(state.city, 'Bengaluru');
      expect(state.status, LocationStatus.ready);
    });

    test('resolves aliases (Bangalore -> Bengaluru)', () async {
      final container = _container(
        const LocationResolution.granted('Bangalore'),
      );
      addTearDown(container.dispose);

      await container
          .read(locationControllerProvider.notifier)
          .detectOnLaunch();
      expect(container.read(locationControllerProvider).city, 'Bengaluru');
    });

    test('reports noMatch when no stored city matches', () async {
      final container = _container(const LocationResolution.granted('Chennai'));
      addTearDown(container.dispose);

      await container
          .read(locationControllerProvider.notifier)
          .detectOnLaunch();
      final state = container.read(locationControllerProvider);
      expect(state.city, isNull);
      expect(state.status, LocationStatus.noMatch);
    });

    test('reports noMatch when no city could be reverse-geocoded', () async {
      final container = _container(const LocationResolution.granted(null));
      addTearDown(container.dispose);

      await container
          .read(locationControllerProvider.notifier)
          .detectOnLaunch();
      expect(
        container.read(locationControllerProvider).status,
        LocationStatus.noMatch,
      );
    });

    test('maps denied permissions', () async {
      final container = _container(
        const LocationResolution(LocationAccess.denied),
      );
      addTearDown(container.dispose);

      await container
          .read(locationControllerProvider.notifier)
          .detectOnLaunch();
      expect(
        container.read(locationControllerProvider).status,
        LocationStatus.denied,
      );
    });

    test('maps permanently denied permissions', () async {
      final container = _container(
        const LocationResolution(LocationAccess.deniedForever),
      );
      addTearDown(container.dispose);

      await container
          .read(locationControllerProvider.notifier)
          .detectOnLaunch();
      expect(
        container.read(locationControllerProvider).status,
        LocationStatus.deniedForever,
      );
    });

    test('maps disabled location services', () async {
      final container = _container(
        const LocationResolution(LocationAccess.serviceDisabled),
      );
      addTearDown(container.dispose);

      await container
          .read(locationControllerProvider.notifier)
          .detectOnLaunch();
      expect(
        container.read(locationControllerProvider).status,
        LocationStatus.serviceDisabled,
      );
    });

    test('preserves a manual city when detection is denied', () async {
      final container = _container(
        const LocationResolution(LocationAccess.denied),
      );
      addTearDown(container.dispose);

      final controller = container.read(locationControllerProvider.notifier);
      controller.select('Mumbai');
      await controller.detectOnLaunch();
      final state = container.read(locationControllerProvider);
      expect(state.city, 'Mumbai');
      expect(state.status, LocationStatus.denied);
    });

    test('degrades to idle when the city options fail to load', () async {
      final container = _container(
        const LocationResolution.granted('Bengaluru'),
        optionsLoader: () => Future.error(Exception('offline')),
      );
      addTearDown(container.dispose);

      await container
          .read(locationControllerProvider.notifier)
          .detectOnLaunch();
      expect(
        container.read(locationControllerProvider).status,
        LocationStatus.idle,
      );
    });
  });
}
