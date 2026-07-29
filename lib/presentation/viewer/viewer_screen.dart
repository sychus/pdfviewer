import 'dart:async';

import 'package:flutter/material.dart';

import '../../application/save_reading_position.dart';
import '../../domain/entities/document_id.dart';
import '../../domain/entities/document_source.dart';
import '../widgets/pdf_surface.dart';

/// Shows one document, and remembers where the reader got to.
class ViewerScreen extends StatefulWidget {
  const ViewerScreen({
    super.key,
    required this.source,
    required this.resumeAt,
    required this.savePosition,
    this.documentId,
  });

  /// The file path. Always available immediately.
  final DocumentSource source;

  /// 1-based page to open at.
  final int resumeAt;

  final SaveReadingPosition savePosition;

  /// Content fingerprint, resolved async. Null until ready.
  /// Position save is deferred until this arrives.
  final DocumentId? documentId;

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  static const _writeDelay = Duration(seconds: 1);

  late final _page = ValueNotifier<int>(widget.resumeAt);
  late int _persisted = widget.resumeAt;
  int? _pageCount;
  Timer? _pendingWrite;

  void _onPageChanged(int page) {
    _page.value = page;
    _pendingWrite?.cancel();
    _pendingWrite = Timer(_writeDelay, _flush);
  }

  void _onDocumentLoaded(int pageCount) {
    setState(() => _pageCount = pageCount);
  }

  void _flush() {
    final id = widget.documentId;
    if (id == null) return; // identity not resolved yet
    final page = _page.value;
    if (page == _persisted) return;
    _persisted = page;
    unawaited(widget.savePosition(id, page));
  }

  @override
  void dispose() {
    _pendingWrite?.cancel();
    _flush();
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.source.uri.split('/').last;

    return Scaffold(
      appBar: AppBar(
        title: Text(title, overflow: TextOverflow.ellipsis),
        actions: [
          if (_pageCount != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ValueListenableBuilder<int>(
                  valueListenable: _page,
                  builder: (context, page, _) => Text(
                    '$page / $_pageCount',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: PdfSurface(
        path: widget.source.uri,
        initialPage: widget.resumeAt,
        onPageChanged: _onPageChanged,
        onDocumentLoaded: _onDocumentLoaded,
      ),
    );
  }
}
