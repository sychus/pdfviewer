import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../application/save_reading_position.dart';
import '../../domain/entities/document_source.dart';
import '../../domain/entities/reading_position.dart';
import '../../domain/repositories/incoming_documents.dart';
import '../../domain/repositories/position_store.dart';
import '../../infrastructure/identity/file_document_bytes.dart';
import '../../infrastructure/identity/fingerprint_document_identity.dart';
import '../viewer/viewer_screen.dart';

const _pdfs = XTypeGroup(
  label: 'PDF',
  extensions: <String>['pdf'],
  mimeTypes: <String>['application/pdf'],
  uniformTypeIdentifiers: <String>['com.adobe.pdf'],
);

/// Empty state, and the app's entry point for documents.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.positions,
    required this.savePosition,
    required this.incoming,
    this.identity = const FingerprintDocumentIdentity(),
  });

  final PositionStore positions;
  final SaveReadingPosition savePosition;
  final IncomingDocuments incoming;
  final FingerprintDocumentIdentity identity;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  StreamSubscription<DocumentSource>? _incoming;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _incoming = widget.incoming.stream().listen(_open);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final launchedWith = await widget.incoming.initial();
      if (launchedWith != null) await _open(launchedWith);
    });
  }

  @override
  void dispose() {
    _incoming?.cancel();
    super.dispose();
  }

  Future<void> _pick() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final picked = await openFile(acceptedTypeGroups: const [_pdfs]);
      if (picked == null || !mounted) return;
      await _open(DocumentSource(picked.path), alreadyBusy: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(DocumentSource source, {bool alreadyBusy = false}) async {
    if (_busy && !alreadyBusy) return;
    if (!alreadyBusy && mounted) setState(() => _busy = true);

    try {
      // ── Fingerprint: 128KB of raw file bytes, no pdfrx, near-instant ──
      final file = File(source.uri);
      final docId = await widget.identity.compute(FileDocumentBytes(file));

      // ── Position: look up where the user left off ──
      ReadingPosition? saved;
      try {
        saved = await widget.positions.load(docId);
      } catch (_) {
        saved = null;
      }
      // We don't know pageCount yet (PdfViewer will tell us), so we
      // can't clamp. A page that's past the end is harmless — PdfViewer
      // just opens at the last page.
      final resumeAt = saved?.page ?? 1;

      if (!mounted) return;

      widget.incoming.acknowledge();

      // ── Navigate. PdfViewer.file() is the ONLY thing opening the PDF ──
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ViewerScreen(
            source: source,
            resumeAt: resumeAt,
            savePosition: widget.savePosition,
            documentId: docId,
          ),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Failed to open document: $error\n$stackTrace');
      _report('Something went wrong opening that file.');
    } finally {
      if (!alreadyBusy && mounted) setState(() => _busy = false);
    }
  }

  void _report(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.picture_as_pdf_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _busy ? null : _pick,
              icon: const Icon(Icons.folder_open),
              label: Text(_busy ? 'Opening…' : 'Open a PDF'),
            ),
          ],
        ),
      ),
    );
  }
}
