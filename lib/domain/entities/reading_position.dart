import 'document_id.dart';

/// How far the user had read.
///
/// We store ONLY the page, deliberately. Not the scroll offset, not the zoom.
///
/// Why? Because neither is portable. The offset within a page depends on zoom
/// level, screen size and orientation: restoring "1340 pixels down" on a phone
/// from what was saved on a desktop monitor means nothing. A page, on the other
/// hand, is the same page on any device.
///
/// It is also the unit the user actually thinks in: nobody remembers "I was 63%
/// into page 47", they remember "I was on page 47".
final class ReadingPosition {
  const ReadingPosition({
    required this.documentId,
    required this.page,
    required this.updatedAt,
  }) : assert(page >= 1, 'pages are 1-based');

  final DocumentId documentId;

  /// 1-based, matching the numbering the user sees.
  final int page;

  final DateTime updatedAt;

  ReadingPosition moveTo(int newPage, {required DateTime now}) =>
      ReadingPosition(documentId: documentId, page: newPage, updatedAt: now);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReadingPosition &&
          other.documentId == documentId &&
          other.page == page &&
          other.updatedAt == updatedAt);

  @override
  int get hashCode => Object.hash(documentId, page, updatedAt);
}
