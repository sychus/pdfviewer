import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

/// The rendering surface for a PDF.
///
/// This is the ONLY widget in the app allowed to import pdfrx. Screens talk to
/// [PdfSurface] through plain Flutter types — a path, a page number, a callback
/// — and never learn which engine is behind it.
///
/// The point is not purity for its own sake. It means replacing the renderer
/// (pdfrx_coregraphics on Apple platforms, say, to cut bundle size) changes
/// this file and nothing else.
class PdfSurface extends StatefulWidget {
  const PdfSurface({
    super.key,
    required this.path,
    this.initialPage = 1,
    this.onPageChanged,
    this.onRecenter,
    this.documentHandle,
  }) : assert(initialPage >= 1, 'pages are 1-based');

  final String path;

  /// Where to open. 1-based.
  final int initialPage;

  /// Fires with the 1-based page number as the user scrolls.
  final ValueChanged<int>? onPageChanged;

  /// Drives the prewarm scheduler: called with the 0-based page index
  /// every time the visible page changes, so background renders follow
  /// the reader.
  final ValueChanged<int>? onRecenter;

  /// Opaque handle from [OpenResult.documentHandle]. When present
  /// (and it's a [PdfDocumentRef]), the viewer reuses the already-open
  /// document instead of opening the file a second time.
  final Object? documentHandle;

  @override
  State<PdfSurface> createState() => _PdfSurfaceState();
}

class _PdfSurfaceState extends State<PdfSurface> {
  late final PdfViewerController _controller = PdfViewerController();

  PdfViewerParams get _params => PdfViewerParams(
        onPageChanged: (pageNumber) {
          if (pageNumber != null) {
            widget.onPageChanged?.call(pageNumber);
            widget.onRecenter?.call(pageNumber - 1);
          }
        },
      );

  @override
  Widget build(BuildContext context) {
    final handle = widget.documentHandle;

    // If the streaming system gave us a PdfDocumentRef, reuse it —
    // this avoids opening the file a second time.
    if (handle is PdfDocumentRef) {
      return PdfViewer(
        handle,
        controller: _controller,
        initialPageNumber: widget.initialPage,
        params: _params,
      );
    }

    // Fallback: open from the file path (old code path, kept for
    // backwards compat until the streaming flow is the only entry).
    return PdfViewer.file(
      widget.path,
      controller: _controller,
      initialPageNumber: widget.initialPage,
      params: _params,
    );
  }
}
