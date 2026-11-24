import 'package:flutter/widgets.dart';

import '../../core/browser.dart';

/// Folds every "reduce motion" preference into
/// [MediaQueryData.disableAnimations] below it, so animated widgets only
/// need [MediaQuery.disableAnimationsOf]:
///
/// * Android "Remove animations" (already reported as disableAnimations);
/// * iOS Reduce Motion (`AccessibilityFeatures.reduceMotion`);
/// * the browser's `prefers-reduced-motion: reduce` on the web.
class ReduceMotionScope extends StatefulWidget {
  const ReduceMotionScope({super.key, required this.child});

  /// The app (or page) that should follow the preference.
  final Widget child;

  @override
  State<ReduceMotionScope> createState() => _ReduceMotionScopeState();
}

class _ReduceMotionScopeState extends State<ReduceMotionScope>
    with WidgetsBindingObserver {
  bool _browserReduce = browserPrefersReducedMotion();
  late final void Function() _stopWatchingBrowser;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _stopWatchingBrowser = watchBrowserReducedMotion((reduce) {
      if (mounted) setState(() => _browserReduce = reduce);
    });
  }

  /// MediaQuery.fromView only rebuilds when a feature it reports changes;
  /// reduceMotion is not one of them, so listen here.
  @override
  void didChangeAccessibilityFeatures() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _stopWatchingBrowser();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final reduce =
        media.disableAnimations ||
        View.of(
          context,
        ).platformDispatcher.accessibilityFeatures.reduceMotion ||
        _browserReduce;
    // Always the same tree shape, so flipping the setting keeps all state.
    return MediaQuery(
      data: media.copyWith(disableAnimations: reduce),
      child: widget.child,
    );
  }
}
