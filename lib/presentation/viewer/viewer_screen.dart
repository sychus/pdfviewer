import 'dart:async';

import 'package:flutter/material.dart';

import '../../application/save_reading_position.dart';
import '../../domain/entities/document.dart';
import '../widgets/pdf_surface.dart';

/// Shows one document, and remembers where the reader got to.
///
/// Note what it does NOT import: pdfrx. It receives a domain [Document] and
/// hands a path to [PdfSurface]. Which engine renders it is not this screen's
/// business.
class ViewerScreen extends StatefulWidget {
  const ViewerScreen({
    super.key,
    required this.document,
    required this.resumeAt,
    required this.savePosition,
    this.onRecenter,
    this.onClose,
    this.documentHandle,
  });

  final Document document;

  /// 1-based page to open at, already resolved and range-checked by
  /// `OpenDocument`.
  final int resumeAt;

  final SaveReadingPosition savePosition;

  /// Drives the prewarm scheduler with a 0-based page index.
  /// Null when the streaming system is not in use.
  final ValueChanged<int>? onRecenter;

  /// Releases all streaming resources (PdfDocument, cache, scheduler).
  /// Null when the streaming system is not in use.
  final VoidCallback? onClose;

  /// Opaque native document handle. Passed to [PdfSurface] so the
  /// viewer reuses the already-open document.
  final Object? documentHandle;

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  /// Scrolling fires page changes continuously. Writing on every one of them
  /// would mean a disk write per page turn, for a value that changes again a
  /// second later. Debouncing collapses a burst of scrolling into one write.
  static const _writeDelay = Duration(seconds: 1);

  /// Current page, 1-based.
  ///
  /// A [ValueNotifier] rather than setState: the page counter changes on every
  /// scroll frame, and there is no reason to rebuild the whole screen — and
  /// its PDF surface — just to repaint a label.
  late final _page = ValueNotifier<int>(widget.resumeAt);

  /// Last page actually written, so a debounce that fires on an unchanged page
  /// costs nothing.
  late int _persisted = widget.resumeAt;

  Timer? _pendingWrite;

  void _onPageChanged(int page) {
    _page.value = page;
    _pendingWrite?.cancel();
    _pendingWrite = Timer(_writeDelay, _flush);
  }

  void _flush() {
    final page = _page.value;
    if (page == _persisted) return;
    _persisted = page;
    // Fire and forget: the reader is reading, not waiting on a write.
    unawaited(widget.savePosition(widget.document.id, page));
  }

  @override
  void dispose() {
    // Flush before tearing down. Debouncing alone would lose the last page
    // whenever the user closes the document within the delay window — which is
    // exactly what someone does when they finish reading and hit close.
    _pendingWrite?.cancel();
    _flush();
    _page.dispose();
    widget.onClose?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.document.title, overflow: TextOverflow.ellipsis),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ValueListenableBuilder<int>(
                valueListenable: _page,
                builder: (context, page, _) => Text(
                  '$page / ${widget.document.pageCount}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ),
          ),
        ],
      ),
      body: PdfSurface(
        path: widget.document.source.uri,
        initialPage: widget.resumeAt,
        onPageChanged: _onPageChanged,
        onRecenter: widget.onRecenter,
        documentHandle: widget.documentHandle,
      ),
    );
  }
}
