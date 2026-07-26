import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/entities/document_id.dart';
import '../domain/entities/reading_position.dart';
import '../domain/repositories/position_store.dart';

/// [PositionStore] backed by the platform's key-value store — `NSUserDefaults`
/// on Apple platforms, `SharedPreferences` on Android, the registry on Windows,
/// and so on.
///
/// Reading positions are tiny and there are at most a few per document, so a
/// key-value store is the right tool. If a library screen ever needs to sort
/// thousands of documents by last-read, that is when this gets swapped for a
/// real database — and because it sits behind [PositionStore], swapping it
/// touches this file only.
final class PrefsPositionStore implements PositionStore {
  PrefsPositionStore({SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  /// Namespaced so future keys cannot collide, and so stored positions can be
  /// enumerated later without guessing which keys are ours.
  static const _prefix = 'reading-position/';

  String _keyFor(DocumentId id) => '$_prefix${id.value}';

  @override
  Future<ReadingPosition?> load(DocumentId id) async {
    final raw = await _preferences.getString(_keyFor(id));
    if (raw == null) return null;

    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final page = json['page'] as int;

      // Validated, not asserted. `ReadingPosition` asserts 1-based pages, but
      // asserts are compiled out of release builds — they express invariants
      // the programmer guarantees, not checks on data crossing a boundary.
      // This is the boundary: these bytes came off disk and could be anything.
      if (page < 1) {
        throw FormatException('page must be 1-based, got $page');
      }

      return ReadingPosition(
        documentId: id,
        page: page,
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
    } catch (_) {
      // A corrupt entry is not worth crashing over — the worst outcome is that
      // the user starts from page one. Drop it so it cannot fail twice.
      await _preferences.remove(_keyFor(id));
      return null;
    }
  }

  @override
  Future<void> save(ReadingPosition position) => _preferences.setString(
        _keyFor(position.documentId),
        jsonEncode({
          'page': position.page,
          'updatedAt': position.updatedAt.toIso8601String(),
        }),
      );

  @override
  Future<void> clear(DocumentId id) => _preferences.remove(_keyFor(id));
}
