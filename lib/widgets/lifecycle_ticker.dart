import 'dart:async';
import 'package:flutter/widgets.dart';

// Periodically re-evaluates time-derived UI (event lifecycle chips, button
// states, sort order) so nothing needs a manual pull-to-refresh. The 60s tick
// is cheap - only rebuilds, never refetches.
mixin LifecycleTickerMixin<T extends StatefulWidget> on State<T> {
  Timer? _lifecycleTimer;

  void startLifecycleTick() {
    _lifecycleTimer ??= Timer.periodic(
      const Duration(seconds: 60),
      (_) => onLifecycleTick(),
    );
  }

  @protected
  void onLifecycleTick() {}

  @override
  void dispose() {
    _lifecycleTimer?.cancel();
    _lifecycleTimer = null;
    super.dispose();
  }
}