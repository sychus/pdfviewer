import 'dart:async';

import '../entities/document.dart';
import '../entities/document_source.dart';
import '../entities/rendered_page.dart';

/// Port: open a document given where it came from.
abstract interface class DocumentRepository {
  /// Opens the document and returns its domain model, identity already
  /// resolved.
  Future<Document> open(DocumentSource source);

  /// Opens the document and returns the first page already rendered,
  /// while the rest of the document loads in the background.
  ///
  /// This is the fast path for large documents: the UI can paint
  /// immediately. Background prewarm kicks in automatically for the
  /// surrounding pages.
  ///
  /// Call [OpenResult.recenter] when the user scrolls so the prewarm
  /// window follows. Call [OpenResult.close] when the document is
  /// dismissed.
  ///
  /// Throws [DocumentOpenException] if it cannot be opened.
  Future<OpenResult> openStreaming(
    DocumentSource source, {
    required int firstPageScaleNumerator,
    required int firstPageScaleDenominator,
    required int prewarmScaleNumerator,
    required int prewarmScaleDenominator,
    required int prewarmRadius,
  });
}

/// The document could not be opened: missing, not permitted, corrupt,
/// or password-protected.
final class DocumentOpenException implements Exception {
  const DocumentOpenException(this.source, {this.cause});

  final DocumentSource source;
  final Object? cause;

  @override
  String toString() => 'Could not open the document at $source'
      '${cause == null ? '' : ': $cause'}';
}

/// What [DocumentRepository.openStreaming] hands back to the UI.
class OpenResult {
  OpenResult({
    required this.document,
    required this.totalPages,
    required this.renderedPages,
    required this.recenter,
    required this.close,
    this.documentHandle,
    this.pageReady,
  });

  final Document document;

  /// Total pages, as reported by the cross-ref table.
  final int totalPages;

  /// LRU cache populated as background pages render. Use
  /// `get(pageIndex)` to pull a ready page. The UI must NOT
  /// call `dispose()` on this directly — use [close] instead.
  final RenderedPageCache renderedPages;

  /// Opaque handle to the already-opened native document. The
  /// presentation layer may downcast this to the engine-specific
  /// type (e.g. `PdfDocumentRef`) to share the open handle with
  /// the viewer widget, avoiding a second file open.
  final Object? documentHandle;

  /// Tell the streaming system the user is now looking at this
  /// 0-based page. Triggers prewarm of neighbours and cancels
  /// stale renders that are no longer relevant.
  final void Function(int pageIndex) recenter;

  /// Emits the 0-based index of each page as it finishes
  /// rendering in the background. The UI can listen to repaint.
  final Stream<int>? pageReady;

  /// Release every resource held by this streaming session:
  /// PdfDocument, cache, scheduler, stream controllers.
  final void Function() close;
}

/// Cache of rendered pages, keyed by 0-based page index.
///
/// Implemented in infrastructure (typically on top of LruBitmapCache).
abstract interface class RenderedPageCache {
  RenderedPage? get(int pageIndex);
  void put(int pageIndex, RenderedPage page);
  void remove(int pageIndex);
  void dispose();
}
