// lib/application/open_document/open_streaming_document.dart

import 'package:pdfviewer/domain/entities/document_source.dart';
import 'package:pdfviewer/domain/repositories/document_repository.dart';

/// Use case: open a PDF and return a ready-to-paint first page plus
/// the cache the UI will use as the user scrolls.
///
/// The streaming aspect is hidden behind [DocumentRepository.openStreaming];
/// this class exists to be the single entry point the UI calls, and to
/// be the natural place to add cross-cutting concerns later (telemetry,
/// error reporting, etc.).
class OpenStreamingDocument {
  const OpenStreamingDocument(this._repository);

  final DocumentRepository _repository;

  Future<OpenResult> call({
    required DocumentSource source,
    int prewarmRadius = 3,
    double firstPageScale = 1.0,
    double prewarmScale = 0.5,
  }) {
    return _repository.openStreaming(
      source,
      firstPageScaleNumerator: (firstPageScale * 1000).round(),
      firstPageScaleDenominator: 1000,
      prewarmScaleNumerator: (prewarmScale * 1000).round(),
      prewarmScaleDenominator: 1000,
      prewarmRadius: prewarmRadius,
    );
  }
}
