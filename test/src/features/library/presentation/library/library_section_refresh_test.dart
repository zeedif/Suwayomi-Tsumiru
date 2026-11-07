// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tsumiru/src/features/library/data/default_category.dart';
import 'package:tsumiru/src/features/library/presentation/library/widgets/library_sections_view.dart';
import 'package:tsumiru/src/features/manga_book/data/updates/updates_repository.dart';
import 'package:tsumiru/src/l10n/generated/app_localizations.dart';
import 'package:tsumiru/src/utils/misc/toast/toast.dart';
import 'package:tsumiru/src/widgets/shell/update_banner_state.dart';

class _Updates extends Fake implements UpdatesRepository {
  final categories = <int?>[];

  @override
  Future<void> fetchUpdates({int? categoryId}) async =>
      categories.add(categoryId);
}

class _Optimistic extends UpdateOptimistic {
  @override
  void arm() {}
}

Future<_Updates> _pumpHeader(
  WidgetTester tester, {
  required int id,
  required bool byCategory,
}) async {
  final updates = _Updates();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settledDefaultCategoryIdProvider.overrideWithValue(0),
        updatesRepositoryProvider.overrideWithValue(updates),
        updateOptimisticProvider.overrideWith(_Optimistic.new),
        toastProvider.overrideWithValue(null),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: LibrarySectionHeader(
            section: (id: id, name: 'Section'),
            byCategory: byCategory,
            showCount: false,
          ),
        ),
      ),
    ),
  );
  return updates;
}

final _refresh = find.byIcon(FluentIcons.arrow_clockwise_24_regular);

void main() {
  testWidgets('updates the category of the section', (tester) async {
    final updates = await _pumpHeader(tester, id: 4, byCategory: true);

    await tester.tap(_refresh);
    expect(updates.categories, [4]);
  });

  testWidgets('offers no update the server cannot run', (tester) async {
    await _pumpHeader(tester, id: 0, byCategory: true);
    expect(_refresh, findsNothing);

    await _pumpHeader(tester, id: 2, byCategory: false);
    expect(_refresh, findsNothing);
  });
}
