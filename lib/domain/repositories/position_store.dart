import '../entities/document_id.dart';
import '../entities/reading_position.dart';

/// Port: persist how far the user had read, per document.
///
/// The key is always the [DocumentId], never the path. That is why moving or
/// renaming a file does not lose the reading position.
abstract interface class PositionStore {
  /// Returns `null` if this document has never been opened.
  Future<ReadingPosition?> load(DocumentId id);

  Future<void> save(ReadingPosition position);

  Future<void> clear(DocumentId id);
}
