import 'package:flutter_test/flutter_test.dart';
import 'package:kelopak_hub/main.dart';

void main() {
  testWidgets('Bpedia Kelopak Hub loads and renders cleanly', (WidgetTester tester) async {
    await tester.pumpWidget(const BpediaKelopakApp());
    await tester.pumpAndSettle();

    // Verify title and wallet header
    expect(find.text('Bpedia Kelopak'), findsOneWidget);
    expect(find.text('Program Hadiah & Loyalitas'), findsOneWidget);

    // Verify 3 tabs
    expect(find.text('Check-in'), findsOneWidget);
    expect(find.text('Roda Sabtu'), findsOneWidget);
    expect(find.text('Misi Belanja'), findsOneWidget);

    // Verify Check-in view contents
    expect(find.text('Jejak tujuh hari'), findsOneWidget);
    expect(find.text('Ambil 1 Kelopak'), findsOneWidget);

    // Tap Check-in
    await tester.tap(find.text('Ambil 1 Kelopak'));
    await tester.pumpAndSettle();

    // Verify button updates to claimed state
    expect(find.text('Sudah check-in hari ini'), findsOneWidget);
  });
}
