/// Browser signals the app follows on the web: the `prefers-reduced-motion`
/// setting and saves another tab makes to localStorage. Off the web every
/// function is a no-op, so callers never need a platform check.
library;

export 'browser_stub.dart' if (dart.library.js_interop) 'browser_web.dart';
