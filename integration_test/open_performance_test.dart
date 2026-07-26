import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:pdfviewer/domain/entities/document_source.dart';
import 'package:pdfviewer/infrastructure/identity/file_document_bytes.dart';
import 'package:pdfviewer/infrastructure/identity/fingerprint_document_identity.dart';
import 'package:pdfviewer/infrastructure/pdf_engine.dart';
import 'package:pdfviewer/infrastructure/pdfrx_document_repository.dart';

import 'support/pdf_builder.dart';

/// Phase 4, step one: measure before touching anything.
///
/// This exists to replace three claims made during design with numbers:
///
/// 1. Fingerprinting is O(1) — a 30MB document costs the same as a 3KB one.
/// 2. PDFium parses the xref on open, not the pages, so opening is cheap
///    relative to document size.
/// 3. Opening a document is dominated by neither, and is fast enough that
///    tuning `PdfViewerParams` would be premature.
///
/// Claim 1 is asserted, not just printed. The others are reported so the
/// numbers are on the record before any optimisation is attempted.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  initializePdfEngine();

  const identity = FingerprintDocumentIdentity();
  const repository = PdfrxDocumentRepository();

  late Directory workspace;
  setUpAll(() => workspace = Directory.systemTemp.createTempSync('pdfbench'));
  tearDownAll(() => workspace.deleteSync(recursive: true));

  /// Median of [runs] timings, discarding a warm-up pass. A median rather than
  /// a mean because one scheduler hiccup should not define the result.
  Future<double> medianMs(Future<void> Function() action, {int runs = 7}) async {
    await action();

    final samples = <int>[];
    for (var run = 0; run < runs; run++) {
      final watch = Stopwatch()..start();
      await action();
      watch.stop();
      samples.add(watch.elapsedMicroseconds);
    }
    samples.sort();
    return samples[samples.length ~/ 2] / 1000;
  }

  const profiles = [
    (name: 'tiny', pages: 1, lines: 20),
    (name: 'small', pages: 25, lines: 40),
    (name: 'medium', pages: 250, lines: 40),
    (name: 'large', pages: 1000, lines: 40),
    (name: 'huge', pages: 4000, lines: 40),
  ];

  testWidgets('open-path performance across document sizes', (_) async {
    final rows = <String>[];
    final fingerprintByProfile = <String, double>{};
    final totalByProfile = <String, double>{};
    final sizeByProfile = <String, int>{};

    for (final profile in profiles) {
      final file = File('${workspace.path}/${profile.name}.pdf')
        ..writeAsBytesSync(
          buildPdf(pageCount: profile.pages, linesPerPage: profile.lines),
        );

      final bytes = file.lengthSync();
      final source = DocumentSource(file.path);

      final fingerprint = await medianMs(
        () => identity.compute(FileDocumentBytes(file)),
      );

      final eager = await medianMs(() async {
        final pdf = await PdfDocument.openFile(file.path);
        await pdf.dispose();
      });

      final progressive = await medianMs(() async {
        final pdf =
            await PdfDocument.openFile(file.path, useProgressiveLoading: true);
        await pdf.dispose();
      });

      final total = await medianMs(() => repository.open(source));

      fingerprintByProfile[profile.name] = fingerprint;
      totalByProfile[profile.name] = total;
      sizeByProfile[profile.name] = bytes;

      rows.add(
        '${profile.name.padRight(8)}'
        '${'${profile.pages}p'.padLeft(7)}'
        '${_mb(bytes).padLeft(9)}'
        '${fingerprint.toStringAsFixed(2).padLeft(13)}'
        '${eager.toStringAsFixed(2).padLeft(9)}'
        '${progressive.toStringAsFixed(2).padLeft(13)}'
        '${total.toStringAsFixed(2).padLeft(11)}',
      );
    }

    // ignore: avoid_print
    print('''

── open-path performance (median of 7, macOS debug, milliseconds) ──────────────
profile   pages     size  fingerprint    eager  progressive  total open
${rows.join('\n')}
────────────────────────────────────────────────────────────────────────────────
eager       = PdfDocument.openFile(path)                      <- engine default
progressive = PdfDocument.openFile(path, progressive: true)   <- what we use
total open  = full repository.open(): fingerprint + progressive parse
''');

    // Claim 1, pinned. The size ratio between the smallest and largest fixture
    // is orders of magnitude; if fingerprinting read whole files, this would
    // fail loudly. The tolerance is deliberately generous — the point is to
    // catch an accidental switch to full-file hashing, not to police jitter.
    final sizeRatio = sizeByProfile['huge']! / sizeByProfile['tiny']!;
    final timeRatio =
        fingerprintByProfile['huge']! / fingerprintByProfile['tiny']!;

    // ignore: avoid_print
    print('fingerprint: ${sizeRatio.toStringAsFixed(0)}x the bytes, '
        '${timeRatio.toStringAsFixed(2)}x the time');

    expect(
      sizeRatio,
      greaterThan(100),
      reason: 'the fixtures must actually differ in size for this to mean much',
    );
    expect(
      timeRatio,
      lessThan(5),
      reason: 'fingerprinting must not scale with document size',
    );

    // Regression guard for progressive loading. Dropping
    // `useProgressiveLoading: true` from the repository makes opening eager
    // again — measured at 200ms for the 4000-page fixture versus 2.5ms, a
    // ratio well past this threshold. An optimisation with no test is an
    // optimisation someone deletes.
    final openRatio = totalByProfile['huge']! / totalByProfile['tiny']!;

    // ignore: avoid_print
    print('total open: ${openRatio.toStringAsFixed(2)}x from tiny to huge');

    expect(
      openRatio,
      lessThan(15),
      reason: 'opening must stay near-constant — is progressive loading still on?',
    );
  });
}

String _mb(int bytes) => bytes < 1024 * 1024
    ? '${(bytes / 1024).toStringAsFixed(0)}KB'
    : '${(bytes / 1024 / 1024).toStringAsFixed(1)}MB';
