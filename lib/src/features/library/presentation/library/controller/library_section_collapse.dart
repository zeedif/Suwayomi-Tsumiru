// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../domain/library_group.dart';
import '../../category/controller/edit_category_controller.dart';
import 'library_grouping.dart';
import 'library_section_meta.dart';

part 'library_section_collapse.g.dart';

const kCollapsedSectionsMetaKey = 'tsumiru_library_collapsed_sections';

/// Section keys collapsed under the active grouping.
@riverpod
class LibraryCollapsedSections extends _$LibraryCollapsedSections {
  @override
  Set<String> build() {
    final stored = ref.watch(
      librarySectionMetaProvider(kCollapsedSectionsMetaKey),
    )['${_groupType()}'];
    return {
      if (stored is List)
        for (final key in stored)
          if (key is String) key,
    };
  }

  int _groupType() =>
      ref.watch(libraryGroupTypeProvider) ?? kDefaultLibraryGroupType;

  void toggle(String key) =>
      _write(state.contains(key) ? ({...state}..remove(key)) : {...state, key});

  /// Collapses every key, or expands them all when they are already collapsed.
  void toggleAll(Iterable<String> keys) => _write(
    keys.every(state.contains)
        ? state.difference(keys.toSet())
        : {...state, ...keys},
  );

  void _write(Set<String> collapsed) {
    final groupType =
        ref.read(libraryGroupTypeProvider) ?? kDefaultLibraryGroupType;
    final known = _knownKeys(groupType);
    final meta = librarySectionMetaProvider(kCollapsedSectionsMetaKey);
    ref.read(meta.notifier).write({
      ...ref.read(meta),
      '$groupType': [
        for (final key in collapsed)
          if (known?.contains(key) ?? true) key,
      ]..sort(),
    });
  }

  /// Null while the groups may be partial, so keys of missing groups survive.
  Set<String>? _knownKeys(int groupType) {
    if (!libraryGroupsComplete(ref)) return null;
    if (groupType == LibraryGroup.byDefault) {
      final categories = ref.read(categoryControllerProvider).value;
      return categories == null
          ? null
          : {for (final category in categories) '${category.id}'};
    }
    final tabs = ref.read(libraryGroupedTabsProvider).value;
    return tabs == null ? null : {for (final tab in tabs) tab.key};
  }
}
