import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/location_provider.dart';
import '../services/location_service.dart';

/// Non-blocking feedback after a GPS attempt. When the user must change a
/// permission or enable location services, offers a shortcut to the relevant
/// settings screen instead of leaving them at a dead end.
void showLocationOutcome(
  BuildContext context,
  WidgetRef ref,
  LocationStatus status,
) {
  final String message;
  VoidCallback? action;
  var actionLabel = 'Settings';

  switch (status) {
    case LocationStatus.serviceDisabled:
      message = 'Turn on location to see what is happening near you.';
      action = () => ref.read(locationServiceProvider).openLocationSettings();
      actionLabel = 'Turn on';
    case LocationStatus.denied:
      message = 'Allow location to show what is near you first.';
      action = () => ref.read(locationServiceProvider).openAppSettings();
    case LocationStatus.deniedForever:
      message =
          'Location is off. Enable it in settings to sort by what is '
          'near you.';
      action = () => ref.read(locationServiceProvider).openAppSettings();
    case LocationStatus.noMatch:
      message = 'No events near you yet — showing everything.';
    case LocationStatus.idle:
    case LocationStatus.detecting:
    case LocationStatus.ready:
      return;
  }

  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      action: action == null
          ? null
          : SnackBarAction(label: actionLabel, onPressed: action),
    ),
  );
}
