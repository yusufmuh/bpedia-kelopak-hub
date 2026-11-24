import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/sound.dart';
import '../domain/app_state.dart';
import 'account/account_page.dart';
import 'home/home_page.dart';
import 'orders/orders_page.dart';
import 'rewards/rewards_hub_page.dart';
import 'widgets/brand_icon.dart';

/// Bottom-navigation tabs.
enum ShellTab {
  home('Beranda', BrandIcons.home),
  rewards('Hadiah', BrandIcons.reward),
  orders('Transaksi', BrandIcons.transaksi),
  account('Akun', BrandIcons.akun);

  const ShellTab(this.label, this.iconName);

  /// Tab label (always visible).
  final String label;

  /// Brand icon base name.
  final String iconName;
}

/// Selected tab, owned by `BpediaApp` and shared through [ShellScope].
class ShellController extends ValueNotifier<ShellTab> {
  ShellController([super.value = ShellTab.home]);
}

/// Lets any route (including pushed pages) switch the bottom-navigation tab.
///
/// ```dart
/// ShellScope.of(context).switchTab(ShellTab.orders);
/// ```
class ShellScope extends InheritedNotifier<ShellController> {
  const ShellScope({
    super.key,
    required ShellController controller,
    required this.navigatorKey,
    required super.child,
  }) : super(notifier: controller);

  /// Root navigator of the app.
  final GlobalKey<NavigatorState> navigatorKey;

  /// The tab controller.
  ShellController get controller => notifier!;

  /// Currently selected tab.
  ShellTab get currentTab => controller.value;

  /// Pops every pushed route (pages, sheets, dialogs) back to the shell, then selects [tab].
  void switchTab(ShellTab tab) {
    navigatorKey.currentState?.popUntil((route) => route.isFirst);
    controller.value = tab;
  }

  /// The scope, without rebuilding the caller on tab changes (use in callbacks).
  static ShellScope of(BuildContext context) {
    final scope = maybeOf(context);
    if (scope == null) {
      throw FlutterError('ShellScope not found. It is provided by BpediaApp.');
    }
    return scope;
  }

  /// The scope, or null outside `BpediaApp`.
  static ShellScope? maybeOf(BuildContext context) {
    final widget = context
        .getElementForInheritedWidgetOfExactType<ShellScope>()
        ?.widget;
    return widget is ShellScope ? widget : null;
  }

  /// The selected tab, rebuilding the caller when it changes.
  static ShellTab tabOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ShellScope>();
    if (scope == null) {
      throw FlutterError('ShellScope not found. It is provided by BpediaApp.');
    }
    return scope.currentTab;
  }
}

/// Home route: four tabs in an [IndexedStack] (built on first visit, kept
/// alive afterwards) with a [NavigationBar]. The Hadiah tab shows a dot when
/// the check-in or the Saturday spin is available, and holds background music
/// while selected. Back on a non-home tab returns to Beranda.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final Set<ShellTab> _visited = <ShellTab>{};
  late final AppLifecycleListener _lifecycle;
  ShellController? _controller;
  AppState? _app;
  SoundService? _sound;
  bool _holdingMusic = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onStateChange: _onLifecycleChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = AppScope.read(context);
    _app = app;
    _sound = app.sound;
    final controller = ShellScope.of(context).controller;
    if (!identical(controller, _controller)) {
      _controller?.removeListener(_syncMusic);
      _controller = controller..addListener(_syncMusic);
      _syncMusic();
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _controller?.removeListener(_syncMusic);
    if (_holdingMusic) _sound?.stopMusic();
    super.dispose();
  }

  void _syncMusic() {
    final sound = _sound;
    final controller = _controller;
    if (sound == null || controller == null) return;
    final wantMusic = controller.value == ShellTab.rewards;
    if (wantMusic == _holdingMusic) return;
    _holdingMusic = wantMusic;
    if (wantMusic) {
      sound.startMusic();
    } else {
      sound.stopMusic();
    }
  }

  void _onLifecycleChanged(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _sound?.setForeground(true);
        _app?.refreshDay();
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _sound?.setForeground(false);
      case AppLifecycleState.inactive:
        break;
    }
  }

  void _select(int index) {
    final tab = ShellTab.values[index];
    final scope = ShellScope.of(context);
    if (tab != scope.currentTab) AppScope.read(context).haptics.selection();
    scope.switchTab(tab);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final tab = ShellScope.tabOf(context);
    _visited.add(tab);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rewardsReady = app.canCheckIn || app.canSpin;
    final overlayStyle =
        theme.appBarTheme.systemOverlayStyle ??
        (theme.brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: PopScope<Object?>(
        canPop: tab == ShellTab.home,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) ShellScope.of(context).switchTab(ShellTab.home);
        },
        child: Scaffold(
          body: IndexedStack(
            index: tab.index,
            children: <Widget>[
              for (final candidate in ShellTab.values)
                _TabSlot(
                  active: candidate == tab,
                  child: _visited.contains(candidate)
                      ? _pageFor(candidate)
                      : const SizedBox.shrink(),
                ),
            ],
          ),
          bottomNavigationBar: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: scheme.outlineVariant)),
            ),
            child: NavigationBar(
              selectedIndex: tab.index,
              onDestinationSelected: _select,
              destinations: <Widget>[
                for (final candidate in ShellTab.values)
                  NavigationDestination(
                    label: candidate.label,
                    icon: _NavIcon(
                      name: BrandIcons.mono(candidate.iconName),
                      color: scheme.onSurfaceVariant,
                      showDot: candidate == ShellTab.rewards && rewardsReady,
                    ),
                    selectedIcon: _NavIcon(
                      name: candidate.iconName,
                      showDot: candidate == ShellTab.rewards && rewardsReady,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _pageFor(ShellTab tab) {
    switch (tab) {
      case ShellTab.home:
        return const HomePage();
      case ShellTab.rewards:
        return const RewardsHubPage();
      case ShellTab.orders:
        return const OrdersPage();
      case ShellTab.account:
        return const AccountPage();
    }
  }
}

/// Keeps an inactive tab alive but paused: no tickers, no focus, and no
/// hero flights out of a tab the user cannot see.
class _TabSlot extends StatelessWidget {
  const _TabSlot({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TickerMode(
      enabled: active,
      child: HeroMode(
        enabled: active,
        child: ExcludeFocus(excluding: !active, child: child),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({required this.name, required this.showDot, this.color});

  final String name;
  final bool showDot;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: showDot ? 'Ada hadiah yang siap diambil' : null,
      child: Badge(
        isLabelVisible: showDot,
        smallSize: 8,
        child: BrandIcon(name, color: color),
      ),
    );
  }
}
