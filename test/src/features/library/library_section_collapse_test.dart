import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsumiru/src/constants/db_keys.dart';
import 'package:tsumiru/src/features/library/domain/library_group.dart';
import 'package:tsumiru/src/features/library/presentation/library/controller/library_grouping.dart';
import 'package:tsumiru/src/features/library/presentation/library/controller/library_section_collapse.dart';
import 'package:tsumiru/src/features/offline/data/server_reachability.dart';
import 'package:tsumiru/src/features/settings/presentation/downloads/data/delete_chapters_settings_repository.dart';
import 'package:tsumiru/src/global_providers/global_providers.dart';
import 'package:tsumiru/src/utils/webui_meta/webui_settings.dart';

class _NoServerMetas extends WebUiSettings {
  @override
  Future<Map<String, String>> build() async => {};
}

class _Repo extends Fake implements DeleteChaptersSettingsRepository {
  final writes = <String, String>{};

  @override
  Future<void> setRawGlobalMeta(String key, String value) async =>
      writes[key] = value;
}

GroupedTab _tab(int id, String key) =>
    (id: id, key: key, name: key, mangaIds: const <int>[]);

Future<ProviderContainer> _container(
  _Repo repo, {
  required List<GroupedTab> tabs,
  bool offline = false,
}) async {
  SharedPreferences.setMockInitialValues({
    DBKeys.libraryGroupType.name: LibraryGroup.byStatus,
    kCollapsedSectionsMetaKey: '{"2":["CANCELLED"],"3":["dropped"]}',
  });
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      webUiSettingsProvider.overrideWith(_NoServerMetas.new),
      deleteChaptersSettingsRepositoryProvider.overrideWithValue(repo),
      libraryGroupedTabsProvider.overrideWith((ref) async => tabs),
      viewOfflineNowProvider.overrideWithValue(offline),
      serverUnreachableProvider.overrideWithValue(false),
    ],
  );
  addTearDown(container.dispose);
  container.listen(libraryCollapsedSectionsProvider, (_, _) {});
  await container.read(webUiSettingsProvider.future);
  await container.read(libraryGroupedTabsProvider.future);
  return container;
}

void main() {
  final tabs = [_tab(1, 'ONGOING'), _tab(2, 'COMPLETED')];

  test('reads the collapsed keys of the active grouping', () async {
    final container = await _container(_Repo(), tabs: tabs);

    expect(container.read(libraryCollapsedSectionsProvider), {'CANCELLED'});
  });

  test('drops keys of groups that left the library', () async {
    final repo = _Repo();
    final container = await _container(repo, tabs: tabs);

    container.read(libraryCollapsedSectionsProvider.notifier).toggle('ONGOING');

    expect(container.read(libraryCollapsedSectionsProvider), {'ONGOING'});
    expect(
      repo.writes[kCollapsedSectionsMetaKey],
      '{"2":["ONGOING"],"3":["dropped"]}',
    );
  });

  test('keeps keys of missing groups while offline', () async {
    final container = await _container(_Repo(), tabs: tabs, offline: true);

    container.read(libraryCollapsedSectionsProvider.notifier).toggle('ONGOING');

    expect(container.read(libraryCollapsedSectionsProvider), {
      'CANCELLED',
      'ONGOING',
    });
  });

  test('collapses every section, then expands them all', () async {
    final container = await _container(_Repo(), tabs: tabs);
    final notifier = container.read(libraryCollapsedSectionsProvider.notifier);
    final keys = tabs.map((tab) => tab.key);

    notifier.toggleAll(keys);
    expect(container.read(libraryCollapsedSectionsProvider), {
      'ONGOING',
      'COMPLETED',
    });

    notifier.toggleAll(keys);
    expect(container.read(libraryCollapsedSectionsProvider), isEmpty);
  });
}
