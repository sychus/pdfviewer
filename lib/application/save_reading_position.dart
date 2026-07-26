import '../domain/entities/document_id.dart';
import '../domain/entities/reading_position.dart';
import '../domain/repositories/position_store.dart';

/// Records how far the user has read.
///
/// The clock is injected rather than called directly. `DateTime.now()` buried
/// inside a use case makes its output depend on when the test runs, which is
/// the difference between a test that asserts behaviour and a test that
/// asserts "close enough".
final class SaveReadingPosition {
  const SaveReadingPosition(this.positions, {this.clock = DateTime.now});

  final PositionStore positions;
  final DateTime Function() clock;

  Future<void> call(DocumentId document, int page) => positions.save(
        ReadingPosition(
          documentId: document,
          page: page,
          updatedAt: clock(),
        ),
      );
}
