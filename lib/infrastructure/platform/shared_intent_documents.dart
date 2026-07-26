import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../../domain/entities/document_source.dart';
import '../../domain/repositories/incoming_documents.dart';

/// [IncomingDocuments] for Android and iOS, backed by platform intents.
///
/// The plugin resolves the incoming `content://` URI by copying its contents
/// into the app's cache directory and handing back a real file path — the same
/// thing the file picker does. Two consequences, both already accounted for:
///
/// - The path is **different on every open** of the same document. Reading
///   positions survive only because documents are keyed by a fingerprint of
///   their content rather than by where they happen to live.
/// - Large documents are physically copied before they can be opened. That
///   cost is invisible on desktop and real here.
final class SharedIntentDocuments implements IncomingDocuments {
  const SharedIntentDocuments();

  @override
  Future<DocumentSource?> initial() async =>
      _firstPdf(await ReceiveSharingIntent.instance.getInitialMedia());

  @override
  Stream<DocumentSource> stream() => ReceiveSharingIntent.instance
      .getMediaStream()
      .map(_firstPdf)
      .where((source) => source != null)
      .cast<DocumentSource>();

  @override
  void acknowledge() => ReceiveSharingIntent.instance.reset();

  /// The manifest already restricts us to `application/pdf`, so this is belt
  /// and braces — but share sheets are a wide door, and opening whatever
  /// arrives as if it were a PDF is how you get an unhelpful parse error
  /// instead of a clear one.
  static DocumentSource? _firstPdf(List<SharedMediaFile> media) {
    for (final file in media) {
      final isPdf = file.mimeType == 'application/pdf' ||
          file.path.toLowerCase().endsWith('.pdf');
      if (isPdf) return DocumentSource(file.path);
    }
    return null;
  }
}
