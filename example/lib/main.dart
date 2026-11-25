import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kelopak_hub/kelopak_hub.dart';
import 'package:kelopak_hub/kit.dart';

import 'demo_data.dart';
import 'demo_host.dart';
import 'demo_pages.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final navigatorKey = GlobalKey<NavigatorState>();
  final host = DemoHost(products: demoProducts, navigatorKey: navigatorKey);
  final controller = await KelopakController.open(
    backend: LocalKelopakBackend(
      store: MemoryKeyValueStore(),
      campaign: demoCampaign,
    ),
    host: host,
  );
  runApp(
    KelopakHubExample(
      controller: controller,
      host: host,
      navigatorKey: navigatorKey,
    ),
  );
}

/// Pengaturan tampilan contoh.
class DemoSettings extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  bool _reduceMotion = false;

  /// Tema terang atau gelap.
  ThemeMode get themeMode => _themeMode;

  set themeMode(ThemeMode value) {
    _themeMode = value;
    notifyListeners();
  }

  /// Kurangi gerak.
  bool get reduceMotion => _reduceMotion;

  set reduceMotion(bool value) {
    _reduceMotion = value;
    notifyListeners();
  }
}

/// Akses contoh ke host, controller, dan pengaturan.
class DemoServices extends InheritedWidget {
  const DemoServices({
    super.key,
    required this.host,
    required this.settings,
    required super.child,
  });

  final DemoHost host;
  final DemoSettings settings;

  static DemoServices of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DemoServices>()!;

  @override
  bool updateShouldNotify(DemoServices oldWidget) =>
      host != oldWidget.host || settings != oldWidget.settings;
}

/// Aplikasi contoh: Beranda tiruan dengan widget tanam, zona Hadiah, tiga
/// game, toko dan keranjang sederhana, serta panel demo.
class KelopakHubExample extends StatefulWidget {
  const KelopakHubExample({
    super.key,
    required this.controller,
    required this.host,
    required this.navigatorKey,
  });

  final KelopakController controller;
  final DemoHost host;
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  State<KelopakHubExample> createState() => _KelopakHubExampleState();
}

class _KelopakHubExampleState extends State<KelopakHubExample> {
  final DemoSettings _settings = DemoSettings();

  @override
  void dispose() {
    _settings.dispose();
    widget.controller.dispose();
    widget.host.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DemoServices(
      host: widget.host,
      settings: _settings,
      child: KelopakScope(
        controller: widget.controller,
        child: ListenableBuilder(
          listenable: _settings,
          builder: (context, _) => MaterialApp(
            title: 'Zona Hadiah Kelopak',
            debugShowCheckedModeBanner: false,
            navigatorKey: widget.navigatorKey,
            theme: kelopakPreviewTheme(Brightness.light),
            darkTheme: kelopakPreviewTheme(Brightness.dark),
            themeMode: _settings.themeMode,
            routes: <String, WidgetBuilder>{
              ...kelopakRoutes,
              '/': (context) => const DemoHomePage(),
            },
            builder: (context, child) => ReduceMotion(
              enabled: _settings.reduceMotion,
              child: MissionCompleteCelebration(
                navigatorKey: widget.navigatorKey,
                child: child!,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Beranda tiruan: strip dompet dan strip "Main bareng Bipy" seperti di
/// aplikasi Bpedia, ditambah pintasan ke toko, keranjang, dan panel demo.
class DemoHomePage extends StatelessWidget {
  const DemoHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final services = DemoServices.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surfaceDim,
      appBar: AppBar(
        title: const Text('Beranda (contoh)'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Keranjang',
            icon: const Icon(Icons.shopping_bag_outlined),
            onPressed: services.host.openCart,
          ),
          IconButton(
            tooltip: 'Panel demo',
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => unawaited(
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const DemoPanelPage()),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: <Widget>[
          const KelopakWalletStrip(),
          const SizedBox(height: 16),
          const KelopakGameStrip(),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: CandyButton(
                    label: 'Zona Hadiah',
                    onPressed: () => KelopakNavigation.openPath(
                      context,
                      KelopakPaths.rewards,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CandyButton(
                    label: 'Belanja',
                    variant: CandyVariant.tonal,
                    onPressed: services.host.openShop,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
