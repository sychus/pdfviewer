// lib/domain/entities/page_render_request.dart

import 'render_priority.dart';

/// A request to render (or re-render) a single page.
///
/// Identity is `pageIndex` — at most one in-flight request per page.
/// The scheduler assigns a monotonically-increasing `generation`
/// so old renders can be cancelled when the user moves on.
class PageRenderRequest {
  PageRenderRequest({
    required this.pageIndex,
    required this.priority,
    required this.scale,
    required this.generation,
  })  : assert(pageIndex >= 0),
        assert(scale > 0 && scale <= 1.0);

  final int pageIndex;
  final RenderPriority priority;

  /// 0.0–1.0. 0.5 means "half resolution, fast".
  final double scale;

  /// Bumped every time the page leaves and re-enters the visible window.
  /// Used to discard stale renders.
  final int generation;

  bool get isFullResolution => scale >= 0.999;

  @override
  bool operator ==(Object other) =>
      other is PageRenderRequest && other.pageIndex == pageIndex;

  @override
  int get hashCode => pageIndex.hashCode;
}
