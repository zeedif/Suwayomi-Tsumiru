// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../domain/library_group.dart';
import 'library_grouping.dart';
import 'library_section_meta.dart';

part 'library_section_order.g.dart';

const kSectionOrderMetaKey = 'tsumiru_library_section_order';

/// Groups named in [order] lead in that order; the rest keep their built-in order.
List<GroupedTab> applySectionOrder(List<GroupedTab> tabs, List<String> order) {
  if (order.isEmpty) return tabs;
  final byKey = {for (final tab in tabs) tab.key: tab};
  final leading = [for (final key in order) ?byKey.remove(key)];
  return [...leading, ...tabs.where((tab) => byKey.containsKey(tab.key))];
}

/// Shortest prefix of [ordered] that [applySectionOrder] expands back to it.
/// Keeps the stored order small for groupings with hundreds of tags.
List<String> compactSectionOrder(List<String> ordered, List<String> natural) {
  final rank = {for (var i = 0; i < natural.length; i++) natural[i]: i};
  var start = ordered.length;
  while (start > 0 &&
      (start == ordered.length ||
          rank[ordered[start - 1]]! < rank[ordered[start]]!)) {
    start--;
  }
  return ordered.sublist(0, start);
}

/// Group keys the user moved ahead under the active grouping.
@riverpod
class LibrarySectionOrder extends _$LibrarySectionOrder {
  @override
  List<String> build() {
    final groupType =
        ref.watch(libraryGroupTypeProvider) ?? kDefaultLibraryGroupType;
    // Categories keep the order set in Edit categories.
    if (groupType == LibraryGroup.byDefault) return const [];
    final stored = ref.watch(
      librarySectionMetaProvider(kSectionOrderMetaKey),
    )['$groupType'];
    return [
      if (stored is List)
        for (final key in stored)
          if (key is String) key,
    ];
  }

  /// Saves [ordered], every key of the loaded groups in their new order.
  Future<void> save(List<String> ordered) async {
    final natural = [
      for (final tab in await ref.read(libraryNaturalTabsProvider.future))
        tab.key,
    ];
    if (!ref.mounted) return;
    final present = natural.toSet();
    final kept = {...ordered.where(present.contains)};
    _write([
      ...compactSectionOrder([
        ...kept,
        ...natural.where((key) => !kept.contains(key)),
      ], natural),
      // Offline the library may be partial; keep groups it did not load.
      if (!libraryGroupsComplete(ref))
        ...state.where((key) => !present.contains(key)),
    ]);
  }

  void reset() => _write(const []);

  void _write(List<String> order) {
    final groupType =
        ref.read(libraryGroupTypeProvider) ?? kDefaultLibraryGroupType;
    final meta = librarySectionMetaProvider(kSectionOrderMetaKey);
    ref.read(meta.notifier).write({...ref.read(meta), '$groupType': order});
  }
}
