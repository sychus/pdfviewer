// test/infrastructure/bitmap_cache_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:pdfviewer/infrastructure/cache/cached_bitmap.dart';
import 'package:pdfviewer/infrastructure/cache/lru_bitmap_cache.dart';
import 'package:pdfviewer/domain/entities/page_render_config.dart';

/// Minimal stand-in for a real bitmap so tests don't pull in PDFium.
/// The cache only cares about identity + byte size for budgeting.
class _FakeBitmap implements CachedBitmap {
  _FakeBitmap(this.id, this.sizeBytes);

  @override
  final int id;
  @override
  final int sizeBytes;

  bool disposed = false;

  @override
  void dispose() {
    disposed = true;
  }
}

void main() {
  group('LruBitmapCache', () {
    test('returns null for a key that was never inserted', () {
      final cache = LruBitmapCache(maxBytes: 1024);
      expect(cache.get(42), isNull);
    });

    test('returns the bitmap that was just inserted', () {
      final cache = LruBitmapCache(maxBytes: 1024);
      final bmp = _FakeBitmap(1, 256);
      cache.put(1, bmp);
      expect(cache.get(1), same(bmp));
    });

    test('evicts the least-recently-used entry when over budget', () {
      final cache = LruBitmapCache(maxBytes: 1000);

      final a = _FakeBitmap(1, 400);
      final b = _FakeBitmap(2, 400);
      final c = _FakeBitmap(3, 400);

      cache.put(1, a);
      cache.put(2, b);
      // Touch 'a' so 'b' becomes least-recently-used.
      cache.get(1);
      cache.put(3, c);

      expect(cache.get(1), same(a), reason: 'a was touched, should remain');
      expect(cache.get(2), isNull, reason: 'b was evicted to make room');
      expect(cache.get(3), same(c));
      expect(b.disposed, isTrue, reason: 'evicted bitmaps must be disposed');
    });

    test('disposes bitmaps on dispose()', () {
      final cache = LruBitmapCache(maxBytes: 1024);
      final a = _FakeBitmap(1, 100);
      final b = _FakeBitmap(2, 100);
      cache.put(1, a);
      cache.put(2, b);

      cache.dispose();

      expect(a.disposed, isTrue);
      expect(b.disposed, isTrue);
    });

    test('does not exceed the configured byte budget after many inserts', () {
      final cache = LruBitmapCache(maxBytes: 2000);
      for (var i = 0; i < 50; i++) {
        cache.put(i, _FakeBitmap(i, 500));
      }
      // 2000 / 500 = at most 4 entries should remain.
      var alive = 0;
      for (var i = 0; i < 50; i++) {
        if (cache.get(i) != null) alive++;
      }
      expect(alive, lessThanOrEqualTo(4));
    });

    test('updating an existing key refreshes its recency', () {
      final cache = LruBitmapCache(maxBytes: 1000);
      cache.put(1, _FakeBitmap(1, 400));
      cache.put(2, _FakeBitmap(2, 400));
      // Re-put 1, which should make it most-recently-used.
      cache.put(1, _FakeBitmap(1, 400));
      cache.put(3, _FakeBitmap(3, 400));

      expect(cache.get(1), isNotNull);
      expect(cache.get(2), isNull);
      expect(cache.get(3), isNotNull);
    });
  });

  group('PageRenderConfig', () {
    test('defaults are sane for a desktop target', () {
      const cfg = PageRenderConfig.desktop();
      expect(cfg.cacheBudgetBytes, greaterThan(0));
      expect(cfg.prewarmScale, greaterThan(0));
      expect(cfg.prewarmScale, lessThanOrEqualTo(1.0));
      expect(cfg.prewarmRadius, greaterThanOrEqualTo(1));
    });

    test('mobile preset uses a smaller budget than desktop', () {
      const desktop = PageRenderConfig.desktop();
      const mobile = PageRenderConfig.mobile();
      expect(mobile.cacheBudgetBytes, lessThan(desktop.cacheBudgetBytes));
    });
  });
}
