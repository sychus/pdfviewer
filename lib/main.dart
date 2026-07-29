import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'application/save_reading_position.dart';
import 'domain/repositories/incoming_documents.dart';
import 'infrastructure/pdf_engine.dart';
import 'infrastructure/platform/no_incoming_documents.dart';
import 'infrastructure/platform/shared_intent_documents.dart';
import 'infrastructure/prefs_position_store.dart';
import 'presentation/home/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _silenceDebugLoggingInRelease();
  initializePdfEngine();

  final positions = PrefsPositionStore();

  runApp(
    PdfViewerApp(
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
    required this.positions,
    required this.savePosition,
    required this.incoming,
  });

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
        positions: positions,
        savePosition: savePosition,
        incoming: incoming,
      ),
    );
  }
}
