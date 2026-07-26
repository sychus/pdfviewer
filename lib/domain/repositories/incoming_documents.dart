import '../entities/document_source.dart';

/// Port: documents handed to the app by the operating system.
///
/// This is the "Open with" path — the user tapped a PDF somewhere else and
/// chose this app, rather than picking a file from inside it.
///
/// There are deliberately **two** members, because the OS delivers documents in
/// two structurally different situations and handling only the first is the
/// classic way this feature ends up half-working:
///
/// - [initial] — the app was not running. It gets launched *because* of the
///   document, which is already waiting at startup.
/// - [stream] — the app was already running. The OS hands the document to the
///   live instance instead of starting a new one. Miss this and the app opens
///   the first document correctly and appears to ignore every one after it.
abstract interface class IncomingDocuments {
  /// The document this launch was started with, or `null` for a normal launch.
  ///
  /// Only meaningful once, at startup.
  Future<DocumentSource?> initial();

  /// Documents delivered while the app is already running.
  Stream<DocumentSource> stream();

  /// Tells the platform the pending document has been consumed, so it is not
  /// replayed on the next resume.
  void acknowledge();
}
