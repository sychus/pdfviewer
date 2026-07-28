// lib/infrastructure/cache/lru_bitmap_cache.dart

import 'dart:collection';

import 'cached_bitmap.dart';

/// A least-recently-used cache for page bitmaps, bounded by a byte budget.
///
/// Eviction rules:
///  * When a `put` would push the cache past `maxBytes`, the entry that
///    was least-recently-used is removed (and disposed) and the process
///    repeats until there is enough room.
///  * `get` and `put` both refresh an entry's recency.
///  * `dispose` disposes every entry it holds.
///
/// The cache is intentionally generic: it never imports pdfrx, Flutter
/// or dart:io, so it can be unit-tested in pure Dart.
class LruBitmapCache {
  LruBitmapCache({required this.maxBytes})
      : assert(maxBytes > 0, 'maxBytes must be positive');

  /// Maximum total bytes the cache may hold. Eviction starts as soon as
  /// a `put` would push the cache past this number.
  final int maxBytes;

  // Doubly-linked-list emulation via LinkedHashMap. Insertion order is
  // recency order: most-recently-used at the end, least at the start.
  final LinkedHashMap<int, CachedBitmap> _entries =
      LinkedHashMap<int, CachedBitmap>();

  int _currentBytes = 0;

  /// Bytes currently held. Exposed for tests and metrics.
  int get currentBytes => _currentBytes;

  /// Number of entries. Exposed for tests and metrics.
  int get length => _entries.length;

  /// Look up a bitmap. Returns `null` if absent. Refreshes recency.
  CachedBitmap? get(int id) {
    final bmp = _entries.remove(id);
    if (bmp == null) return null;
    _entries[id] = bmp; // re-insert at the MRU end
    return bmp;
  }

  /// Insert or replace a bitmap. May trigger one or more evictions.
  void put(int id, CachedBitmap bmp) {
    assert(bmp.sizeBytes >= 0, 'sizeBytes must be non-negative');

    // If we're replacing an existing entry, free the old one first so
    // the budget math is correct.
    final existing = _entries.remove(id);
    if (existing != null) {
      _currentBytes -= existing.sizeBytes;
      existing.dispose();
    }

    _currentBytes += bmp.sizeBytes;
    _entries[id] = bmp;

    // If the new entry alone is bigger than the budget, the only sane
    // thing is to evict everything else and let it stand alone. It will
    // be evicted on the next put that overflows.
    if (bmp.sizeBytes > maxBytes) {
      _evictAllExcept(id);
      return;
    }

    while (_currentBytes > maxBytes && _entries.length > 1) {
      _evictLeastRecentlyUsed();
    }
  }

  /// Remove a single entry. Disposes it. No-op if absent.
  void remove(int id) {
    final bmp = _entries.remove(id);
    if (bmp == null) return;
    _currentBytes -= bmp.sizeBytes;
    bmp.dispose();
  }

  /// Drop and dispose every entry.
  void dispose() {
    for (final bmp in _entries.values) {
      bmp.dispose();
    }
    _entries.clear();
    _currentBytes = 0;
  }

  void _evictLeastRecentlyUsed() {
    if (_entries.isEmpty) return;
    final lruId = _entries.keys.first;
    _evict(lruId);
  }

  void _evictAllExcept(int keepId) {
    final ids = _entries.keys.where((id) => id != keepId).toList();
    for (final id in ids) {
      _evict(id);
    }
  }

  void _evict(int id) {
    final bmp = _entries.remove(id);
    if (bmp == null) return;
    _currentBytes -= bmp.sizeBytes;
    bmp.dispose();
  }
}
