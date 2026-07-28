// lib/application/prewarm/prewarm_scheduler.dart

import 'package:pdfviewer/domain/entities/page_render_config.dart';
import 'package:pdfviewer/domain/entities/page_render_request.dart';
import 'package:pdfviewer/domain/entities/render_priority.dart';

/// Decides which pages the renderer should be working on right now.
///
/// `recenter(currentPage)` cancels any pending work outside the new
/// window and emits fresh requests for the pages that should be hot.
///
/// This class is pure logic: no Flutter, no pdfrx, no I/O. The caller
/// is responsible for actually rendering pages and reporting back.
class PrewarmScheduler {
  PrewarmScheduler({
    required this.totalPages,
    required this.currentPage,
    required this.config,
    required this.onRequest,
    this.onCancel,
  })  : assert(totalPages > 0),
        assert(currentPage >= 0 && currentPage < totalPages) {
    _currentWindow = _windowFor(currentPage);
  }

  final int totalPages;
  int currentPage;
  final PageRenderConfig config;
  final void Function(PageRenderRequest request) onRequest;
  final void Function(PageRenderRequest request)? onCancel;

  final Map<int, PageRenderRequest> _inFlight = <int, PageRenderRequest>{};
  late Set<int> _currentWindow;
  int _generation = 0;

  void recenter(int newPage) {
    assert(newPage >= 0 && newPage < totalPages,
        'newPage out of range: $newPage for $totalPages pages');

    currentPage = newPage;
    _generation += 1;

    final newWindow = _windowFor(newPage);

    for (final entry in _inFlight.entries.toList()) {
      if (!newWindow.contains(entry.key)) {
        onCancel?.call(entry.value);
        _inFlight.remove(entry.key);
      }
    }

    for (final page in newWindow) {
      final priority = page == newPage
          ? RenderPriority.visible
          : RenderPriority.neighbour;
      final request = PageRenderRequest(
        pageIndex: page,
        priority: priority,
        scale: config.prewarmScale,
        generation: _generation,
      );
      _inFlight[page] = request;
      onRequest(request);
    }

    _currentWindow = newWindow;
  }

  void upgradeToFull(int pageIndex) {
    if (!_currentWindow.contains(pageIndex)) return;

    final request = PageRenderRequest(
      pageIndex: pageIndex,
      priority: RenderPriority.visible,
      scale: 1.0,
      generation: _generation,
    );
    _inFlight[pageIndex] = request;
    onRequest(request);
  }

  void clear() {
    for (final request in _inFlight.values) {
      onCancel?.call(request);
    }
    _inFlight.clear();
    _currentWindow = <int>{};
  }

  Set<int> _windowFor(int centre) {
    final radius = config.prewarmRadius;
    final first = (centre - radius).clamp(0, totalPages - 1);
    final last = (centre + radius).clamp(0, totalPages - 1);
    return {for (var i = first; i <= last; i++) i};
  }

  Set<int> get currentWindow => Set<int>.unmodifiable(_currentWindow);

  Map<int, PageRenderRequest> get inFlight =>
      Map<int, PageRenderRequest>.unmodifiable(_inFlight);
}
