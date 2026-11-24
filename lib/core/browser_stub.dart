/// Non-web implementation of `browser.dart`: nothing to read or watch.
library;

/// Whether the browser asks for reduced motion (always false off the web).
bool browserPrefersReducedMotion() => false;

/// Calls `onChange` when the browser's reduced-motion setting changes.
/// Returns the function that stops watching.
void Function() watchBrowserReducedMotion(
  void Function(bool reduce) onChange,
) => _stop;

/// Calls `onChange` when another tab of this origin changes `key` in
/// localStorage. Returns the function that stops watching.
void Function() watchBrowserStorageKey(String key, void Function() onChange) =>
    _stop;

void _stop() {}
