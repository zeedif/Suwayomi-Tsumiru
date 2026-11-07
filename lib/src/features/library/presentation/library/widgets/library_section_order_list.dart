// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../utils/extensions/custom_extensions.dart';
import '../controller/library_grouping.dart';
import '../controller/library_section_order.dart';

/// Drags the groups of the active grouping into the order sections follow.
class LibrarySectionOrderList extends HookConsumerWidget {
  const LibrarySectionOrderList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stored = ref.watch(librarySectionOrderProvider);
    final tabs = ref.watch(libraryGroupedTabsProvider).value ?? const [];
    final names = {for (final tab in tabs) tab.key: tab.name};
    // Saving waits for the groups, so show the dragged order meanwhile.
    final dragged = useState<List<String>?>(null);
    useEffect(() {
      dragged.value = null;
      return null;
    }, [tabs]);
    final keys = [
      for (final key in dragged.value ?? names.keys)
        if (names.containsKey(key)) key,
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ReorderableListView(
          // The organizer's outer ListView owns scrolling.
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          onReorderItem: (oldIndex, newIndex) {
            // newIndex already accounts for the removal.
            final next = [...keys];
            next.insert(newIndex, next.removeAt(oldIndex));
            dragged.value = next;
            ref.read(librarySectionOrderProvider.notifier).save(next);
          },
          children: [
            for (var i = 0; i < keys.length; i++)
              Padding(
                key: ValueKey(keys[i]),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    ReorderableDragStartListener(
                      index: i,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                        child: Icon(FluentIcons.re_order_24_regular),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        names[keys[i]]!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextButton(
              onPressed: stored.isEmpty
                  ? null
                  : () {
                      dragged.value = null;
                      ref.read(librarySectionOrderProvider.notifier).reset();
                    },
              child: Text(context.l10n.reset),
            ),
          ),
        ),
      ],
    );
  }
}
