// lib/domain/entities/open_result.dart

/// What `OpenDocument` hands back to the UI layer.
///
/// The first page is returned eagerly so the UI can paint as fast as
/// possible. The full document handle resolves later in the background.
class OpenResult {
  const OpenResult({
    required this.firstPageIndex,
    required this.totalPages,
    required this.documentId,
    required this.firstPageRendered,
    required this.documentReady,
  });

  /// 0-based index of the first page (always 0 today, but kept here so a
  /// future "resume at last page" change doesn't ripple through callers).
  final int firstPageIndex;

  /// Total number of pages in the document. Reported as soon as the
  /// cross-ref table is parsed — does not wait for full ingestion.
  final int totalPages;

  /// The document's stable identity (content fingerprint).
  final String documentId;

  /// The first page, already rendered at full resolution. Ready to paint.
  final Object firstPageRendered;

  /// Resolves once the document is fully parsed and all pages are
  /// queryable. Most UI never needs to await this.
  final Future<void> documentReady;
}
