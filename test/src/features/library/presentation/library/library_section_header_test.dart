// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tsumiru/src/features/library/presentation/library/widgets/library_sections_view.dart';

Future<void> _pumpHeader(WidgetTester tester, Widget header) =>
    tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: Scaffold(body: header)),
      ),
    );

void main() {
  const section = (id: 1, key: 'reading', name: 'Reading');

  testWidgets('toggles on tap and toggles all on long press', (tester) async {
    var taps = 0;
    var longPresses = 0;
    await _pumpHeader(
      tester,
      LibrarySectionHeader(
        section: section,
        byCategory: false,
        showCount: false,
        collapsed: true,
        onTap: () => taps++,
        onLongPress: () => longPresses++,
      ),
    );

    expect(find.byIcon(FluentIcons.chevron_down_24_regular), findsOneWidget);
    await tester.tap(find.text('Reading'));
    await tester.longPress(find.text('Reading'));
    expect((taps, longPresses), (1, 1));
  });

  testWidgets('shows no chevron when the section cannot collapse', (
    tester,
  ) async {
    await _pumpHeader(
      tester,
      const LibrarySectionHeader(
        section: section,
        byCategory: false,
        showCount: false,
      ),
    );

    expect(find.byIcon(FluentIcons.chevron_down_24_regular), findsNothing);
    expect(find.byIcon(FluentIcons.chevron_up_24_regular), findsNothing);
  });
}
