import '../domain/entities/document.dart';
import '../domain/entities/document_source.dart';
import '../domain/entities/reading_position.dart';
import '../domain/repositories/document_repository.dart';
import '../domain/repositories/position_store.dart';

/// A document, plus the page the user should land on.
typedef OpenedDocument = ({Document document, int resumeAt});

/// Opens a document and resolves where to resume reading it.
///
/// This use case exists now, and did not in Phase 2, because it finally has
/// something to do: it composes two ports that neither one could coordinate on
/// its own. A use case that only forwards a single call is not a layer, it is
/// a file.
final class OpenDocument {
  const OpenDocument({required this.documents, required this.positions});

  final DocumentRepository documents;
  final PositionStore positions;

  /// Throws [DocumentOpenException] if the document cannot be opened.
  ///
  /// Failing to *read the stored position*, on the other hand, is never fatal:
  /// losing your place is an annoyance, not a reason to refuse to open a
  /// document the user asked for.
  Future<OpenedDocument> call(DocumentSource source) async {
    final document = await documents.open(source);

    ReadingPosition? saved;
    try {
      saved = await positions.load(document.id);
    } catch (_) {
      saved = null;
    }

    // The upper bound is the real work here, and it is reachable: identity is
    // a partial fingerprint, so two documents differing only in their middle
    // bytes share an identity — a limitation pinned by a test in the
    // fingerprint suite. If such a pair also differs in page count, the stored
    // page points past the end.
    //
    // The lower bound is defence in depth: the store already rejects pages
    // below one at the boundary. Costs nothing to keep, and this is the only
    // place that knows the document's actual length.
    final resumeAt = saved == null ? 1 : saved.page.clamp(1, document.pageCount);

    return (document: document, resumeAt: resumeAt);
  }
}
