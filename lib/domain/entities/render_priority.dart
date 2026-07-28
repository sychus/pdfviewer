// lib/domain/entities/render_priority.dart

/// Priority of a page render request. Higher values are served first.
enum RenderPriority {
  /// The page the user is actively looking at. Must be served fast.
  visible(100),

  /// Neighbours of the visible page. Pre-warmed in the background.
  neighbour(50),

  /// Anything else. Rendered only if the system is otherwise idle.
  background(10);

  const RenderPriority(this.weight);

  final int weight;
}
