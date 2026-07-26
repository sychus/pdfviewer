/// Where a document came from.
///
/// Deliberately an OPAQUE string. Depending on the platform it may be a file
/// path, an Android `content://` URI, or a security-scoped iOS URL. The domain
/// does not care which: it only carries the value through to infrastructure,
/// the one layer that knows how to interpret it.
///
/// This is METADATA, not identity. Never compare documents by their source —
/// that is what [DocumentId] is for.
final class DocumentSource {
  const DocumentSource(this.uri);

  final String uri;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is DocumentSource && other.uri == uri);

  @override
  int get hashCode => uri.hashCode;

  @override
  String toString() => uri;
}
