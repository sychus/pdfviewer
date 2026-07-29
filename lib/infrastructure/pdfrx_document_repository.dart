import 'dart:async';
import 'dart:io';

import 'package:pdfrx/pdfrx.dart';

import '../application/prewarm/prewarm_scheduler.dart';
import '../domain/entities/document.dart';
import '../domain/entities/document_source.dart';
import '../domain/entities/page_render_config.dart';
import '../domain/repositories/document_repository.dart';
import 'identity/file_document_bytes.dart';
import 'identity/fingerprint_document_identity.dart';
import 'pdfrx/pdfrx_rendered_page.dart';
import 'pdfrx/pdfrx_rendered_page_cache.dart';

/// [DocumentRepository] backed by pdfrx (PDFium).
final class PdfrxDocumentRepository implements DocumentRepository {
  const PdfrxDocumentRepository({
    this.identity = const FingerprintDocumentIdentity(),
  });

  final FingerprintDocumentIdentity identity;

  // ---------- existing fast metadata-only open ----------

  @override
  Future<Document> open(DocumentSource source) async {
    final file = File(source.uri);
    PdfDocument? pdf;

    try {
      pdf = await PdfDocument.openFile(file.path, useProgressiveLoading: true);

      final pageCount = pdf.pages.length;
      if (pageCount == 0) {
        throw const FormatException('the document reports zero pages');
      }

      return Document(
        id: await identity.compute(FileDocumentBytes(file)),
        source: source,
        title: _titleOf(file),
        pageCount: pageCount,
      );
    } on DocumentOpenException {
      rethrow;
    } catch (error) {
      throw DocumentOpenException(source, cause: error);
    } finally {
      await pdf?.dispose();
    }
  }

  // ---------- streaming open: first page fast, rest in background ----------

  @override
  Future<OpenResult> openStreaming(
    DocumentSource source, {
    required int firstPageScaleNumerator,
    required int firstPageScaleDenominator,
    required int prewarmScaleNumerator,
    required int prewarmScaleDenominator,
    required int prewarmRadius,
  }) async {
    final file = File(source.uri);

    PdfDocument? pdf;
    try {
      pdf = await PdfDocument.openFile(file.path, useProgressiveLoading: true);
      final pageCount = pdf.pages.length;
      if (pageCount == 0) {
        throw const FormatException('the document reports zero pages');
      }

      // Compute identity (reads only 128KB, constant cost).
      final documentId = await identity.compute(FileDocumentBytes(file));
      final title = _titleOf(file);

      // No eager page render here. PdfViewer handles its own rendering
      // and doing it here too doubles memory usage — which kills large
      // PDFs on memory-constrained devices.
      final cache = PdfrxRenderedPageCache(maxEntries: 32);

      final document = Document(
        id: documentId,
        source: source,
        title: title,
        pageCount: pageCount,
      );

      // Wrap the already-open PdfDocument so PdfViewer can share it
      // without opening the file a second time. autoDispose is false
      // because we manage the lifecycle ourselves via close().
      final documentRef = PdfDocumentRefDirect(
        pdf,
        autoDispose: false,
      );

      // Stream that notifies the UI when a background page is ready.
      final pageReadyController = StreamController<int>.broadcast();

      // Track pages currently being rendered so we don't launch
      // duplicate work when the scheduler re-emits for overlapping
      // windows.
      final rendering = <int>{};

      // Wire the PrewarmScheduler: it decides WHAT to render, and
      // the onRequest callback does the actual pdfrx render.
      final prewarmScale = prewarmScaleNumerator / prewarmScaleDenominator;
      final config = PageRenderConfig(
        cacheBudgetBytes: 150 * 1024 * 1024,
        prewarmScale: prewarmScale,
        prewarmRadius: prewarmRadius,
        upgradeDelay: const Duration(milliseconds: 300),
      );

      late final PrewarmScheduler scheduler;
      scheduler = PrewarmScheduler(
        totalPages: pageCount,
        currentPage: 0,
        config: config,
        onRequest: (request) {
          final idx = request.pageIndex;
          if (cache.get(idx) != null) return; // already cached
          if (rendering.contains(idx)) return; // already in flight
          rendering.add(idx);

          _renderPage(pdf!, idx, prewarmScale).then((page) {
            rendering.remove(idx);
            if (page != null) {
              cache.put(idx, page);
              if (!pageReadyController.isClosed) {
                pageReadyController.add(idx);
              }
            }
          }).catchError((_) {
            rendering.remove(idx);
          });
        },
      );

      // Prewarm is NOT fired here. It starts when the UI calls
      // recenter() on the first scroll event, so opening is instant
      // even for huge files.

      // Cleanup closure: tears down everything when the UI is done.
      var closed = false;
      void close() {
        if (closed) return;
        closed = true;
        scheduler.clear();
        pageReadyController.close();
        cache.dispose();
        pdf?.dispose();
        pdf = null;
      }

      return OpenResult(
        document: document,
        totalPages: pageCount,
        renderedPages: cache,
        documentHandle: documentRef,
        recenter: (pageIndex) {
          if (closed) return;
          scheduler.recenter(pageIndex.clamp(0, pageCount - 1));
        },
        pageReady: pageReadyController.stream,
        close: close,
      );
    } on DocumentOpenException {
      rethrow;
    } catch (error) {
      await pdf?.dispose();
      throw DocumentOpenException(source, cause: error);
    }
  }

  /// Renders a single page at the given scale. Returns null if the
  /// page could not be rendered (progressive loading not ready yet).
  static Future<PdfrxRenderedPage?> _renderPage(
    PdfDocument pdf,
    int pageIndex,
    double scale,
  ) async {
    final page = pdf.pages[pageIndex];
    final image = await page.render(
      fullWidth: page.width * scale,
      fullHeight: page.height * scale,
      backgroundColor: 0xffffffff,
    );
    if (image == null) return null;
    return PdfrxRenderedPage(pageIndex: pageIndex, image: image);
  }

  static String _titleOf(File file) => file.uri.pathSegments.last;
}
