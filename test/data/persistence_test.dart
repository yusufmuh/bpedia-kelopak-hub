import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kelopak_hub/data/key_value_store.dart';
import 'package:kelopak_hub/data/persistence.dart';

import '../support/test_app_state.dart';

void main() {
  final freshDocument = AppSnapshot.fresh().encode();

  test('save then load gives an equal snapshot', () async {
    final store = MemoryKeyValueStore();
    final state = await createTestAppState(store: store);
    addTearDown(state.dispose);
    state
      ..claimCheckIn()
      ..jumpToNextSaturday()
      ..claimCheckIn()
      ..spin()
      ..addToCart('gogotales-dusk-thick-mist-lip-glaze-g06')
      ..addToCart('animate-brightening-soap-80g', qty: 4);
    state.placeOrder(state.quote(useKelopak: true));
    state.markOrderReceived(state.orders.first.id);
    state.addToCart('somethinc-copy-paste-cushion-nina');

    final saved = state.snapshot();
    await saved.save(store);
    final loaded = await AppSnapshot.load(store);

    expect(loaded.encode(), saved.encode());
    expect(loaded.rewards.vouchers, hasLength(1));
    expect(loaded.shop.orders, hasLength(1));
    expect(loaded.clockOffsetDays, state.demoOffsetDays);
  });

  test('missing document loads fresh', () async {
    final loaded = await AppSnapshot.load(MemoryKeyValueStore());
    expect(loaded.encode(), freshDocument);
  });

  test('corrupt JSON loads fresh', () async {
    final store = MemoryKeyValueStore(<String, String>{
      appStateStorageKey: '{"schema": 1, "rewards": [oops',
    });
    expect((await AppSnapshot.load(store)).encode(), freshDocument);
  });

  test('unknown schema, wrong types and impossible values load fresh', () {
    final valid =
        jsonDecode(AppSnapshot.fresh().encode()) as Map<String, Object?>;
    final variants = <Map<String, Object?>>[
      <String, Object?>{...valid, 'schema': 2},
      <String, Object?>{...valid, 'schema': '1'},
      <String, Object?>{...valid, 'clockOffsetDays': -3},
      <String, Object?>{...valid, 'rewards': 'not an object'},
      <String, Object?>{
        ...valid,
        'rewards': <String, Object?>{'streak': 'three'},
      },
      <String, Object?>{
        ...valid,
        'shop': <String, Object?>{
          'cart': <Object?>[
            <String, Object?>{'productId': 'x', 'qty': 0},
          ],
        },
      },
      <String, Object?>{
        ...valid,
        'rewards': <String, Object?>{
          'vouchers': <Object?>[
            <String, Object?>{'id': 'VM-0001'},
          ],
        },
      },
    ];
    for (final variant in variants) {
      expect(AppSnapshot.decode(jsonEncode(variant)).encode(), freshDocument);
    }
    expect(AppSnapshot.decode('[]').encode(), freshDocument);
    expect(AppSnapshot.decode('').encode(), freshDocument);
  });

  test('AppState starts fresh on a corrupt document and repairs it', () async {
    final store = MemoryKeyValueStore(<String, String>{
      appStateStorageKey: 'not json at all',
    });
    final state = await createTestAppState(store: store);
    addTearDown(state.dispose);
    expect(state.balance, 0);

    state.claimCheckIn();
    await state.flush();
    final repaired = AppSnapshot.decode(store.values[appStateStorageKey]);
    expect(repaired.rewards.ledger, hasLength(1));
  });

  test('MemoryKeyValueStore reads, writes and deletes', () async {
    final store = MemoryKeyValueStore();
    expect(await store.read('k'), isNull);
    await store.write('k', 'v');
    expect(await store.read('k'), 'v');
    await store.delete('k');
    expect(await store.read('k'), isNull);
  });
}
