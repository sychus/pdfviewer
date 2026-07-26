import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../domain/entities/document_id.dart';
import 'document_bytes.dart';

/// Computes a document's identity as a partial fingerprint of its content:
///
/// ```
/// sha256( first N bytes ‖ last N bytes ‖ total size )
/// ```
///
/// ## Why partial and not the whole file
///
/// The cost is CONSTANT, not proportional to the size of the PDF. A 500MB
/// document reads 128KB, same as a 2MB one. Hashing the whole file would give a
/// mathematically perfect identity, but would force reading 500MB before the
/// first page renders — exactly the opposite of what we want.
///
/// ## Why both ends and not just the start
///
/// A PDF opens with the `%PDF-1.x` header and the catalog, and closes with the
/// `xref` table and the `trailer`. Two documents produced by the same tool share
/// much of their leading bytes; what separates them is at the end. Taking both
/// ends plus the size makes collisions between distinct PDFs negligible in
/// practice.
///
/// ## What survives and what does not
///
/// Survives moving, renaming and copying the file, Android's ephemeral
/// `content://` URIs, and iOS container UUID changes.
///
/// Does NOT survive modifying the file: different content is a different
/// identity. That is the correct behaviour — if the document changed, page 47 is
/// no longer the same page 47.
final class FingerprintDocumentIdentity {
  const FingerprintDocumentIdentity({this.chunkSize = 64 * 1024})
      : assert(chunkSize > 0, 'chunk size must be positive');

  /// How many bytes are read from each end.
  final int chunkSize;

  Future<DocumentId> compute(DocumentBytes bytes) async {
    final size = await bytes.length();

    // For files smaller than the chunk the two windows overlap and end up
    // being the whole file counted twice. Redundant but correct, and it avoids
    // a special case.
    final window = size < chunkSize ? size : chunkSize;

    final head = await bytes.read(offset: 0, length: window);
    final tail = await bytes.read(offset: size - window, length: window);

    final buffer = BytesBuilder(copy: false)
      ..add(head)
      ..add(tail)
      ..add(utf8.encode('$size'));

    return DocumentId('sha256-${sha256.convert(buffer.takeBytes())}');
  }
}
