import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Back navigation that works in every locale.
extension BackNavigation on WidgetTester {
  /// Taps the app bar's [BackButton]. Unlike [WidgetTester.pageBack], which
  /// looks for the English "Back" tooltip, this also works with the app's
  /// Indonesian localizations ("Kembali").
  Future<void> tapBack() async {
    final back = find.byType(BackButton);
    expect(back, findsOneWidget, reason: 'One back button expected on screen');
    await tap(back);
  }
}
