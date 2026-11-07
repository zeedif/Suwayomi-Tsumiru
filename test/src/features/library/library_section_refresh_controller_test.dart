import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:tsumiru/src/features/library/data/default_category.dart';
import 'package:tsumiru/src/features/library/presentation/library/controller/library_grouping.dart';
import 'package:tsumiru/src/features/library/presentation/library/controller/library_section_refresh.dart';
import 'package:tsumiru/src/features/manga_book/data/manga_book/manga_book_repository.dart';
import 'package:tsumiru/src/features/manga_book/data/updates/updates_repository.dart';
import 'package:tsumiru/src/features/manga_book/domain/chapter/chapter_model.dart';
import 'package:tsumiru/src/widgets/shell/update_banner_state.dart';

class _Updates extends Fake implements UpdatesRepository {
  final categories = <int?>[];

  @override
  Future<void> fetchUpdates({int? categoryId}) async =>
      categories.add(categoryId);
}

class _Manga extends Fake implements MangaBookRepository {
  _Manga(this.gate);

  final Completer<void> gate;
  final fetched = <int>[];

  @override
  Future<List<ChapterDto>?> getMangaAndChapterList(int mangaId) async {
    await gate.future;
    fetched.add(mangaId);
    if (mangaId == 13) throw StateError('source down');
    return const [];
  }
}

class _Optimistic extends UpdateOptimistic {
  @override
  void arm() {}
}

ProviderContainer _container(_Updates updates, _Manga manga) {
  final container = ProviderContainer(
    overrides: [
      settledDefaultCategoryIdProvider.overrideWithValue(0),
      updatesRepositoryProvider.overrideWithValue(updates),
      mangaBookRepositoryProvider.overrideWithValue(manga),
      updateOptimisticProvider.overrideWith(_Optimistic.new),
      libraryGroupedTabsProvider.overrideWith(
        (ref) async => [
          (id: 1, key: 'reading', name: 'Reading', mangaIds: [11, 12, 13]),
        ],
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('updates categories through the server', () async {
    final updates = _Updates();
    final manga = _Manga(Completer()..complete());
    final container = _container(updates, manga);

    final failed = await container
        .read(librarySectionRefreshProvider.notifier)
        .refresh(id: 4, key: '4', byCategory: true);

    expect(failed, 0);
    expect(updates.categories, [4]);
    expect(manga.fetched, isEmpty);
  });

  test('fetches every entry of a group and counts failures', () async {
    final manga = _Manga(Completer());
    final container = _container(_Updates(), manga);
    await container.read(libraryGroupedTabsProvider.future);
    final notifier = container.read(librarySectionRefreshProvider.notifier);

    final run = notifier.refresh(id: 1, key: 'reading', byCategory: false);
    expect(container.read(librarySectionRefreshProvider), {'reading'});
    expect(await notifier.refresh(id: 1, key: 'reading', byCategory: false), 0);
    manga.gate.complete();

    expect(await run, 1);
    expect(manga.fetched..sort(), [11, 12, 13]);
    expect(container.read(librarySectionRefreshProvider), isEmpty);
  });
}
