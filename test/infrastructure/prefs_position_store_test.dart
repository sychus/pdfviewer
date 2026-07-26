import 'package:flutter_test/flutter_test.dart';
import 'package:pdfviewer/domain/entities/document_id.dart';
import 'package:pdfviewer/domain/entities/reading_position.dart';
import 'package:pdfviewer/infrastructure/prefs_position_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

const _manual = DocumentId('sha256-manual');
const _novel = DocumentId('sha256-novel');

ReadingPosition _position(DocumentId id, int page) => ReadingPosition(
      documentId: id,
      page: page,
      updatedAt: DateTime.utc(2026, 7, 25, 12, 30),
    );

void main() {
  late PrefsPositionStore store;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    store = PrefsPositionStore();
  });

  group('PrefsPositionStore', () {
    test('an unread document has no position', () async {
      expect(await store.load(_manual), isNull);
    });

    test('round-trips a position', () async {
      await store.save(_position(_manual, 47));

      final loaded = await store.load(_manual);

      expect(loaded, isNotNull);
      expect(loaded!.page, 47);
      expect(loaded.documentId, _manual);
      expect(loaded.updatedAt, DateTime.utc(2026, 7, 25, 12, 30));
    });

    test('saving again overwrites', () async {
      await store.save(_position(_manual, 47));
      await store.save(_position(_manual, 91));

      expect((await store.load(_manual))!.page, 91);
    });

    test('documents do not collide with each other', () async {
      await store.save(_position(_manual, 47));
      await store.save(_position(_novel, 3));

      expect((await store.load(_manual))!.page, 47);
      expect((await store.load(_novel))!.page, 3);
    });

    test('clear forgets a position', () async {
      await store.save(_position(_manual, 47));
      await store.clear(_manual);

      expect(await store.load(_manual), isNull);
    });

    test('a corrupt entry reads as absent and is dropped', () async {
      // Anything could have written garbage here: an aborted write, a botched
      // migration, a future version of us. Losing a bookmark is acceptable;
      // throwing on every open of that document is not.
      final raw = SharedPreferencesAsync();
      await raw.setString('reading-position/${_manual.value}', 'not json');

      expect(await store.load(_manual), isNull);

      // Dropped, so it cannot fail a second time.
      expect(await raw.getString('reading-position/${_manual.value}'), isNull);
    });

    test('a page below one reads as absent and is dropped', () async {
      // Well-formed JSON, invalid domain value. `ReadingPosition` asserts
      // 1-based pages, but asserts vanish in release builds — so the check
      // that matters is the one here, at the boundary where bytes from disk
      // become domain objects.
      final raw = SharedPreferencesAsync();
      await raw.setString(
        'reading-position/${_manual.value}',
        '{"page":0,"updatedAt":"2026-07-25T12:30:00.000Z"}',
      );

      expect(await store.load(_manual), isNull);
      expect(await raw.getString('reading-position/${_manual.value}'), isNull);
    });

    test('a page above the range is still stored — clamping is not our job',
        () async {
      // The store's contract is "give back what was written, if it is
      // structurally valid". It has no idea how many pages the document has;
      // only `OpenDocument` does, and that is where the upper clamp lives.
      await store.save(_position(_manual, 9999));

      expect((await store.load(_manual))!.page, 9999);
    });
  });
}
