import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kelopak_hub/kelopak_hub.dart';

import '../domain/fixtures.dart';
import '../storage/v2_fixture.dart';

/// Penyimpanan yang selalu gagal membaca atau menulis.
class BrokenStore implements KeyValueStore {
  BrokenStore({this.failReads = true, this.failWrites = true});

  final bool failReads;
  final bool failWrites;
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> read(String key) async {
    if (failReads) throw StateError('storage unavailable');
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    if (failWrites) throw StateError('quota exceeded');
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async => values.remove(key);
}

LocalKelopakBackend backendOn(KeyValueStore store, {List<int>? rolls}) =>
    LocalKelopakBackend(
      store: store,
      campaign: testCampaign(),
      random: ScriptedRandom(rolls ?? <int>[5000, 1]),
    );

Future<KelopakOrder> commit(
  LocalKelopakBackend backend,
  String orderId,
  KelopakState state,
  int today,
) async {
  final quote = KelopakView(
    state,
    campaign: backend.campaign,
  ).quote(request(<CheckoutLine>[line(otherCode, 25000)]), today: today);
  final reply = await backend.commitOrder(
    orderId: orderId,
    quote: quote,
    today: today,
  );
  return (reply.value as OrderCommitted).order;
}

void main() {
  test('starts fresh, saves every change and survives a reload', () async {
    final store = MemoryKeyValueStore();
    final backend = backendOn(store);
    expect(backend.origin, KelopakOrigin.notLoaded);
    final state = await backend.load();
    expect(backend.origin, KelopakOrigin.fresh);
    expect(state.balance, 0);
    expect(store.values, isEmpty);

    final reply = await backend.claimCheckIn(today: tuesday);
    expect(reply.value, isA<CheckInClaimed>());
    expect(reply.state.balance, 1);
    final again = await backend.claimCheckIn(today: tuesday);
    expect(again.value, isA<CheckInAlreadyClaimed>());
    await backend.flush();
    expect(backend.revision, 1);
    expect(backend.lastSaveError, isNull);

    final reloaded = backendOn(store);
    final restored = await reloaded.load();
    expect(reloaded.origin, KelopakOrigin.loaded);
    expect(reloaded.revision, 1);
    expect(restored.balance, 1);
    expect(restored.lastClaimDay, tuesday);
  });

  test('starts fresh on a corrupt document and repairs it', () async {
    final store = MemoryKeyValueStore(<String, String>{
      kelopakDocumentKey: 'not json at all',
    });
    final backend = backendOn(store);
    final state = await backend.load();
    expect(backend.origin, KelopakOrigin.corrupt);
    expect(state.balance, 0);

    await backend.claimCheckIn(today: tuesday);
    await backend.flush();
    final repaired = KelopakDocument.decode(store.values[kelopakDocumentKey]);
    expect(repaired.state.ledger, hasLength(1));
  });

  test('migrates the v2 document once and keeps the old key', () async {
    final raw = jsonEncode(v2Document());
    final store = MemoryKeyValueStore(<String, String>{v2DocumentKey: raw});
    final backend = backendOn(store);
    final state = await backend.load();
    expect(backend.origin, KelopakOrigin.migratedV2);
    expect(state.balance, 7);
    expect(state.gifts, hasLength(2));
    expect(store.values[v2DocumentKey], raw);
    expect(store.values.containsKey(kelopakDocumentKey), isTrue);

    final again = backendOn(store);
    await again.load();
    expect(again.origin, KelopakOrigin.loaded);
  });

  test('an unreadable store falls back to memory and keeps working', () async {
    final backend = backendOn(BrokenStore());
    final state = await backend.load();
    expect(backend.origin, KelopakOrigin.unreadable);
    expect(state.balance, 0);
    final reply = await backend.claimCheckIn(today: tuesday);
    expect(reply.state.balance, 1);
    expect(backend.lastSaveError, isNull);
  });

  test('a failing write is reported and the change is kept', () async {
    final backend = backendOn(BrokenStore(failReads: false));
    await backend.load();
    final reply = await backend.claimCheckIn(today: tuesday);
    expect(reply.state.balance, 1);
    expect(backend.lastSaveError, isA<StateError>());
  });

  test('spins with the drawn roll and landing seed', () async {
    final backend = backendOn(MemoryKeyValueStore(), rolls: <int>[0, 123]);
    await backend.load();
    final reply = await backend.spin(today: saturday);
    final outcome = reply.value as SpinCompleted;
    expect(outcome.record.roll, 0);
    expect(outcome.record.landingSeed, 123);
    expect(outcome.prize.kind, PrizeKind.product);
    expect(reply.state.gifts.single.source, GiftSource.wheel);
    final rejected = await backend.spin(today: saturday);
    expect(
      (rejected.value as SpinRejected).eligibility,
      SpinEligibility.alreadySpun,
    );
  });

  group('two instances on one store (second browser tab)', () {
    test('a stale instance adopts the newer document instead of '
        'overwriting it', () async {
      final store = MemoryKeyValueStore();
      final tabA = backendOn(store);
      final tabB = backendOn(store);
      await tabA.load();
      await tabB.load();

      final claimed = await tabA.claimCheckIn(today: tuesday);
      final first = await commit(tabA, 'BP-1', claimed.state, tuesday);
      await tabA.flush();
      expect(tabA.revision, 2);

      final again = await tabB.claimCheckIn(today: tuesday);
      expect(again.value, isA<CheckInAlreadyClaimed>());
      expect(tabB.adoptedUpdates, 1);
      expect(again.state.orders.single.id, first.id);
      expect(again.state.balance, 0);

      await commit(tabB, 'BP-2', again.state, tuesday);
      await tabB.flush();
      final latest = KelopakDocument.decode(store.values[kelopakDocumentKey]);
      expect(latest.state.orders, hasLength(2));
      expect(latest.revision, greaterThan(2));
    });

    test('refresh picks up a newer save once', () async {
      final store = MemoryKeyValueStore();
      final tabA = backendOn(store);
      final tabB = backendOn(store);
      await tabA.load();
      await tabB.load();

      expect(await tabB.refresh(), isNull);
      await tabA.claimCheckIn(today: tuesday);
      await tabA.flush();
      final newer = await tabB.refresh();
      expect(newer?.balance, 1);
      expect(await tabB.refresh(), isNull);
    });
  });

  test('demo tools change promo, quota and balance, and reset', () async {
    final backend = backendOn(MemoryKeyValueStore());
    await backend.load();
    expect(backend.demoTools, same(backend));

    var state = await backend.setPromoActive(false);
    expect(state.promoActive, isFalse);
    state = await backend.setWheelQuotaLeft(1, today: saturday);
    expect(
      KelopakView(state, campaign: backend.campaign).wheelQuotaLeft(saturday),
      1,
    );
    state = await backend.grantKelopak(250, today: tuesday);
    expect(state.balance, 250);
    state = await backend.reset();
    expect(state.toJson(), KelopakState().toJson());
  });
}
