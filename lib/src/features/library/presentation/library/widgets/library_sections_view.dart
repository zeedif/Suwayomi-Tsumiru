// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'dart:async';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../constants/db_keys.dart';
import '../../../../../constants/enum.dart';
import '../../../../../routes/router_config.dart';
import '../../../../../utils/extensions/custom_extensions.dart';
import '../../../../../widgets/desktop/desktop_page_frame.dart';
import '../../../../../widgets/emoticons.dart';
import '../../../../../widgets/shell/update_banner_state.dart';
import '../../../../manga_book/data/updates/updates_repository.dart';
import '../../../../manga_book/domain/manga/manga_model.dart';
import '../../../../offline/data/server_reachability.dart';
import '../../../../tracking/data/tracker_repository.dart';
import '../controller/category_library_options.dart';
import '../controller/library_controller.dart';
import '../controller/library_grouping.dart';
import '../controller/library_manga_list.dart';
import '../controller/library_section_sort.dart';
import 'library_manga_grid_view.dart';
import 'library_manga_organizer.dart';

typedef LibrarySection = ({int id, String key, String name});

AsyncValue<List<MangaDto>?> watchLibrarySection(
  WidgetRef ref,
  LibrarySection section, {
  required bool byCategory,
}) => byCategory
    ? ref.watch(
        categoryMangaListWithQueryAndFilterProvider(categoryId: section.id),
      )
    : ref.watch(groupedMangaListWithQueryAndFilterProvider(tabId: section.id));

/// Writes libraryVisibleSectionProvider from scroll position; never drives scrolling from it.
class LibrarySectionsView extends HookConsumerWidget {
  const LibrarySectionsView({
    super.key,
    required this.sections,
    required this.byCategory,
    this.showCounts = false,
  });

  final List<LibrarySection> sections;

  /// True uses category providers; false uses grouped-list providers.
  final bool byCategory;

  final bool showCounts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Retain keys across rebuilds so section tracking follows the same elements.
    final headerKeys = useRef(<int, GlobalKey>{});
    for (final s in sections) {
      headerKeys.value.putIfAbsent(s.id, GlobalKey.new);
    }
    headerKeys.value.removeWhere((id, _) => !sections.any((s) => s.id == id));

    final scrollController = useScrollController();

    void trackVisibleSection() {
      if (!scrollController.hasClients) return;
      int? topId;
      double? topY;
      int? firstId;
      double? firstY;
      for (final entry in headerKeys.value.entries) {
        final box =
            entry.value.currentContext?.findRenderObject() as RenderBox?;
        if (box == null || !box.attached) continue;
        final viewport = RenderAbstractViewport.of(box) as RenderBox;
        final viewportTop = viewport.localToGlobal(Offset.zero).dy;
        final y = box.localToGlobal(Offset.zero).dy;
        // The closest header at or above the viewport top is the active pinned section.
        if (y <= viewportTop + 1 && (topY == null || y > topY)) {
          topY = y;
          topId = entry.key;
        }
        if (firstY == null || y < firstY) {
          firstY = y;
          firstId = entry.key;
        }
      }
      final visible = topId ?? firstId;
      if (visible != ref.read(libraryVisibleSectionProvider)) {
        ref.read(libraryVisibleSectionProvider.notifier).update(visible);
      }
    }

    useEffect(() {
      scrollController.addListener(trackVisibleSection);
      // Initial layout emits no scroll event; seed the visible section after layout.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) trackVisibleSection();
      });
      return () => scrollController.removeListener(trackVisibleSection);
      // Group changes shift the section at the current offset.
    }, [scrollController, sections.length]);

    return RefreshIndicator(
      onRefresh: () async {
        ref.read(viewOfflineNowProvider.notifier).set(false);
        ref.read(serverUnreachableProvider.notifier).set(false);
        ref.read(updateOptimisticProvider.notifier).arm();
        unawaited(
          ref
              .read(updatesRepositoryProvider)
              .fetchUpdates()
              .catchError((Object _) {}),
        );
        ref.invalidate(libraryMangaListProvider);
        await ref.read(libraryMangaListProvider.future);
      },
      // Sections that finish loading change the extent without a scroll event.
      child: NotificationListener<ScrollMetricsNotification>(
        onNotification: (_) {
          trackVisibleSection();
          return false;
        },
        child: CustomScrollView(
          controller: scrollController,
          slivers: [
            for (final section in sections)
              _Section(
                key: ValueKey(section.id),
                headerKey: headerKeys.value[section.id]!,
                section: section,
                byCategory: byCategory,
                showCount: showCounts,
              ),
          ],
        ),
      ),
    );
  }
}

// SliverMainAxisGroup unpins a header when its own group scrolls away.
class _Section extends ConsumerWidget {
  const _Section({
    super.key,
    required this.headerKey,
    required this.section,
    required this.byCategory,
    required this.showCount,
  });

  final LibrarySection section;
  final bool byCategory;
  final bool showCount;

