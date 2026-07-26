import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../application/open_document.dart';
import '../../application/save_reading_position.dart';
import '../../domain/entities/document_source.dart';
import '../../domain/repositories/document_repository.dart';
import '../../domain/repositories/incoming_documents.dart';
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
    required this.openDocument,
    required this.savePosition,
    required this.incoming,
  });

  final OpenDocument openDocument;
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
      final opened = await widget.openDocument(source);
      if (!mounted) return;

      // Consume the pending document so it is not replayed the next time the
      // app resumes — otherwise closing the viewer bounces straight back into
      // it and the app feels stuck.
      widget.incoming.acknowledge();

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ViewerScreen(
            document: opened.document,
            resumeAt: opened.resumeAt,
            savePosition: widget.savePosition,
          ),
        ),
      );
    } on DocumentOpenException {
      _report("That file couldn't be opened as a PDF.");
    } catch (error, stackTrace) {
      // Everything else has to surface too. A plugin failure or a sandbox
      // denial that only gets rethrown into the void is exactly how a button
      // ends up doing nothing at all, with no way for the user to tell why.
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
