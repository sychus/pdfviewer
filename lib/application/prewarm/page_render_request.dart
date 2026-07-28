// lib/application/prewarm/page_render_request.dart

/// Re-export the domain entity so application-layer code has a single
/// stable import path. This is the only file under `lib/application/`
/// allowed to know about the domain entity's name.
export 'package:pdfviewer/domain/entities/page_render_request.dart'
    show PageRenderRequest;
