import 'package:flutter_test/flutter_test.dart';
import 'package:pdfviewer/application/open_document.dart';
import 'package:pdfviewer/domain/entities/document.dart';
import 'package:pdfviewer/domain/entities/document_id.dart';
import 'package:pdfviewer/domain/entities/document_source.dart';
import 'package:pdfviewer/domain/entities/reading_position.dart';
import 'package:pdfviewer/domain/repositories/document_repository.dart';
import 'package:pdfviewer/domain/repositories/position_store.dart';

const _id = DocumentId('sha256-abc');
const _source = DocumentSource('/somewhere/manual.pdf');

const _manual = Document(
  id: _id,
  source: _source,
  title: 'manual.pdf',
  pageCount: 120,
);

final class _Repository implements DocumentRepository {
  const _Repository(this.document);

  final Document document;

  @override
  Future<Document> open(DocumentSource source) async => document;

  @override
  Future<OpenResult> openStreaming(
    DocumentSource source, {
    required int firstPageScaleNumerator,
    required int firstPageScaleDenominator,
    required int prewarmScaleNumerator,
    required int prewarmScaleDenominator,
    required int prewarmRadius,
  }) =>
      throw UnimplementedError('not used in these tests');
}

final class _FailingRepository implements DocumentRepository {
  const _FailingRepository();

  @override
  Future<Document> open(DocumentSource source) async =>
      throw DocumentOpenException(source);

  @override
  Future<OpenResult> openStreaming(
    DocumentSource source, {
    required int firstPageScaleNumerator,
    required int firstPageScaleDenominator,
    required int prewarmScaleNumerator,
    required int prewarmScaleDenominator,
    required int prewarmRadius,
  }) =>
      throw UnimplementedError('not used in these tests');
}

final class _Store implements PositionStore {
  _Store([this.stored]);

  ReadingPosition? stored;

  @override
  Future<ReadingPosition?> load(DocumentId id) async => stored;

  @override
  Future<void> save(ReadingPosition position) async => stored = position;

  @override
  Future<void> clear(DocumentId id) async => stored = null;
}

final class _UnreadableStore implements PositionStore {
  const _UnreadableStore();

  @override
  Future<ReadingPosition?> load(DocumentId id) async =>
      throw StateError('the store is having a bad day');

  @override
  Future<void> save(ReadingPosition position) async {}

  @override
  Future<void> clear(DocumentId id) async {}
}

ReadingPosition _at(int page) => ReadingPosition(
      documentId: _id,
      page: page,
      updatedAt: DateTime.utc(2026, 7, 25),
    );

void main() {
  group('OpenDocument', () {
    test('starts at page one when nothing was saved', () async {
      final open = OpenDocument(
        documents: const _Repository(_manual),
        positions: _Store(),
      );

      final result = await open(_source);

      expect(result.document, _manual);
      expect(result.resumeAt, 1);
    });

    test('resumes at the saved page', () async {
      final open = OpenDocument(
        documents: const _Repository(_manual),
        positions: _Store(_at(47)),
      );

      expect((await open(_source)).resumeAt, 47);
    });

    test('clamps a saved page that points past the end', () async {
      // Reachable via the partial-fingerprint limitation: two documents that
      // differ only in their middle bytes share an identity, and could differ
      // in page count. Opening must not blow up because of it.
      final open = OpenDocument(
        documents: const _Repository(_manual), // 120 pages
        positions: _Store(_at(9999)),
      );

      expect((await open(_source)).resumeAt, 120);
    });

    test('a broken store loses your place but still opens the document',
        () async {
      // Losing your position is an annoyance. Refusing to open the document
      // the user just asked for is a bug.
      final open = OpenDocument(
        documents: const _Repository(_manual),
        positions: const _UnreadableStore(),
      );

      final result = await open(_source);

      expect(result.document, _manual);
      expect(result.resumeAt, 1);
    });

    test('a document that cannot be opened still fails loudly', () async {
      final open = OpenDocument(
        documents: const _FailingRepository(),
        positions: _Store(),
      );

      await expectLater(
        open(_source),
        throwsA(isA<DocumentOpenException>()),
      );
    });
  });
}
