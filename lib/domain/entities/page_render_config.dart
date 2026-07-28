// lib/domain/entities/page_render_config.dart

/// Tunables for the page prewarm + cache pipeline.
///
/// Pure Dart, no Flutter or pdfrx dependencies — this is a value object.
class PageRenderConfig {
  const PageRenderConfig({
    required this.cacheBudgetBytes,
    required this.prewarmScale,
    required this.prewarmRadius,
    required this.upgradeDelay,
  })  : assert(cacheBudgetBytes > 0),
        assert(prewarmScale > 0 && prewarmScale <= 1.0),
        assert(prewarmRadius >= 1);

  /// Maximum total bytes the bitmap LRU may hold before evicting.
  final int cacheBudgetBytes;

  /// Scale factor for prewarm renders (0.0–1.0). 0.5 means half size.
  final double prewarmScale;

  /// How many pages on each side of the visible page to prewarm.
  final int prewarmRadius;

  /// How long the user must be idle on a page before we upgrade
  /// its prewarm bitmap to full resolution. Zero or negative means
  /// "upgrade immediately".
  final Duration upgradeDelay;

  /// Sensible defaults for a desktop machine (16 GB RAM-ish).
  const PageRenderConfig.desktop()
      : cacheBudgetBytes = 150 * 1024 * 1024, // 150 MB
        prewarmScale = 0.5,
        prewarmRadius = 3,
        upgradeDelay = const Duration(milliseconds: 300);

  /// Conservative defaults for phones.
  const PageRenderConfig.mobile()
      : cacheBudgetBytes = 60 * 1024 * 1024, // 60 MB
        prewarmScale = 0.33,
        prewarmRadius = 2,
        upgradeDelay = const Duration(milliseconds: 500);

  PageRenderConfig copyWith({
    int? cacheBudgetBytes,
    double? prewarmScale,
    int? prewarmRadius,
    Duration? upgradeDelay,
  }) {
    return PageRenderConfig(
      cacheBudgetBytes: cacheBudgetBytes ?? this.cacheBudgetBytes,
      prewarmScale: prewarmScale ?? this.prewarmScale,
      prewarmRadius: prewarmRadius ?? this.prewarmRadius,
      upgradeDelay: upgradeDelay ?? this.upgradeDelay,
    );
  }
}
