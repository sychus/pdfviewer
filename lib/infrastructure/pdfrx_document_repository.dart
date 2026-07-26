import 'dart:io';

import 'package:pdfrx/pdfrx.dart';

import '../domain/entities/document.dart';
import '../domain/entities/document_source.dart';
import '../domain/repositories/document_repository.dart';
import 'identity/file_document_bytes.dart';
import 'identity/fingerprint_document_identity.dart';

/// [DocumentRepository] backed by pdfrx (PDFium).
///
/// Opens the document only to read its metadata, then closes it. The viewer
/// widget opens the file again for rendering, so the file is parsed twice.
/// The alternative — keeping a handle alive and handing it to the UI — leaks
/// lifecycle management across layers for a saving that the benchmark shows is
/// small.
///
/// **`useProgressiveLoading: true` is not optional here.** The engine-level
/// `PdfDocument.openFile` defaults it to `false`, unlike `PdfViewer.file`,
/// which defaults it to `true`. With it off, opening eagerly loads every page
/// and cost grows linearly with page count — measured at ~0.05ms per page, so
/// roughly 200ms for a 4000-page document, spent entirely to read one integer.
/// See `integration_test/open_performance_test.dart`.
final class PdfrxDocumentRepository implements DocumentRepository {
  const PdfrxDocumentRepository({
    this.identity = const FingerprintDocumentIdentity(),
  });

  final FingerprintDocumentIdentity identity;

  @override
  Future<Document> open(DocumentSource source) async {
    final file = File(source.uri);
    PdfDocument? pdf;

    try {
      pdf = await PdfDocument.openFile(file.path, useProgressiveLoading: true);

      final pageCount = pdf.pages.length;
      if (pageCount == 0) {
        throw const FormatException('the document reports zero pages');
      }

      return Document(
        id: await identity.compute(FileDocumentBytes(file)),
        source: source,
        title: _titleOf(file),
        pageCount: pageCount,
      );
    } on DocumentOpenException {
      rethrow;
    } catch (error) {
      throw DocumentOpenException(source, cause: error);
    } finally {
      await pdf?.dispose();
    }
  }

  /// The filename — deliberately not the PDF's embedded `/Title`.
  ///
  /// Embedded titles are routinely garbage: "Microsoft Word - untitled1.doc"
  /// is the canonical example. The filename is what the user recognises,
  /// because it is what they saw in the file picker a second ago.
  static String _titleOf(File file) => file.uri.pathSegments.last;
}
