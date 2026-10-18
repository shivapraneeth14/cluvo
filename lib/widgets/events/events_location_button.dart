import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme.dart';
import '../../providers/location_provider.dart';
import '../location_feedback.dart';

class _LocationResult {
  final String? value;
  final bool useGps;
  const _LocationResult(this.value, {this.useGps = false});
}

/// Compact header control for the user's city. The city only *prioritises* the
/// display (matching events first) — it never hides events. Offers a manual
/// pick from real, visible community cities plus a one-tap "Use my location".
class EventsLocationButton extends ConsumerWidget {
  const EventsLocationButton({super.key});

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    final options = await ref
        .read(locationOptionsProvider.future)
        .catchError((_) => <String>[]);
    if (!context.mounted) return;

    final current = ref.read(locationControllerProvider).city;
    final result = await showModalBottomSheet<_LocationResult>(
      context: context,
      backgroundColor: context.cluvoSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Choose location',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: context.cluvoTextPrimary,
                    ),
                  ),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.my_location,
                        color: CluvoTheme.primary,
                      ),
                      title: Text(
                        'Use my location',
                        style: TextStyle(color: context.cluvoTextPrimary),
                      ),
                      onTap: () => Navigator.pop(
                        context,
                        const _LocationResult(null, useGps: true),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(
                        Icons.public,
                        color: CluvoTheme.primary,
                      ),
                      title: Text(
                        'Any location',
                        style: TextStyle(color: context.cluvoTextPrimary),
                      ),
                      trailing: current == null
                          ? const Icon(Icons.check, color: CluvoTheme.primary)
                          : null,
                      onTap: () =>
                          Navigator.pop(context, const _LocationResult(null)),
                    ),
                    for (final option in options)
                      ListTile(
                        leading: const Icon(
                          Icons.location_city_outlined,
                          color: CluvoTheme.primary,
                        ),
                        title: Text(
                          option,
                          style: TextStyle(color: context.cluvoTextPrimary),
                        ),
                        trailing: current == option
                            ? const Icon(Icons.check, color: CluvoTheme.primary)
                            : null,
                        onTap: () =>
                            Navigator.pop(context, _LocationResult(option)),
                      ),
                    if (options.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          'No cities available yet.',
                          style: TextStyle(color: context.cluvoTextSecondary),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (result == null || !context.mounted) return;

    if (result.useGps) {
      await ref.read(locationControllerProvider.notifier).useMyLocation();
      if (!context.mounted) return;
      showLocationOutcome(
        context,
        ref,
        ref.read(locationControllerProvider).status,
      );
      return;
    }
    ref.read(locationControllerProvider.notifier).select(result.value);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(locationControllerProvider);
    final label = state.status == LocationStatus.detecting && !state.hasCity
        ? 'Locating…'
        : (state.hasCity ? state.city! : 'Any location');

    return GestureDetector(
      onTap: () => _pick(context, ref),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: context.cluvoChipFill,
          borderRadius: BorderRadius.circular(CluvoTheme.radiusPill),
          border: Border.all(color: context.cluvoBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.location_on_outlined,
              size: 15,
              color: CluvoTheme.primary,
            ),
            const SizedBox(width: 5),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 108),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: context.cluvoTextPrimary,
                ),
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.keyboard_arrow_down,
              size: 16,
              color: context.cluvoTextSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
