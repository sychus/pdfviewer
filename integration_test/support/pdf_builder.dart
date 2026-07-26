import 'dart:convert';
import 'dart:typed_data';

/// Builds structurally valid PDFs in memory, for tests and benchmarks.
///
/// Hand-rolled rather than checked in as binaries, for two reasons. Tests stay
/// hermetic — no fixture directory to resolve, which matters because on macOS
/// the test process runs inside the app's sandbox container and cannot see the
/// project tree. And benchmarks can dial page count and page weight
/// independently, which is the whole point of measuring.
///
/// Cross-reference offsets are byte-exact by spec. The content is pure ASCII,
/// so string length equals byte length and offsets can be taken as the buffer
/// is assembled.
Uint8List buildPdf({int pageCount = 1, int linesPerPage = 0}) {
  assert(pageCount > 0, 'a PDF needs at least one page');
  assert(linesPerPage >= 0, 'line count cannot be negative');

  final out = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[];

  void writeObject(String body) {
    offsets.add(out.length);
    out.write('${offsets.length} 0 obj\n$body\nendobj\n');
  }

  // Object 1 is the catalog, 2 the page tree, 3 the shared font. Each page then
  // takes two objects: the page itself and its content stream.
  const catalogId = 1;
  const pagesId = 2;
  const fontId = 3;
  const firstPageId = 4;

  final pageIds = [
    for (var i = 0; i < pageCount; i++) firstPageId + i * 2,
  ];
  final kids = pageIds.map((id) => '$id 0 R').join(' ');

  writeObject('<< /Type /Catalog /Pages $pagesId 0 R >>');
  writeObject('<< /Type /Pages /Kids [$kids] /Count $pageCount >>');
  writeObject('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>');

  for (var page = 0; page < pageCount; page++) {
    final contentId = pageIds[page] + 1;

    writeObject(
      '<< /Type /Page /Parent $pagesId 0 R /MediaBox [0 0 612 792] '
      '/Resources << /Font << /F1 $fontId 0 R >> >> '
      '/Contents $contentId 0 R >>',
    );

    final stream = _contentStream(page + 1, linesPerPage);
    writeObject('<< /Length ${stream.length} >>\nstream\n$stream\nendstream');
  }

  // The cross-reference table always includes the mandatory free object 0.
  final entryCount = offsets.length + 1;
  final xrefOffset = out.length;

  out.write('xref\n0 $entryCount\n');
  out.write('0000000000 65535 f \n');
  for (final offset in offsets) {
    out.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
  }
  out.write('trailer\n<< /Size $entryCount /Root $catalogId 0 R >>\n');
  out.write('startxref\n$xrefOffset\n%%EOF\n');

  return Uint8List.fromList(latin1.encode(out.toString()));
}

/// Text-drawing operators for one page.
///
/// [lines] controls how heavy the page is: 0 leaves it blank, higher values
/// make PDFium do proportionally more parsing and glyph work per page.
String _contentStream(int pageNumber, int lines) {
  final buffer = StringBuffer('BT\n/F1 12 Tf\n');

  buffer.write('72 720 Td\n(Page $pageNumber) Tj\n');
  for (var line = 0; line < lines; line++) {
    // Leading is applied by TD, so each line steps down the page.
    buffer.write('0 -14 Td\n');
    buffer.write('(Line $line of page $pageNumber '
        '- the quick brown fox jumps over the lazy dog) Tj\n');
  }

  buffer.write('ET');
  return buffer.toString();
}
