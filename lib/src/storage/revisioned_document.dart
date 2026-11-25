/// Dokumen JSON tunggal ber-`revision` di atas [KeyValueStore].
///
/// Setiap penulisan menaikkan revisi. Sebelum menulis, dokumen tersimpan
/// dibaca lagi: bila instans lain (tab browser kedua) sudah menyimpan revisi
/// yang lebih baru, dokumen itu yang dipakai, bukan ditimpa.
library;

import 'dart:convert';

import 'json_reader.dart';
import 'key_value_store.dart';

/// Isi dokumen beserta revisinya.
final class DocumentSnapshot<T> {
  const DocumentSnapshot({required this.value, required this.revision});

  /// Isi dokumen.
  final T value;

  /// Pencacah simpan (0 untuk dokumen yang belum pernah disimpan).
  final int revision;
}

/// Hasil [RevisionedDocument.save].
sealed class DocumentSave<T> {
  const DocumentSave();
}

/// Dokumen ditulis dengan revisi [revision].
final class DocumentWritten<T> extends DocumentSave<T> {
  const DocumentWritten(this.revision);

  /// Revisi yang baru ditulis.
  final int revision;
}

/// Tidak ditulis: instans lain sudah menyimpan [newer], yang kini berlaku.
final class DocumentSuperseded<T> extends DocumentSave<T> {
  const DocumentSuperseded(this.newer);

  /// Dokumen yang lebih baru di penyimpanan.
  final DocumentSnapshot<T> newer;
}

/// Pembaca dan penulis satu dokumen bertipe [T] di kunci [key].
///
/// Bentuk tersimpan: `{"schema": n, "revision": n, ...isi}`. [toJson]
/// memberi isi; [fromJson] menerima seluruh objek dan melempar
/// [FormatException] bila isinya tidak sah.
final class RevisionedDocument<T> {
  RevisionedDocument({
    required KeyValueStore store,
    required this.key,
    required this.schema,
    required T Function(JsonMap json) fromJson,
    required JsonMap Function(T value) toJson,
  }) : _store = store,
       _fromJson = fromJson,
       _toJson = toJson;

  /// Kunci penyimpanan dokumen.
  final String key;

  /// Versi skema yang ditulis dan diterima.
  final int schema;

  final T Function(JsonMap json) _fromJson;
  final JsonMap Function(T value) _toJson;
  KeyValueStore _store;
  int _revision = 0;

  /// Penyimpanan yang dipakai (memori setelah [useMemoryFallback]).
  KeyValueStore get store => _store;

  /// Revisi dokumen yang terakhir dibaca atau ditulis instans ini.
  int get revision => _revision;

  /// Beralih ke penyimpanan memori, supaya data perangkat yang tidak bisa
  /// dibaca tidak pernah ditimpa.
  void useMemoryFallback() {
    _store = MemoryKeyValueStore();
    _revision = 0;
  }

  /// Teks JSON dokumen berisi [value] pada [revision].
  String encode(T value, int revision) => jsonEncode(<String, Object?>{
    'schema': schema,
    'revision': revision,
    ..._toJson(value),
  });

  /// Mengurai [raw]. Null untuk teks kosong, JSON rusak, skema lain, atau isi
  /// yang tidak sah: dokumen seperti itu tidak bisa dipercaya sama sekali.
  DocumentSnapshot<T>? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = asJsonMap(jsonDecode(raw), 'document');
      if (readInt(json, 'schema') != schema) return null;
      final revision = readInt(json, 'revision', fallback: 0);
      if (revision < 0) return null;
      return DocumentSnapshot<T>(value: _fromJson(json), revision: revision);
    } catch (_) {
      return null;
    }
  }

  /// Teks mentah di [key], atau null. Galat penyimpanan diteruskan supaya
  /// pemanggil tidak menimpa data yang gagal dibaca.
  Future<String?> readRaw() => _store.read(key);

  /// Membaca dokumen dan mencatat revisinya. Null bila tidak ada atau rusak.
  Future<DocumentSnapshot<T>?> load() async {
    final snapshot = decode(await readRaw());
    _revision = snapshot?.revision ?? 0;
    return snapshot;
  }

  /// Dokumen tersimpan bila revisinya lebih baru dari milik instans ini
  /// (lalu revisi itu dicatat); selain itu null.
  Future<DocumentSnapshot<T>?> readNewer() async {
    final stored = decode(await readRaw());
    if (stored == null || stored.revision <= _revision) return null;
    _revision = stored.revision;
    return stored;
  }

  /// Menulis [value] dengan revisi berikutnya, kecuali instans lain sudah
  /// menyimpan revisi yang lebih baru.
  Future<DocumentSave<T>> save(T value) async {
    final newer = await readNewer();
    if (newer != null) return DocumentSuperseded<T>(newer);
    final next = _revision + 1;
    await _store.write(key, encode(value, next));
    _revision = next;
    return DocumentWritten<T>(next);
  }
}
