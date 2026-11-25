/// Tabel rute `/hadiah/*` untuk host.
library;

import 'package:flutter/widgets.dart';

import '../core/paths.dart';
import '../games/game_screens.dart';
import 'ledger_page.dart';
import 'my_gifts_page.dart';
import 'rewards_hub_page.dart';
import 'vouchers_page.dart';

/// Jalur zona Hadiah ke pembangun halamannya. Semua halaman membaca
/// `KelopakScope` terdekat, jadi pasang scope di atas navigator host.
///
/// ```dart
/// MaterialApp(routes: <String, WidgetBuilder>{...kelopakRoutes});
/// ```
final Map<String, WidgetBuilder> kelopakRoutes =
    Map<String, WidgetBuilder>.unmodifiable(<String, WidgetBuilder>{
      KelopakPaths.rewards: (context) => const RewardsHubPage(),
      KelopakPaths.checkIn: (context) => const KelopakCheckInScreen(),
      KelopakPaths.wheel: (context) => const KelopakWheelScreen(),
      KelopakPaths.mission: (context) => const KelopakMissionScreen(),
      KelopakPaths.myGifts: (context) => const MyGiftsPage(),
      KelopakPaths.vouchers: (context) => const VouchersPage(),
      KelopakPaths.ledger: (context) => const LedgerPage(),
    });

/// Pembangun halaman untuk [location] (boleh berisi `?kueri` atau garis
/// miring akhir), atau null bila bukan jalur zona Hadiah.
WidgetBuilder? kelopakRouteFor(String location) {
  var path = Uri.tryParse(location)?.path ?? location;
  if (!path.startsWith('/')) path = '/$path';
  if (path.length > 1 && path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  return kelopakRoutes[path];
}
