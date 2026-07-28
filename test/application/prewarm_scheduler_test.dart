// test/application/prewarm_scheduler_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:pdfviewer/application/prewarm/prewarm_scheduler.dart';
import 'package:pdfviewer/application/prewarm/page_render_request.dart';
import 'package:pdfviewer/domain/entities/page_render_config.dart';

void main() {
  group('PrewarmScheduler', () {
    test('emits requests for the current page plus a symmetric window', () {
      final emitted = <PageRenderRequest>[];
      final scheduler = PrewarmScheduler(
        totalPages: 100,
        currentPage: 10,
        config: const PageRenderConfig.desktop(),
        onRequest: emitted.add,
      );

      scheduler.recenter(10);

      final pages = emitted.map((r) => r.pageIndex).toSet();
      // 10 ± 3 = {7, 8, 9, 10, 11, 12, 13}
      expect(pages, {7, 8, 9, 10, 11, 12, 13});
    });

    test('caps the window at the document boundaries', () {
      final emitted = <PageRenderRequest>[];
      final scheduler = PrewarmScheduler(
        totalPages: 5,
        currentPage: 0,
        config: const PageRenderConfig.desktop(),
        onRequest: emitted.add,
      );

      scheduler.recenter(0);
      final pages = emitted.map((r) => r.pageIndex).toSet();
      expect(pages, {0, 1, 2, 3}); // -3 would be negative, dropped
    });

    test('recenter cancels previously-pending requests outside the new window',
        () {
      final requests = <PageRenderRequest>[];
      final cancels = <PageRenderRequest>[];
      final scheduler = PrewarmScheduler(
        totalPages: 100,
        currentPage: 10,
        config: const PageRenderConfig.desktop(),
        onRequest: requests.add,
        onCancel: cancels.add,
      );

      scheduler.recenter(10);
      scheduler.recenter(50);

      expect(cancels, isNotEmpty);
      // The pages from the old window (around 10) should be cancelled.
      final cancelledPages = cancels.map((c) => c.pageIndex).toSet();
      expect(cancelledPages.contains(10), isTrue);
    });

    test('recenter bumps the generation on the emitted requests', () {
      final emitted = <PageRenderRequest>[];
      final scheduler = PrewarmScheduler(
        totalPages: 100,
        currentPage: 10,
        config: const PageRenderConfig.desktop(),
        onRequest: emitted.add,
      );

      scheduler.recenter(10);
      final firstGen = emitted.first.generation;

      scheduler.recenter(50);
      final newGen = emitted.last.generation;

      expect(newGen, greaterThan(firstGen));
    });
  });
}
