import '../entities/document.dart';
import '../entities/document_source.dart';

/// Port: open a document given where it came from.
///
/// The implementation is the only thing that knows how to interpret a
/// [DocumentSource] (path, `content://`, security-scoped URL), and the only
/// thing that knows how the resulting document's `DocumentId` is computed.
abstract interface class DocumentRepository {
  /// Opens the document and returns its domain model, identity already
  /// resolved.
  ///
  /// Throws [DocumentOpenException] if it cannot be opened.
  Future<Document> open(DocumentSource source);
}

/// The document could not be opened: missing, not permitted, corrupt, or
/// password-protected.
final class DocumentOpenException implements Exception {
  const DocumentOpenException(this.source, {this.cause});

  final DocumentSource source;
  final Object? cause;

  @override
  String toString() => 'Could not open the document at $source'
      '${cause == null ? '' : ': $cause'}';
}
