import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'application/open_document/open_streaming_document.dart';
import 'application/save_reading_position.dart';
import 'domain/repositories/incoming_documents.dart';
import 'infrastructure/pdf_engine.dart';
import 'infrastructure/pdfrx_document_repository.dart';
import 'infrastructure/platform/no_incoming_documents.dart';
import 'infrastructure/platform/shared_intent_documents.dart';
import 'infrastructure/prefs_position_store.dart';
import 'presentation/home/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _silenceDebugLoggingInRelease();
  initializePdfEngine();

  // Wired by hand. This is the composition root, and it is a handful of lines
  // — a DI container here would be ceremony, not architecture. It is also the
  // only place in the app where a concrete implementation is named.
  const repository = PdfrxDocumentRepository();
  final positions = PrefsPositionStore();

  runApp(
    PdfViewerApp(
      openStreamingDocument: const OpenStreamingDocument(repository),
      positions: positions,
      savePosition: SaveReadingPosition(positions),
      incoming: _incomingDocuments(),
    ),
  );
}

/// Picks the "Open with" implementation for the current platform.
///
/// `defaultTargetPlatform` rather than `dart:io`'s `Platform`, because the
/// latter does not exist on web and this file is compiled for every target.
IncomingDocuments _incomingDocuments() {
  if (kIsWeb) return const NoIncomingDocuments();

  return switch (defaultTargetPlatform) {
    TargetPlatform.android || TargetPlatform.iOS =>
      const SharedIntentDocuments(),
    _ => const NoIncomingDocuments(),
  };
}

/// Turns off `debugPrint` in release builds.
///
/// This is a privacy fix, not tidiness. `debugPrint` is not compiled out of
/// release builds — it writes to stdout, which lands in Console.app on macOS
/// and logcat on Android. pdfrx calls it unguarded on every document load,
/// including the **full path of the file**:
///
///     PdfDocument initial load: PdfDocumentRefKey(/Users/x/Documents/NDA.pdf)
///
/// For a PDF reader that is not acceptable. People open contracts, medical
/// records and bank statements, and the filename alone gives those away to
/// anything that can read the system log.
///
/// This silences every library's debug output too, which is the right default
/// for release. When crash reporting arrives, genuine errors go there instead
/// of to stdout.
void _silenceDebugLoggingInRelease() {
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }
}

class PdfViewerApp extends StatelessWidget {
  const PdfViewerApp({
    super.key,
    required this.openStreamingDocument,
    required this.positions,
    required this.savePosition,
    required this.incoming,
  });

  final OpenStreamingDocument openStreamingDocument;
  final PrefsPositionStore positions;
  final SaveReadingPosition savePosition;
  final IncomingDocuments incoming;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDF Viewer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.blueGrey),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.blueGrey,
        brightness: Brightness.dark,
      ),
      home: HomeScreen(
        openStreamingDocument: openStreamingDocument,
        positions: positions,
        savePosition: savePosition,
        incoming: incoming,
      ),
    );
  }
}
