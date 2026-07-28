// lib/domain/entities/rendered_page.dart

/// A page that has been rendered and is ready to be painted.
///
/// The domain does not know what kind of object backs this — pdfrx
/// `PdfPageImage`, a Flutter `ui.Image`, or a future swap-in all satisfy
/// the same interface. The concrete type lives behind the adapter.
abstract interface class RenderedPage {
  /// 0-based page index inside the document.
  int get pageIndex;

  /// Pixel width at the resolution this bitmap was rendered at.
  int get width;

  /// Pixel height at the resolution this bitmap was rendered at.
  int get height;

  /// Approximate memory cost in bytes. Used by the bitmap LRU to
  /// decide when to evict. Width × height × 4 is a safe lower bound
  /// for an RGBA8 bitmap.
  int get sizeBytes;

  /// Release any native resources held by this page.
  /// Called by the cache when the page is evicted.
  void dispose();
}
