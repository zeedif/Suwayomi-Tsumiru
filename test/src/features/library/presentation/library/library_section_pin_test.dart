// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsumiru/src/features/library/presentation/library/widgets/library_manga_grid_view.dart';
import 'package:tsumiru/src/global_providers/global_providers.dart';

void main() {
  testWidgets('an unpinned header scrolls with the entries', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          home: Scaffold(
            body: LibraryMangaGridView(
              items: const [],
              onOpen: (_) {},
              header: const Text('Reading'),
            ),
          ),
        ),
      ),
    );

    expect(
      find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.text('Reading'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('empty pages keep the header above their message', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: withLibraryHeader(const Text('Reading'), const Text('Empty')),
        ),
      ),
    );

    expect(
      tester.getTopLeft(find.text('Reading')).dy,
      lessThan(tester.getTopLeft(find.text('Empty')).dy),
    );
    expect(withLibraryHeader(null, const Text('Empty')), isA<Text>());
  });
}
