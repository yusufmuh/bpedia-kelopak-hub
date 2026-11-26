import 'package:flutter_test/flutter_test.dart';
import 'package:kelopak_hub/src/core/format.dart';

void main() {
  test('rupiahCompact shortens thousands and millions for narrow tiles', () {
    expect(rupiahCompact(900), 'Rp900');
    expect(rupiahCompact(1000), 'Rp1rb');
    expect(rupiahCompact(12500), 'Rp12,5rb');
    expect(rupiahCompact(40000), 'Rp40rb');
    expect(rupiahCompact(40999), 'Rp40,9rb');
    expect(rupiahCompact(1500000), 'Rp1,5jt');
    expect(rupiahCompact(-25000), '-Rp25rb');
  });
}
