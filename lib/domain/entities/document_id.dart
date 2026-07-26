/// Stable identity of a document.
///
/// Derived from the document's CONTENT, never from its location. Moving,
/// renaming or copying the file does not change its identity; modifying it does.
///
/// That distinction is deliberate. A path identifies a location, not a document,
/// and location is unstable on every platform we ship to:
///
/// - Android hands out opaque `content://` URIs that may be ephemeral.
/// - On iOS the path embeds the sandbox container UUID, which changes on app update.
/// - On desktop the user moves and renames files freely.
///
/// The domain does not know HOW this identity is computed. That lives in
/// infrastructure.
final class DocumentId {
  const DocumentId(this.value);

  final String value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is DocumentId && other.value == value);

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
