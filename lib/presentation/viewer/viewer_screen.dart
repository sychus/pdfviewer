import 'dart:async';

import 'package:flutter/material.dart';

import '../../application/save_reading_position.dart';
import '../../domain/entities/document.dart';
import '../../domain/entities/document_source.dart';
import '../widgets/pdf_surface.dart';

/// Shows one document, and remembers where the reader got to.
class ViewerScreen extends StatefulWidget {
  const ViewerScreen({
    super.key,
    this.document,
    required this.source,
    required this.resumeAt,
    required this.savePosition,
    this.showPageCount = true,
  });

  /// May be null while identity is still resolving in the background.
  /// Rendering starts immediately regardless — identity is only needed
  /// for position save and the page counter.
  final Document? document;

  /// Always available — the file path the viewer opens from.
  final DocumentSource source;

  /// 1-based page to open at.
  final int resumeAt;

  final SaveReadingPosition savePosition;

  /// Whether to show the page counter in the app bar.
  final bool showPageCount;

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  static const _writeDelay = Duration(seconds: 1);

  late final _page = ValueNotifier<int>(widget.resumeAt);
  late int _persisted = widget.resumeAt;
  Timer? _pendingWrite;

  void _onPageChanged(int page) {
    _page.value = page;
    _pendingWrite?.cancel();
    _pendingWrite = Timer(_writeDelay, _flush);
  }

  void _flush() {
    final doc = widget.document;
    if (doc == null) return; // identity not resolved yet, skip save
    final page = _page.value;
    if (page == _persisted) return;
    _persisted = page;
    unawaited(widget.savePosition(doc.id, page));
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
    final doc = widget.document;
    final title = doc?.title ?? widget.source.uri.split('/').last;

    return Scaffold(
      appBar: AppBar(
        title: Text(title, overflow: TextOverflow.ellipsis),
        actions: [
          if (widget.showPageCount && doc != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ValueListenableBuilder<int>(
                  valueListenable: _page,
                  builder: (context, page, _) => Text(
                    '$page / ${doc.pageCount}',
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
      ),
    );
  }
}
