// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../constants/db_keys.dart';
import '../../../../../constants/enum.dart';
import '../../../../../utils/extensions/custom_extensions.dart';
import '../../../../../utils/webui_meta/webui_meta_codec.dart';
import '../../../domain/library_group.dart';
import '../../category/controller/edit_category_controller.dart';
import 'category_library_options.dart';
import 'library_controller.dart';
import 'library_grouping.dart';
import 'library_section_meta.dart';

part 'library_section_sort.g.dart';

const kSectionSortsMetaKey = 'tsumiru_library_section_sorts';

typedef SectionSort = ({MangaSort sort, bool ascending});

/// Sorts picked from section headers under the active grouping, by section key.
@riverpod
class LibrarySectionSorts extends _$LibrarySectionSorts {
  @override
  Map<String, SectionSort> build() {
    final groupType =
        ref.watch(libraryGroupTypeProvider) ?? kDefaultLibraryGroupType;
    final stored = ref.watch(
      librarySectionMetaProvider(kSectionSortsMetaKey),
    )['$groupType'];
    if (stored is! Map<String, dynamic>) return const {};
    return {
      for (final e in stored.entries)
        if (e.value case {
          'sort': final String name,
          'ascending': final bool ascending,
        })
          if (MangaSort.values.asNameMap()[name] case final sort?)
            e.key: (sort: sort, ascending: ascending),
    };
  }

  void set(String key, SectionSort sort) {
    final known = _knownKeys();
    _write({
      for (final e in {...state, key: sort}.entries)
        if (known?.contains(e.key) ?? true)
          e.key: {'sort': e.value.sort.name, 'ascending': e.value.ascending},
    });
  }

  /// Lets every section of the active grouping follow the library sort again.
  void clear() {
    if (state.isNotEmpty) _write(null);
  }

  void _write(Map<String, dynamic>? sorts) {
    final groupType =
        ref.read(libraryGroupTypeProvider) ?? kDefaultLibraryGroupType;
    final meta = librarySectionMetaProvider(kSectionSortsMetaKey);
    ref.read(meta.notifier).write({
      for (final e in ref.read(meta).entries)
        if (e.key != '$groupType') e.key: e.value,
      '$groupType': ?sorts,
    });
  }

  /// Null while the groups may be partial, so sorts of missing groups survive.
  Set<String>? _knownKeys() {
    if (!libraryGroupsComplete(ref)) return null;
    final groupType =
        ref.read(libraryGroupTypeProvider) ?? kDefaultLibraryGroupType;
    if (groupType == LibraryGroup.byDefault) {
      final categories = ref.read(categoryControllerProvider).value;
      return categories?.map((category) => '${category.id}').toSet();
    }
    return ref
        .read(libraryGroupedTabsProvider)
        .value
        ?.map((tab) => tab.key)
        .toSet();
  }
}

/// Sort a section follows, saved wherever that section keeps it.
@riverpod
class LibrarySectionSort extends _$LibrarySectionSort {
  @override
  SectionSort build({
    required int id,
    required String key,
    required bool byCategory,
  }) {
    // Per-category settings keep category sorts in the meta WebUI shares.
    if (byCategory && ref.watch(useCategoryLibraryOptionsProvider)) {
      final options = ref.watch(effectiveCategoryLibraryOptionsProvider(id));
      return (sort: options.sort!, ascending: options.ascending!);
    }
    return ref.watch(librarySectionSortsProvider)[key] ??
        (
          sort: ref.watch(libraryMangaSortProvider) ?? DBKeys.mangaSort.initial,
          ascending: ref.watch(libraryMangaSortDirectionProvider).ifNull(true),
        );
  }

  void update({MangaSort? sort, bool? ascending}) {
    if (byCategory && ref.read(useCategoryLibraryOptionsProvider)) {
      final meta = CategoryLibraryOptions(
        sort: sort,
        ascending: ascending,
      ).toMeta();
      ref.read(categoryLibraryMetadataProvider(id).notifier).write({
        if (sort != null) 'sortBy': meta[webUiKey('sortBy')],
        if (ascending != null) 'sortDesc': meta[webUiKey('sortDesc')],
      });
      return;
    }
    ref.read(librarySectionSortsProvider.notifier).set(key, (
      sort: sort ?? state.sort,
      ascending: ascending ?? state.ascending,
    ));
  }
}
