// lib/infrastructure/pdfrx/pdfrx_rendered_page.dart

import 'package:pdfrx/pdfrx.dart';

import '../../domain/entities/rendered_page.dart';

/// Domain [RenderedPage] backed by a pdfrx [PdfImage].
class PdfrxRenderedPage implements RenderedPage {
  PdfrxRenderedPage({
    required this.pageIndex,
    required this.image,
  });

  @override
  final int pageIndex;
  final PdfImage image;

  @override
  int get width => image.width;

  @override
  int get height => image.height;

  @override
  int get sizeBytes => width * height * 4;

  @override
  void dispose() => image.dispose();
}
