import 'dart:typed_data';

/// Read-only, range-based access to a document's bytes.
///
/// This is an INFRASTRUCTURE concept. The domain does not care about bytes:
/// you will not find this interface imported from `domain/`.
///
/// It exists for two concrete reasons:
///
/// 1. Every platform delivers bytes differently: a `File` on desktop, a
///    `content://` resolved through the ContentResolver on Android, a
///    security-scoped resource on iOS. Fingerprinting should not have to know.
///
/// 2. It makes the fingerprint algorithm testable in memory, without touching
///    disk.
abstract interface class DocumentBytes {
  /// Total size in bytes.
  Future<int> length();

  /// Reads [length] bytes starting at [offset].
  ///
  /// May return fewer bytes than requested if the end is reached.
  Future<Uint8List> read({required int offset, required int length});
}
