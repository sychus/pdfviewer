import 'document_id.dart';
import 'document_source.dart';

/// An open PDF document.
///
/// Pure model: knows nothing about pdfrx, the filesystem, or Flutter.
final class Document {
  const Document({
    required this.id,
    required this.source,
    required this.title,
    required this.pageCount,
  }) : assert(pageCount > 0, 'a document has at least one page');

  /// Stable content-derived identity. The key for everything we persist about
  /// this document.
  final DocumentId id;

  /// Where the file was when we opened it. Useful for reopening it and for
  /// displaying it in the UI. NOT for comparing documents.
  final DocumentSource source;

  final String title;

  final int pageCount;

  /// Pages are 1-based throughout the domain, matching what the user sees.
  /// Converting to 0-based, where needed, is the concern of the layer that
  /// needs it.
  bool containsPage(int page) => page >= 1 && page <= pageCount;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Document && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
