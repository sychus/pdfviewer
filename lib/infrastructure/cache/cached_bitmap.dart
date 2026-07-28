// lib/infrastructure/cache/cached_bitmap.dart

/// Anything that occupies memory in the bitmap cache.
///
/// Production bitmaps are pdfrx `PdfPageImage` objects. The cache only
/// needs to know how many bytes each entry costs and how to dispose it.
abstract class CachedBitmap {
  /// Stable identity. Used as the cache key.
  int get id;

  /// Memory cost in bytes. Used for budget accounting.
  int get sizeBytes;

  /// Release native resources. Called by the cache when an entry is
  /// evicted, and on `LruBitmapCache.dispose()`.
  void dispose();
}
