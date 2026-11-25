/// Dokumen tersimpan sistem Kelopak: kunci [kelopakDocumentKey],
/// `"schema": 1`, ber-`revision`.
///
/// Dokumen yang hilang, rusak, atau berskema lain dimuat sebagai keadaan baru
/// dan tidak pernah membuat aplikasi berhenti.
library;

import '../domain/state.dart';
import 'json_reader.dart';
import 'key_value_store.dart';
import 'revisioned_document.dart';

/// Kunci penyimpanan dokumen Kelopak v3.
const String kelopakDocumentKey = 'bpedia_kelopak_v3';

/// Versi skema yang ditulis ke dokumen.
const int kelopakDocumentSchema = 1;

/// Semua yang disimpan sistem Kelopak.
final class KelopakDocument {
  KelopakDocument({required this.state, this.revision = 0});

  /// Keadaan pemakaian pertama.
  factory KelopakDocument.fresh() => KelopakDocument(state: KelopakState());

  /// Mengurai dokumen skema 1; melempar [FormatException] bila tidak sah.
  factory KelopakDocument.fromJson(Object? source) {
    final json = asJsonMap(source, 'document');
    if (readInt(json, 'schema') != kelopakDocumentSchema) {
      throw const FormatException('Unknown schema');
    }
    final revision = readInt(json, 'revision', fallback: 0);
    if (revision < 0) throw const FormatException('Negative revision');
    return KelopakDocument(state: _stateOf(json), revision: revision);
  }

  /// Mengurai [raw]; null, JSON rusak, atau skema lain memberi
  /// [KelopakDocument.fresh].
  factory KelopakDocument.decode(String? raw) {
    final snapshot = storage(MemoryKeyValueStore()).decode(raw);
    return snapshot == null
        ? KelopakDocument.fresh()
        : KelopakDocument(state: snapshot.value, revision: snapshot.revision);
  }

  /// Data hadiah pengguna.
  final KelopakState state;

  /// Pencacah simpan dokumen (0 untuk dokumen yang belum pernah disimpan).
  final int revision;

  /// Pembaca dan penulis dokumen ini di [store].
  static RevisionedDocument<KelopakState> storage(KeyValueStore store) =>
      RevisionedDocument<KelopakState>(
        store: store,
        key: kelopakDocumentKey,
        schema: kelopakDocumentSchema,
        fromJson: _stateOf,
        toJson: (state) => <String, Object?>{'state': state.toJson()},
      );

  /// Membaca dan mengurai dokumen dari [store]. Galat `KeyValueStore.read`
  /// diteruskan supaya pemanggil tidak menimpa data yang gagal dibaca.
  static Future<KelopakDocument> load(KeyValueStore store) async =>
      KelopakDocument.decode(await store.read(kelopakDocumentKey));

  /// Menulis dokumen ke [store].
  Future<void> save(KeyValueStore store) =>
      store.write(kelopakDocumentKey, encode());

  /// Salinan dengan [revision] diganti.
  KelopakDocument withRevision(int revision) =>
      KelopakDocument(state: state, revision: revision);

  /// Teks JSON dokumen.
  String encode() => storage(MemoryKeyValueStore()).encode(state, revision);

  /// Menyerialkan dokumen.
  Map<String, Object?> toJson() => <String, Object?>{
    'schema': kelopakDocumentSchema,
    'revision': revision,
    'state': state.toJson(),
  };

  static KelopakState _stateOf(JsonMap json) => json['state'] == null
      ? KelopakState()
      : KelopakState.fromJson(json['state']);
}
