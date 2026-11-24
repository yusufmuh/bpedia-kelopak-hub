/// Web implementation of `browser.dart` (package:web).
library;

import 'dart:async';

import 'package:web/web.dart' as web;

const String _reducedMotionQuery = '(prefers-reduced-motion: reduce)';

/// Whether the browser asks for reduced motion
/// (`prefers-reduced-motion: reduce`).
bool browserPrefersReducedMotion() =>
    web.window.matchMedia(_reducedMotionQuery).matches;

/// Calls [onChange] when the browser's reduced-motion setting changes.
/// Returns the function that stops watching.
void Function() watchBrowserReducedMotion(void Function(bool reduce) onChange) {
  final query = web.window.matchMedia(_reducedMotionQuery);
  final subscription = web.EventStreamProviders.changeEvent
      .forTarget(query)
      .listen((_) => onChange(query.matches));
  return () => unawaited(subscription.cancel());
}

/// Calls [onChange] when another tab of this origin changes [key] in
/// localStorage (or clears it). The browser only sends this event to the
/// other tabs, never to the tab that wrote. Returns the function that stops
/// watching.
void Function() watchBrowserStorageKey(String key, void Function() onChange) {
  final subscription = web.EventStreamProviders.storageEvent
      .forTarget(web.window)
      .listen((event) {
        final changed = event.key;
        if (changed == null || changed == key) onChange();
      });
  return () => unawaited(subscription.cancel());
}
