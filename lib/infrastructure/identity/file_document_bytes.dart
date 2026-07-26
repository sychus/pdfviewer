import 'dart:io';
import 'dart:typed_data';

import 'document_bytes.dart';

/// [DocumentBytes] backed by a filesystem file.
///
/// Covers desktop, and the mobile cases where the platform has already resolved
/// a `content://` URI or a security scope down to a concrete file.
/// Platform-specific adapters will live alongside this one, implementing the
/// same interface.
final class FileDocumentBytes implements DocumentBytes {
  const FileDocumentBytes(this.file);

  final File file;

  @override
  Future<int> length() => file.length();

  @override
  Future<Uint8List> read({required int offset, required int length}) async {
    if (length == 0) return Uint8List(0);

    final handle = await file.open();
    try {
      await handle.setPosition(offset);
      // The `await` is load-bearing. `return handle.read(...)` would run the
      // `finally` block immediately, closing the handle while the read is
      // still in flight, and the VM throws
      // "FileSystemException: An async operation is currently pending".
      return await handle.read(length);
    } finally {
      await handle.close();
    }
  }
}
