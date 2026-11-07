// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:collection/collection.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../widgets/shell/update_banner_state.dart';
import '../../../../manga_book/data/manga_book/manga_book_repository.dart';
import '../../../../manga_book/data/updates/updates_repository.dart';
import '../../../data/default_category.dart';
import 'library_controller.dart';
import 'library_grouping.dart';
import 'library_manga_list.dart';

part 'library_section_refresh.g.dart';

/// Low concurrency avoids saturating self-hosted servers.
const _kRefreshConcurrency = 2;

/// Keys of sections whose entries are being fetched one by one.
@Riverpod(keepAlive: true)
class LibrarySectionRefresh extends _$LibrarySectionRefresh {
  @override
  Set<String> build() => const {};

  /// Returns how many entries failed to update.
  ///
  /// The server only updates whole categories, so the default category and
  /// groups other than categories fetch their entries here instead.
  Future<int> refresh({
    required int id,
    required String key,
    required bool byCategory,
  }) async {
    if (state.contains(key)) return 0;
    final defaultId = ref.read(settledDefaultCategoryIdProvider);
    if (byCategory && defaultId != null && id != defaultId) {
      ref.read(updateOptimisticProvider.notifier).arm();
      await ref.read(updatesRepositoryProvider).fetchUpdates(categoryId: id);
      return 0;
    }
    state = {...state, key};
    var failed = 0;
    try {
      final queue = byCategory
          ? [
              for (final manga
                  in await ref.read(categoryMangaListProvider(id).future) ??
                      const [])
                manga.id,
            ]
          : [
              ...?ref
                  .read(libraryGroupedTabsProvider)
                  .value
                  ?.firstWhereOrNull((tab) => tab.id == id)
                  ?.mangaIds,
            ];
      final repo = ref.read(mangaBookRepositoryProvider);
      Future<void> worker() async {
        while (queue.isNotEmpty) {
          final mangaId = queue.removeLast();
          try {
            await repo.getMangaAndChapterList(mangaId);
          } catch (_) {
            failed++;
          }
        }
      }

      await Future.wait([
        for (var i = 0; i < _kRefreshConcurrency; i++) worker(),
      ]);
    } finally {
      state = {...state}..remove(key);
      ref.invalidate(libraryMangaListProvider);
    }
    return failed;
  }
}
