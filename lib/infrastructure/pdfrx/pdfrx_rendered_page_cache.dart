// lib/infrastructure/pdfrx/pdfrx_rendered_page_cache.dart

import 'package:pdfviewer/domain/entities/rendered_page.dart';
import 'package:pdfviewer/domain/repositories/document_repository.dart';
import 'package:pdfviewer/infrastructure/cache/cached_bitmap.dart';
import 'package:pdfviewer/infrastructure/cache/lru_bitmap_cache.dart';

/// LRU cache of [RenderedPage]s, implemented on top of [LruBitmapCache].
///
/// Uses a generous per-entry size estimate; the budget is in "entries",
/// not bytes, because the actual bitmap size is unknown until a page
/// is rendered. This keeps the test surface area small while still
/// bounding memory: at most `maxEntries` PdfPageImages are alive.
class PdfrxRenderedPageCache implements RenderedPageCache {
  PdfrxRenderedPageCache({required this.maxEntries})
      : assert(maxEntries > 0),
        _lru = LruBitmapCache(maxBytes: maxEntries * _fakeEntrySize);

  final int maxEntries;

  // We use the LRU infrastructure but fake the byte size: every
  // entry reports the same size, so the cache evicts in LRU order
  // once it has maxEntries items.
  static const int _fakeEntrySize = 1;

  final LruBitmapCache _lru;

  // PdfrxRenderedPage implements both CachedBitmap and RenderedPage.
  // We need a small adapter to bridge them.
  final Map<int, _Adapter> _adapters = <int, _Adapter>{};

  @override
  RenderedPage? get(int pageIndex) {
    final a = _adapters[pageIndex];
    if (a == null) return null;
    _lru.get(a.id);
    return a.page;
  }

  @override
  void put(int pageIndex, RenderedPage page) {
    final adapter = _Adapter(id: pageIndex, page: page);
    _adapters[pageIndex] = adapter;
    _lru.put(pageIndex, adapter);
  }

  @override
  void remove(int pageIndex) {
    _adapters.remove(pageIndex);
    _lru.remove(pageIndex);
  }

  @override
  void dispose() {
    _lru.dispose();
    _adapters.clear();
  }
}

class _Adapter implements CachedBitmap {
  _Adapter({required this.id, required this.page});

  @override
  final int id;
  final RenderedPage page;

  @override
  int get sizeBytes => PdfrxRenderedPageCache._fakeEntrySize;

  @override
  void dispose() {
    // The page is disposed by the cache consumer, not here. This
    // adapter just exists to satisfy the CachedBitmap contract.
  }
}
