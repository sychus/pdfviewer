import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

/// The rendering surface for a PDF.
///
/// This is the ONLY widget in the app allowed to import pdfrx. Screens talk to
/// [PdfSurface] through plain Flutter types — a path, a page number, a callback
/// — and never learn which engine is behind it.
class PdfSurface extends StatefulWidget {
  const PdfSurface({
    super.key,
    required this.path,
    this.initialPage = 1,
    this.onPageChanged,
  }) : assert(initialPage >= 1, 'pages are 1-based');

  final String path;

  /// Where to open. 1-based.
  final int initialPage;

  /// Fires with the 1-based page number as the user scrolls.
  final ValueChanged<int>? onPageChanged;

  @override
  State<PdfSurface> createState() => _PdfSurfaceState();
}

class _PdfSurfaceState extends State<PdfSurface> {
  late final PdfViewerController _controller = PdfViewerController();

  @override
  Widget build(BuildContext context) {
    return PdfViewer.file(
      widget.path,
      controller: _controller,
      initialPageNumber: widget.initialPage,
      params: PdfViewerParams(
        onPageChanged: (pageNumber) {
          if (pageNumber != null) widget.onPageChanged?.call(pageNumber);
        },
      ),
    );
  }
}
