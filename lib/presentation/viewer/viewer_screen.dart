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
    required this.documentId,
  });

  final DocumentSource source;
  final int resumeAt;
  final SaveReadingPosition savePosition;
  final DocumentId documentId;

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
    if (mounted) setState(() => _pageCount = pageCount);
  }

  void _flush() {
    final page = _page.value;
    if (page == _persisted) return;
    _persisted = page;
    unawaited(widget.savePosition(widget.documentId, page));
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
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ValueListenableBuilder<int>(
                valueListenable: _page,
                builder: (context, page, _) => Text(
                  _pageCount != null ? '$page / $_pageCount' : '$page',
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
