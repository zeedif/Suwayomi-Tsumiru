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

import '../../../../../routes/router_config.dart';
import '../../../../../utils/extensions/custom_extensions.dart';
import '../../../../../widgets/desktop/desktop_page_frame.dart';
import '../../../../../widgets/emoticons.dart';
import '../../../../../widgets/shell/update_banner_state.dart';
import '../../../../manga_book/data/updates/updates_repository.dart';
import '../../../../manga_book/domain/manga/manga_model.dart';
import '../../../../offline/data/server_reachability.dart';
import '../controller/category_library_options.dart';
import '../controller/library_controller.dart';
import '../controller/library_grouping.dart';
import '../controller/library_manga_list.dart';
import '../controller/library_section_collapse.dart';
import 'library_manga_grid_view.dart';

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
                onToggleAll: () => ref
                    .read(libraryCollapsedSectionsProvider.notifier)
                    .toggleAll(sections.map((s) => s.key)),
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
    required this.onToggleAll,
  });

  final LibrarySection section;
  final bool byCategory;
  final bool showCount;
  final VoidCallback onToggleAll;

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
    // Searching expands every section so no match stays hidden.
    final collapsible = ref.watch(libraryQueryDebouncedProvider).isBlank;
    final collapsed =
        collapsible &&
        ref.watch(
          libraryCollapsedSectionsProvider.select(
            (keys) => keys.contains(section.key),
          ),
        );

    return SliverMainAxisGroup(
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _SectionHeaderDelegate(
            headerKey: headerKey,
            section: section,
            byCategory: byCategory,
            showCount: showCount,
            collapsed: collapsible ? collapsed : null,
            onTap: collapsible
                ? () => ref
                      .read(libraryCollapsedSectionsProvider.notifier)
                      .toggle(section.key)
                : null,
            onLongPress: collapsible ? onToggleAll : null,
          ),
        ),
        if (!collapsed) ...[
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
    this.collapsed,
    this.onTap,
    this.onLongPress,
  });

  final GlobalKey headerKey;
  final LibrarySection section;
  final bool byCategory;
  final bool showCount;
  final bool? collapsed;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

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
      collapsed: collapsed,
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }

  @override
  bool shouldRebuild(_SectionHeaderDelegate old) =>
      old.section != section ||
      old.byCategory != byCategory ||
      old.showCount != showCount ||
      old.collapsed != collapsed;
}

/// Title row shared by the continuous and paged section layouts.
class LibrarySectionHeader extends ConsumerWidget {
  const LibrarySectionHeader({
    super.key,
    required this.section,
    required this.byCategory,
    required this.showCount,
    this.collapsed,
    this.onTap,
    this.onLongPress,
  });

  static const height = 40.0;

  final LibrarySection section;
  final bool byCategory;
  final bool showCount;

  /// Null when the section cannot collapse.
  final bool? collapsed;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = showCount
        ? watchLibrarySection(ref, section, byCategory: byCategory)
              .value
              ?.length
        : null;
    final primary = context.theme.colorScheme.primary;
    return Material(
      // Opaque headers hide rows scrolling underneath.
      color: context.theme.colorScheme.surface,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          height: height,
          width: double.infinity,
          alignment: AlignmentDirectional.centerStart,
          padding: const EdgeInsets.symmetric(horizontal: 8)
              .onDesktopPageLine(context),
          child: Row(
            children: [
              if (collapsed != null) ...[
                Icon(
                  collapsed!
                      ? FluentIcons.chevron_down_24_regular
                      : FluentIcons.chevron_up_24_regular,
                  size: 20,
                  color: primary,
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  count == null ? section.name : '${section.name} ($count)',
                  overflow: TextOverflow.ellipsis,
                  style: context.theme.textTheme.titleSmall?.copyWith(
                    color: primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
