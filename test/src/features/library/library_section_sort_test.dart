import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsumiru/src/constants/db_keys.dart';
import 'package:tsumiru/src/constants/enum.dart';
import 'package:tsumiru/src/features/library/domain/library_group.dart';
import 'package:tsumiru/src/features/library/presentation/library/controller/category_library_options.dart';
import 'package:tsumiru/src/features/library/presentation/library/controller/library_controller.dart';
import 'package:tsumiru/src/features/library/presentation/library/controller/library_grouping.dart';
import 'package:tsumiru/src/features/library/presentation/library/controller/library_section_sort.dart';
import 'package:tsumiru/src/features/offline/data/server_reachability.dart';
import 'package:tsumiru/src/features/settings/presentation/downloads/data/delete_chapters_settings_repository.dart';
import 'package:tsumiru/src/features/tracking/data/tracker_repository.dart';
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

final _tabs = [_tab(1, 'reading'), _tab(3, 'planToRead')];

Future<ProviderContainer> _container(_Repo repo) async {
  SharedPreferences.setMockInitialValues({
    DBKeys.libraryGroupType.name: LibraryGroup.byTrackStatus,
    DBKeys.mangaSort.name: MangaSort.alphabetical.index,
    DBKeys.mangaSortDirection.name: true,
    kSectionSortsMetaKey:
        '{"0":{"7":{"sort":"unread","ascending":true}},'
        '"3":{"reading":{"sort":"lastRead","ascending":false},'
        '"gone":{"sort":"rating","ascending":true}}}',
  });
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      webUiSettingsProvider.overrideWith(_NoServerMetas.new),
      deleteChaptersSettingsRepositoryProvider.overrideWithValue(repo),
      libraryGroupedTabsProvider.overrideWith((ref) async => _tabs),
      loggedInTrackersProvider.overrideWithValue(const AsyncData([])),
      viewOfflineNowProvider.overrideWithValue(false),
      serverUnreachableProvider.overrideWithValue(false),
    ],
  );
  addTearDown(container.dispose);
  container.listen(librarySectionSortsProvider, (_, _) {});
  await container.read(webUiSettingsProvider.future);
  await container.read(libraryGroupedTabsProvider.future);
  return container;
}

LibrarySectionSortProvider _section(GroupedTab tab) =>
    librarySectionSortProvider(id: tab.id, key: tab.key, byCategory: false);

void main() {
  test('sections without their own sort follow the library sort', () async {
    final container = await _container(_Repo());

    expect(container.read(_section(_tabs[0])), (
      sort: MangaSort.lastRead,
      ascending: false,
    ));
    expect(container.read(_section(_tabs[1])), (
      sort: MangaSort.alphabetical,
      ascending: true,
    ));
  });

  test('a header keeps its sort to its section', () async {
    final repo = _Repo();
    final container = await _container(repo);

    container
        .read(_section(_tabs[1]).notifier)
        .update(sort: MangaSort.dateAdded);

    expect(container.read(_section(_tabs[1])).sort, MangaSort.dateAdded);
    expect(container.read(_section(_tabs[0])).sort, MangaSort.lastRead);
    expect(container.read(libraryMangaSortProvider), MangaSort.alphabetical);
    expect(
      repo.writes[kSectionSortsMetaKey],
      '{"0":{"7":{"sort":"unread","ascending":true}},'
      '"3":{"reading":{"sort":"lastRead","ascending":false},'
      '"planToRead":{"sort":"dateAdded","ascending":true}}}',
    );
  });

  test('the library sort applies to every section again', () async {
    final container = await _container(_Repo());

    container
        .read(activeLibraryOptionsProvider.notifier)
        .sort(MangaSort.unread);

    expect(container.read(libraryMangaSortProvider), MangaSort.unread);
    for (final tab in _tabs) {
      expect(container.read(_section(tab)).sort, MangaSort.unread);
    }
  });

  test(
    'categories keep their own sort without per-category settings',
    () async {
      final container = await _container(_Repo());
      container
          .read(libraryGroupTypeProvider.notifier)
          .update(LibraryGroup.byDefault);

      expect(
        container.read(
          librarySectionSortProvider(id: 7, key: '7', byCategory: true),
        ),
        (sort: MangaSort.unread, ascending: true),
      );
    },
  );
}
