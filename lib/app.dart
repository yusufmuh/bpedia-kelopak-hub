import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/config.dart';
import 'core/theme.dart';
import 'domain/app_state.dart';
import 'ui/shell.dart';

/// Root widget: themes, theme mode from settings, Indonesian framework
/// strings, text scale capped at 200% and the [ShellScope] that lets any
/// route switch bottom-navigation tabs.
class BpediaApp extends StatefulWidget {
  const BpediaApp({super.key});

  /// The only UI language, also for built-in tooltips and labels ("Kembali").
  static const Locale locale = Locale('id');

  /// Locales the app supports.
  static const List<Locale> supportedLocales = <Locale>[locale];

  /// Material, Cupertino and widgets localizations for [locale].
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      GlobalMaterialLocalizations.delegates;

  @override
  State<BpediaApp> createState() => _BpediaAppState();
}

class _BpediaAppState extends State<BpediaApp> {
  static final ThemeData _lightTheme = buildLightTheme();
  static final ThemeData _darkTheme = buildDarkTheme();

  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final ShellController _shell = ShellController();

  @override
  void dispose() {
    _shell.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = AppScope.of(context).settings.themeMode;
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      locale: BpediaApp.locale,
      supportedLocales: BpediaApp.supportedLocales,
      localizationsDelegates: BpediaApp.localizationsDelegates,
      navigatorKey: _navigatorKey,
      theme: _lightTheme,
      darkTheme: _darkTheme,
      themeMode: themeMode,
      home: const AppShell(),
      builder: (context, child) => ShellScope(
        controller: _shell,
        navigatorKey: _navigatorKey,
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 2.0,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}
