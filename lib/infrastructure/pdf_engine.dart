import 'package:pdfrx/pdfrx.dart';

/// Boots the native PDF engine.
///
/// Must run once at startup, before any document is opened through the engine
/// API — which is exactly what [PdfrxDocumentRepository] does when it reads a
/// document's page count. Skip this and opening a document fails at runtime.
///
/// It lives here, behind a neutral name, so that `main.dart` can start the
/// engine without importing pdfrx itself.
void initializePdfEngine() => pdfrxFlutterInitialize();
