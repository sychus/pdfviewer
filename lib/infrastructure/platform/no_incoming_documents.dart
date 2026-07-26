import '../../domain/entities/document_source.dart';
import '../../domain/repositories/incoming_documents.dart';

/// [IncomingDocuments] for platforms where "Open with" is not wired up yet.
///
/// Desktop needs entirely different plumbing — `CFBundleDocumentTypes` plus an
/// AppKit delegate on macOS, a `.desktop` entry on Linux, registry keys written
/// by an installer on Windows — and on Windows and Linux a second document
/// arrives as a **new process**, so routing it to the running instance is an
/// IPC problem rather than a file-handling one.
///
/// Returning nothing is the honest implementation until that exists. The app
/// keeps working; it just never receives a document it did not open itself.
final class NoIncomingDocuments implements IncomingDocuments {
  const NoIncomingDocuments();

  @override
  Future<DocumentSource?> initial() async => null;

  @override
  Stream<DocumentSource> stream() => const Stream.empty();

  @override
  void acknowledge() {}
}
