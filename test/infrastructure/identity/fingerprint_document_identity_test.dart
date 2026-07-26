import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdfviewer/infrastructure/identity/document_bytes.dart';
import 'package:pdfviewer/infrastructure/identity/fingerprint_document_identity.dart';

/// In-memory [DocumentBytes]. No disk, no platform, no Flutter.
/// This is exactly what abstracting byte access buys us.
final class _InMemoryBytes implements DocumentBytes {
  _InMemoryBytes(String content) : data = Uint8List.fromList(utf8.encode(content));

  final Uint8List data;

  @override
  Future<int> length() async => data.length;

  @override
  Future<Uint8List> read({required int offset, required int length}) async =>
      Uint8List.sublistView(data, offset, math.min(offset + length, data.length));
}

void main() {
  // Small chunk so the edge cases stay readable by hand.
  const identity = FingerprintDocumentIdentity(chunkSize: 4);

  Future<String> idOf(String content) async =>
      (await identity.compute(_InMemoryBytes(content))).value;

  group('FingerprintDocumentIdentity', () {
    test('the same content always yields the same identity', () async {
      expect(await idOf('%PDF-1.7 body xref'), await idOf('%PDF-1.7 body xref'));
    });

    test('two copies of a document are the same document', () async {
      // The real case: the user has the same PDF in Downloads and in Documents.
      // Different instances, different locations, one identity.
      final inDownloads = _InMemoryBytes('%PDF-1.7 body xref');
      final inDocuments = _InMemoryBytes('%PDF-1.7 body xref');

      expect(
        await identity.compute(inDownloads),
        await identity.compute(inDocuments),
      );
    });

    test('different content yields a different identity', () async {
      expect(await idOf('%PDF-1.7 one'), isNot(await idOf('%PDF-1.7 two')));
    });

    test('same head and tail, different size -> different identity', () async {
      // This is why the size goes into the hash.
      expect(
        await idOf('AAAAxxxxZZZZ'), // 12 bytes
        isNot(await idOf('AAAAxxxxxxxxZZZZ')), // 16 bytes
      );
    });

    test('same size and head, different tail -> different identity', () async {
      // This is why we read BOTH ends and not just the start: two PDFs from the
      // same generator share a header, and differ in the trailing xref.
      expect(
        await idOf('AAAAxxxxZZZZ'),
        isNot(await idOf('AAAAxxxxYYYY')),
      );
    });

    test('KNOWN LIMITATION: only the middle changed -> same identity', () async {
      // This is NOT a bug, it is the explicit price of a partial fingerprint.
      // Tested on purpose so nobody "fixes" it without understanding that
      // fixing it means reading the whole file again.
      expect(
        await idOf('AAAAxxxxZZZZ'),
        await idOf('AAAAyyyyZZZZ'),
      );
    });

    test('a file smaller than the chunk does not blow up', () async {
      expect(await idOf('%P'), isNotEmpty);
    });

    test('an empty file does not blow up', () async {
      expect(await idOf(''), isNotEmpty);
    });

    test('the identity is tagged with its algorithm', () async {
      // The prefix makes algorithm migration unambiguous: if we switch later,
      // old identities remain recognisable.
      expect(await idOf('%PDF-1.7'), startsWith('sha256-'));
    });
  });
}
