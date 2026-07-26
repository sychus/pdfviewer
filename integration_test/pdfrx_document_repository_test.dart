import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pdfviewer/domain/entities/document_source.dart';
import 'package:pdfviewer/domain/repositories/document_repository.dart';
import 'package:pdfviewer/infrastructure/pdf_engine.dart';
import 'package:pdfviewer/infrastructure/pdfrx_document_repository.dart';

import 'support/pdf_builder.dart';

/// Exercises the repository against real PDFium, not a mock.
///
/// Unit tests cover the fingerprint algorithm in isolation. This covers what a
/// mock can never tell us: that pdfrx actually opens a document, that the
/// engine was initialised correctly, and that page count from PDFium plus
/// identity from our own byte reader compose into a valid domain object.
///
/// Fixtures are generated at runtime rather than read from `test/fixtures/`.
/// That is not a style choice — on macOS the test process runs inside the app's
/// sandbox container, so a project-relative path resolves to
/// `~/Library/Containers/<bundle-id>/Data/...` and the file is simply not there.
/// The same sandboxing is why we never key documents by path.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  initializePdfEngine();

  const repository = PdfrxDocumentRepository();

  late Directory workspace;

  setUp(() => workspace = Directory.systemTemp.createTempSync('pdfviewer'));
  tearDown(() => workspace.deleteSync(recursive: true));

  /// Writes a valid PDF into the workspace and returns where it landed.
  DocumentSource write(String name, {int pages = 1}) {
    final file = File('${workspace.path}/$name')
      ..writeAsBytesSync(buildPdf(pageCount: pages));
    return DocumentSource(file.path);
  }

  group('PdfrxDocumentRepository', () {
    testWidgets('opens a real PDF and reports its page count', (_) async {
      final document = await repository.open(write('report.pdf', pages: 3));

      expect(document.pageCount, 3);
      expect(document.title, 'report.pdf');
      expect(document.containsPage(3), isTrue);
      expect(document.containsPage(4), isFalse);
    });

    testWidgets('identity is tagged and stable across opens', (_) async {
      final source = write('stable.pdf');

      final first = await repository.open(source);
      final second = await repository.open(source);

      expect(first.id.value, startsWith('sha256-'));
      expect(first.id, second.id);
      expect(first, second); // Document equality IS identity equality.
    });

    testWidgets('a renamed copy is the same document', (_) async {
      // The whole reason we fingerprint content instead of trusting paths.
      final original = write('original.pdf');
      final elsewhere = Directory.systemTemp.createTempSync('pdfviewer-copy');
      addTearDown(() => elsewhere.deleteSync(recursive: true));

      final copy = await File(original.uri).copy('${elsewhere.path}/renamed.pdf');

      final a = await repository.open(original);
      final b = await repository.open(DocumentSource(copy.path));

      expect(b.id, a.id, reason: 'same content, same identity');
      expect(b.title, 'renamed.pdf', reason: 'the title follows the file');
    });

    testWidgets('different documents get different identities', (_) async {
      final one = await repository.open(write('one.pdf', pages: 1));
      final two = await repository.open(write('two.pdf', pages: 5));

      expect(two.id, isNot(one.id));
    });

    testWidgets('a non-PDF fails with a domain exception', (_) async {
      final junk = File('${workspace.path}/not-really.pdf')
        ..writeAsStringSync('this is definitely not a PDF');

      await expectLater(
        repository.open(DocumentSource(junk.path)),
        throwsA(isA<DocumentOpenException>()),
      );
    });

    testWidgets('a missing file fails with a domain exception', (_) async {
      await expectLater(
        repository.open(DocumentSource('${workspace.path}/ghost.pdf')),
        throwsA(isA<DocumentOpenException>()),
      );
    });
  });
}
