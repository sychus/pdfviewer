import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../application/open_document.dart';
import '../../application/save_reading_position.dart';
import '../../domain/entities/document_source.dart';
import '../../domain/repositories/document_repository.dart';
import '../viewer/viewer_screen.dart';

const _pdfs = XTypeGroup(
  label: 'PDF',
  extensions: <String>['pdf'],
  mimeTypes: <String>['application/pdf'],
  uniformTypeIdentifiers: <String>['com.adobe.pdf'],
);

/// Empty state: no document open yet.
///
/// Temporary by design. Once file association lands in Phase 5, most launches
/// will skip this screen entirely — the OS hands us a document and we go
/// straight to the viewer.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.openDocument,
    required this.savePosition,
  });

  final OpenDocument openDocument;
  final SaveReadingPosition savePosition;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _opening = false;

  Future<void> _pickAndOpen() async {
    if (_opening) return;
    setState(() => _opening = true);

    try {
      final picked = await openFile(acceptedTypeGroups: const [_pdfs]);
      if (picked == null || !mounted) return;

      final opened = await widget.openDocument(DocumentSource(picked.path));
      if (!mounted) return;

      // Not awaited on purpose: awaiting navigation would keep [_opening] true
      // for as long as the user reads the document.
      unawaited(
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ViewerScreen(
              document: opened.document,
              resumeAt: opened.resumeAt,
              savePosition: widget.savePosition,
            ),
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
      if (mounted) setState(() => _opening = false);
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
              onPressed: _opening ? null : _pickAndOpen,
              icon: const Icon(Icons.folder_open),
              label: Text(_opening ? 'Opening…' : 'Open a PDF'),
            ),
          ],
        ),
      ),
    );
  }
}
