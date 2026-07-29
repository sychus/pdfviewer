import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../application/save_reading_position.dart';
import '../../domain/entities/document.dart';
import '../../domain/entities/document_source.dart';
import '../../domain/entities/reading_position.dart';
import '../../domain/repositories/document_repository.dart';
import '../../domain/repositories/incoming_documents.dart';
import '../../domain/repositories/position_store.dart';
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
    required this.documents,
    required this.positions,
    required this.savePosition,
    required this.incoming,
  });

  final DocumentRepository documents;
  final PositionStore positions;
  final SaveReadingPosition savePosition;
  final IncomingDocuments incoming;

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
      // Navigate FIRST, resolve identity AFTER. PdfViewer.file() handles
      // its own progressive loading so the user sees pages immediately.
      // The document identity (fingerprint) runs in the background — it
      // only matters for position restore, not for rendering.
      //
      // We kick off the identity computation in parallel with navigation
      // so it's usually ready before the user even scrolls.
      final docFuture = widget.documents.open(source);

      widget.incoming.acknowledge();

      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _DeferredViewerScreen(
            source: source,
            docFuture: docFuture,
            positions: widget.positions,
            savePosition: widget.savePosition,
          ),
        ),
      );
    } on DocumentOpenException {
      _report("That file couldn't be opened as a PDF.");
    } catch (error, stackTrace) {
      debugPrint('Unexpected failure opening a document: $error\n$stackTrace');
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

/// Navigates immediately showing the PDF via [PdfSurface], while the
/// document identity resolves in the background. Once it lands, position
/// restore and page counting become available.
class _DeferredViewerScreen extends StatefulWidget {
  const _DeferredViewerScreen({
    required this.source,
    required this.docFuture,
    required this.positions,
    required this.savePosition,
  });

  final DocumentSource source;
  final Future<Document> docFuture;
  final PositionStore positions;
  final SaveReadingPosition savePosition;

  @override
  State<_DeferredViewerScreen> createState() => _DeferredViewerScreenState();
}

class _DeferredViewerScreenState extends State<_DeferredViewerScreen> {
  Document? _doc;
  int? _resumeAt;
  bool _resolved = false;

  @override
  void initState() {
    super.initState();
    _resolveDocument();
  }

  Future<void> _resolveDocument() async {
    try {
      final doc = await widget.docFuture;
      if (!mounted) return;

      ReadingPosition? saved;
      try {
        saved = await widget.positions.load(doc.id);
      } catch (_) {
        saved = null;
      }

      if (!mounted) return;
      setState(() {
        _doc = doc;
        _resumeAt = saved?.page.clamp(1, doc.pageCount);
        _resolved = true;
      });
    } catch (_) {
      // Identity resolution failed — the PDF still renders fine, we just
      // can't restore position or show the page count. Not fatal.
      if (mounted) setState(() => _resolved = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ViewerScreen(
      document: _doc,
      source: widget.source,
      resumeAt: _resumeAt ?? 1,
      savePosition: widget.savePosition,
      showPageCount: _resolved && _doc != null,
    );
  }
}
