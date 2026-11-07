// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsumiru/src/constants/db_keys.dart';
import 'package:tsumiru/src/features/library/domain/library_group.dart';
import 'package:tsumiru/src/features/library/presentation/library/controller/library_grouping.dart';
import 'package:tsumiru/src/features/library/presentation/library/controller/library_section_order.dart';
import 'package:tsumiru/src/features/library/presentation/library/widgets/library_section_order_list.dart';
import 'package:tsumiru/src/global_providers/global_providers.dart';
import 'package:tsumiru/src/l10n/generated/app_localizations.dart';
import 'package:tsumiru/src/utils/webui_meta/webui_settings.dart';

class _NoServerMetas extends WebUiSettings {
  @override
  Future<Map<String, String>> build() async => {};
}

Future<void> _pump(WidgetTester tester, String stored) async {
  SharedPreferences.setMockInitialValues({
    DBKeys.libraryGroupType.name: LibraryGroup.byTrackStatus,
    kSectionOrderMetaKey: stored,
  });
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        webUiSettingsProvider.overrideWith(_NoServerMetas.new),
        libraryNaturalTabsProvider.overrideWith(
          (ref) async => [
            for (final key in ['reading', 'planToRead', 'dropped'])
              (id: key.length, key: key, name: key, mangaIds: const <int>[]),
          ],
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: SingleChildScrollView(child: LibrarySectionOrderList()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists groups in their arranged order', (tester) async {
    await _pump(tester, '{"3":["dropped"]}');

    final tops = [
      for (final name in ['dropped', 'reading', 'planToRead'])
        tester.getTopLeft(find.text(name)).dy,
    ];
    expect(tops, orderedEquals([...tops]..sort()));
    expect(
      tester.widget<TextButton>(find.byType(TextButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('offers no reset for the built-in order', (tester) async {
    await _pump(tester, '{}');

    expect(
      tester.widget<TextButton>(find.byType(TextButton)).onPressed,
      isNull,
    );
  });
}