  final GlobalKey headerKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = watchLibrarySection(ref, section, byCategory: byCategory);
    final items = listAsync.value ?? const [];
    final showEmpty =
        byCategory &&
        listAsync.value != null &&
        ref.watch(useCategoryLibraryOptionsProvider);

    if (items.isEmpty && !showEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverMainAxisGroup(
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _SectionHeaderDelegate(
            headerKey: headerKey,
            section: section,
            byCategory: byCategory,
            showCount: showCount,
          ),
        ),
        if (items.isEmpty)
          SliverToBoxAdapter(
            child: Emoticons(title: context.l10n.noCategoryMangaFound),
          ),
        LibraryMangaSliver(
          items: items,
          onOpen: (manga) => MangaRoute(
            mangaId: manga.id,
            categoryId: byCategory ? section.id : null,
          ).push(context),
          linkLocationFor: (manga) => MangaRoute(
            mangaId: manga.id,
            categoryId: byCategory ? section.id : null,
          ).location,
        ),
      ],
    );
  }
}

class _SectionHeaderDelegate extends SliverPersistentHeaderDelegate {
  _SectionHeaderDelegate({
    required this.headerKey,
    required this.section,
    required this.byCategory,
    required this.showCount,
  });

  final GlobalKey headerKey;
  final LibrarySection section;
  final bool byCategory;
  final bool showCount;

  @override
  double get minExtent => LibrarySectionHeader.height;

  @override
  double get maxExtent => LibrarySectionHeader.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return LibrarySectionHeader(
      key: headerKey,
      section: section,
      byCategory: byCategory,
      showCount: showCount,
    );
  }

  @override
  bool shouldRebuild(_SectionHeaderDelegate old) =>
      old.section != section ||
      old.byCategory != byCategory ||
      old.showCount != showCount;
}

/// Title row shared by the continuous and paged section layouts.
class LibrarySectionHeader extends ConsumerWidget {
  const LibrarySectionHeader({
    super.key,
    required this.section,
    required this.byCategory,
    required this.showCount,
  });

  static const height = 40.0;

  final LibrarySection section;
  final bool byCategory;
  final bool showCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = showCount
        ? watchLibrarySection(ref, section, byCategory: byCategory)
              .value
              ?.length
        : null;
    return Container(
      height: height,
      width: double.infinity,
      // Opaque headers hide rows scrolling underneath.
      color: context.theme.colorScheme.surface,
      alignment: AlignmentDirectional.centerStart,
      padding: const EdgeInsets.symmetric(horizontal: 8)
          .onDesktopPageLine(context),
      child: Row(
        children: [
          Expanded(
            child: Text(
              count == null ? section.name : '${section.name} ($count)',
              overflow: TextOverflow.ellipsis,
              style: context.theme.textTheme.titleSmall?.copyWith(
                color: context.theme.colorScheme.primary,
              ),
            ),
          ),
          _SectionSortButton(section: section, byCategory: byCategory),
        ],
      ),
    );
  }
}

/// Picks the sort of one section; picking the current sort flips its direction.
class _SectionSortButton extends ConsumerWidget {
  const _SectionSortButton({required this.section, required this.byCategory});

  final LibrarySection section;
  final bool byCategory;

  static IconData _icon(SectionSort value) => value.sort == MangaSort.random
      ? FluentIcons.arrow_shuffle_24_regular
      : value.ascending
      ? FluentIcons.arrow_sort_up_24_regular
      : FluentIcons.arrow_sort_down_24_regular;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = librarySectionSortProvider(
      id: section.id,
      key: section.key,
      byCategory: byCategory,
    );
    final current = ref.watch(provider);
    final hasTrackers =
        ref.watch(loggedInTrackersProvider).value?.isNotEmpty ?? false;
    // Categories shared with WebUI only store the sorts it knows.
    final webUiSorts =
        byCategory && ref.watch(useCategoryLibraryOptionsProvider);
    final primary = context.theme.colorScheme.primary;
    return PopupMenuButton<MangaSort>(
      tooltip: context.l10n.sort,
      position: PopupMenuPosition.under,
      onSelected: (sort) {
        if (sort != current.sort) {
          ref.read(provider.notifier).update(sort: sort);
        } else if (sort == MangaSort.random) {
          final seed =
              ref.read(librarySortRandomSeedProvider) ??
              DBKeys.librarySortRandomSeed.initial as int;
          ref.read(librarySortRandomSeedProvider.notifier).update(seed + 1);
        } else {
          ref.read(provider.notifier).update(ascending: !current.ascending);
        }
      },
      itemBuilder: (context) => [
        for (final sort in librarySortDisplayOrder)
          if ((sort != MangaSort.trackerScore || hasTrackers) &&
              (!webUiSorts || categorySortModes.containsKey(sort)))
            PopupMenuItem(
              value: sort,
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: sort == current.sort
                        ? Icon(_icon(current), size: 20, color: primary)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Flexible(child: Text(sort.toLocale(context))),
                ],
              ),
            ),
      ],
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              current.sort.toLocale(context),
              style: context.theme.textTheme.labelMedium?.copyWith(
                color: primary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(_icon(current), size: 16, color: primary),
          ],
        ),
      ),
    );
  }
}
