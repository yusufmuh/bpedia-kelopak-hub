import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kelopak_hub/kelopak_hub.dart';

import '../domain/fixtures.dart';

KelopakState busyState() {
  final engine = KelopakEngine(KelopakState(), campaign: testCampaign());
  engine
    ..claimCheckIn(tuesday)
    ..claimCheckIn(saturday)
    ..spin(today: saturday, roll: 0, landingSeed: 4);
  place(engine, 'BP-1', <CheckoutLine>[
    line(missionCodes[0], 35000),
    line(missionCodes[1], 10000, quantity: 4),
  ], today: saturday);
  engine.completeOrder('BP-1', saturday + 1);
  return engine.state;
}

void main() {
  final freshDocument = KelopakDocument.fresh().encode();

  test('save then load gives an equal document', () async {
    final store = MemoryKeyValueStore();
    final saved = KelopakDocument(state: busyState(), revision: 4);
    await saved.save(store);
    expect(store.values.keys, <String>[kelopakDocumentKey]);

    final loaded = await KelopakDocument.load(store);
    expect(loaded.encode(), saved.encode());
    expect(loaded.revision, 4);
    expect(loaded.state.vouchers, hasLength(1));
    expect(loaded.state.orders, hasLength(1));
    expect(loaded.state.gifts.single.status, GiftStatus.received);
    expect(KelopakDocument.fromJson(saved.toJson()).encode(), saved.encode());
    expect(saved.withRevision(5).revision, 5);
  });

  test('missing document loads fresh', () async {
    final loaded = await KelopakDocument.load(MemoryKeyValueStore());
    expect(loaded.encode(), freshDocument);
    expect(loaded.revision, 0);
  });

  test('corrupt JSON loads fresh', () async {
    final store = MemoryKeyValueStore(<String, String>{
      kelopakDocumentKey: '{"schema": 1, "state": [oops',
    });
    expect((await KelopakDocument.load(store)).encode(), freshDocument);
  });

  test('unknown schema, wrong types and impossible values load fresh', () {
    final valid = jsonDecode(freshDocument) as Map<String, Object?>;
    final busy = busyState().toJson();
    final order = (busy['orders']! as List<Object?>).single! as Map;
    final variants = <Map<String, Object?>>[
      <String, Object?>{...valid, 'schema': 2},
      <String, Object?>{...valid, 'schema': '1'},
      <String, Object?>{...valid, 'revision': -3},
      <String, Object?>{...valid, 'state': 'not an object'},
      <String, Object?>{
        ...valid,
        'state': <String, Object?>{'streak': 'three'},
      },
      <String, Object?>{
        ...valid,
        'state': <String, Object?>{
          ...busy,
          'orders': <Object?>[
            <String, Object?>{
              ...order.cast<String, Object?>(),
              'lines': <Object?>[
                <String, Object?>{
                  'productCode': 'x',
                  'unitPrice': 1000,
                  'quantity': 0,
                },
              ],
            },
          ],
        },
      },
      <String, Object?>{
        ...valid,
        'state': <String, Object?>{
          'vouchers': <Object?>[
            <String, Object?>{'id': 'VM-0001'},
          ],
        },
      },
      <String, Object?>{
        ...valid,
        'state': <String, Object?>{
          'gifts': <Object?>[
            <String, Object?>{
              'id': 'HG-0001',
              'source': 'lottery',
              'wonDay': saturday,
            },
          ],
        },
      },
    ];
    for (final variant in variants) {
      expect(
        KelopakDocument.decode(jsonEncode(variant)).encode(),
        freshDocument,
        reason: jsonEncode(variant),
      );
    }
    expect(KelopakDocument.decode('[]').encode(), freshDocument);
    expect(KelopakDocument.decode('').encode(), freshDocument);
    expect(KelopakDocument.decode(null).encode(), freshDocument);
    expect(
      () => KelopakDocument.fromJson(<String, Object?>{...valid, 'schema': 2}),
      throwsFormatException,
    );
  });

  test('MemoryKeyValueStore reads, writes and deletes', () async {
    final store = MemoryKeyValueStore();
    expect(await store.read('k'), isNull);
    await store.write('k', 'v');
    expect(await store.read('k'), 'v');
    await store.delete('k');
    expect(await store.read('k'), isNull);
  });

  group('RevisionedDocument', () {
    test('each save raises the revision and the revision survives a '
        'reload', () async {
      final store = MemoryKeyValueStore();
      final document = KelopakDocument.storage(store);
      expect(await document.load(), isNull);
      expect(
        await document.save(KelopakState()),
        isA<DocumentWritten<KelopakState>>(),
      );
      expect(document.revision, 1);
      await document.save(busyState());
      expect(document.revision, 2);

      final reopened = KelopakDocument.storage(store);
      final snapshot = (await reopened.load())!;
      expect(snapshot.revision, 2);
      expect(snapshot.value.toJson(), busyState().toJson());
      final written =
          await reopened.save(snapshot.value) as DocumentWritten<KelopakState>;
      expect(written.revision, 3);
    });

    test('a stale writer adopts the newer document instead of '
        'overwriting it', () async {
      final store = MemoryKeyValueStore();
      final tabA = KelopakDocument.storage(store);
      final tabB = KelopakDocument.storage(store);
      await tabA.load();
      await tabB.load();

      await tabA.save(busyState());
      final result = await tabB.save(KelopakState());
      final newer = (result as DocumentSuperseded<KelopakState>).newer;
      expect(newer.revision, 1);
      expect(newer.value.orders, hasLength(1));
      expect(tabB.revision, 1);
      final stored = KelopakDocument.decode(store.values[kelopakDocumentKey]);
      expect(stored.state.orders, hasLength(1));

      final next = await tabB.save(newer.value);
      expect((next as DocumentWritten<KelopakState>).revision, 2);
    });

    test('readNewer reports a newer save once', () async {
      final store = MemoryKeyValueStore();
      final tabA = KelopakDocument.storage(store);
      final tabB = KelopakDocument.storage(store);
      expect(await tabB.readNewer(), isNull);
      await tabA.save(busyState());
      expect((await tabB.readNewer())?.revision, 1);
      expect(await tabB.readNewer(), isNull);
    });

    test('the memory fallback stops touching the broken store', () async {
      final store = MemoryKeyValueStore(<String, String>{
        kelopakDocumentKey: 'keep me',
      });
      final document = KelopakDocument.storage(store)..useMemoryFallback();
      await document.save(KelopakState());
      expect(store.values[kelopakDocumentKey], 'keep me');
      expect(document.store, isNot(same(store)));
    });
  });
}
