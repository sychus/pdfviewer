import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../application/open_document/open_streaming_document.dart';
import '../../application/save_reading_position.dart';
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
///
/// Two ways in, one destination: the user picks a file here, or the operating
/// system hands us one because they tapped a PDF elsewhere and chose this app.
/// Both funnel through [_HomeScreenState._open].
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.openStreamingDocument,
    required this.positions,
    required this.savePosition,
    required this.incoming,
  });

  final OpenStreamingDocument openStreamingDocument;
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

    // Documents handed to an app that is already running.
    _incoming = widget.incoming.stream().listen(_open);

    // And the one this launch may have been started with. Deferred to after
    // the first frame so there is a Navigator to push onto.
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
      // Open the document via the streaming path: this returns the first
      // page already rendered and starts background prewarming.
      final result = await widget.openStreamingDocument(source: source);
      if (!mounted) {
        result.close();
        return;
      }

      // Look up the stored reading position, same logic as OpenDocument.
      ReadingPosition? saved;
      try {
        saved = await widget.positions.load(result.document.id);
      } catch (_) {
        saved = null;
      }
      final resumeAt = saved == null
          ? 1
          : saved.page.clamp(1, result.document.pageCount);

      // If we're resuming somewhere other than page 1, tell the scheduler
      // to recenter its prewarm window there.
      if (resumeAt > 1) {
        result.recenter(resumeAt - 1); // 0-based
      }

      if (!mounted) {
        result.close();
        return;
      }

      // Consume the pending document so it is not replayed the next time the
      // app resumes — otherwise closing the viewer bounces straight back into
      // it and the app feels stuck.
      widget.incoming.acknowledge();

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ViewerScreen(
            document: result.document,
            resumeAt: resumeAt,
            savePosition: widget.savePosition,
            onRecenter: result.recenter,
            onClose: result.close,
            documentHandle: result.documentHandle,
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
