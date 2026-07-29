import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

/// The rendering surface for a PDF.
///
/// This is the ONLY widget in the app allowed to import pdfrx.
class PdfSurface extends StatefulWidget {
  const PdfSurface({
    super.key,
    required this.path,
    this.initialPage = 1,
    this.onPageChanged,
    this.onDocumentLoaded,
  }) : assert(initialPage >= 1, 'pages are 1-based');

  final String path;
  final int initialPage;

  /// Fires with the 1-based page number as the user scrolls.
  final ValueChanged<int>? onPageChanged;

  /// Fires once when pdfrx finishes loading, with the total page count.
  final ValueChanged<int>? onDocumentLoaded;

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
        onDocumentChanged: (document) {
          if (document != null) {
            widget.onDocumentLoaded?.call(document.pages.length);
          }
        },
      ),
    );
  }
}
