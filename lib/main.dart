import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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

  const repository = PdfrxDocumentRepository();
  final positions = PrefsPositionStore();

  runApp(
    PdfViewerApp(
      documents: repository,
      positions: positions,
      savePosition: SaveReadingPosition(positions),
      incoming: _incomingDocuments(),
    ),
  );
}

IncomingDocuments _incomingDocuments() {
  if (kIsWeb) return const NoIncomingDocuments();

  return switch (defaultTargetPlatform) {
    TargetPlatform.android || TargetPlatform.iOS =>
      const SharedIntentDocuments(),
    _ => const NoIncomingDocuments(),
  };
}

void _silenceDebugLoggingInRelease() {
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }
}

class PdfViewerApp extends StatelessWidget {
  const PdfViewerApp({
    super.key,
    required this.documents,
    required this.positions,
    required this.savePosition,
    required this.incoming,
  });

  final PdfrxDocumentRepository documents;
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
        documents: documents,
        positions: positions,
        savePosition: savePosition,
        incoming: incoming,
      ),
    );
  }
}
