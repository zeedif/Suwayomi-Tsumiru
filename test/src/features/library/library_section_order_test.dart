import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsumiru/src/constants/db_keys.dart';
import 'package:tsumiru/src/features/library/domain/library_group.dart';
import 'package:tsumiru/src/features/library/presentation/library/controller/library_grouping.dart';
import 'package:tsumiru/src/features/library/presentation/library/controller/library_section_order.dart';
import 'package:tsumiru/src/features/offline/data/server_reachability.dart';
import 'package:tsumiru/src/features/settings/presentation/downloads/data/delete_chapters_settings_repository.dart';
import 'package:tsumiru/src/global_providers/global_providers.dart';
import 'package:tsumiru/src/utils/webui_meta/webui_settings.dart';

class _NoServerMetas extends WebUiSettings {
  @override
  Future<Map<String, String>> build() async => {};
}

class _Repo extends Fake implements DeleteChaptersSettingsRepository {
  @override
  Future<void> setRawGlobalMeta(String key, String value) async {}
}

GroupedTab _tab(String key) =>
    (id: key.hashCode, key: key, name: key, mangaIds: const <int>[]);

List<String> _keys(List<GroupedTab> tabs) => [for (final t in tabs) t.key];

final _natural = [_tab('a'), _tab('b'), _tab('c'), _tab('d')];

Future<ProviderContainer> _container({
  required String stored,
  bool offline = false,
}) async {
  SharedPreferences.setMockInitialValues({
    DBKeys.libraryGroupType.name: LibraryGroup.byTag,
    kSectionOrderMetaKey: stored,
  });
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      webUiSettingsProvider.overrideWith(_NoServerMetas.new),
      deleteChaptersSettingsRepositoryProvider.overrideWithValue(_Repo()),
      libraryNaturalTabsProvider.overrideWith((ref) async => _natural),
      viewOfflineNowProvider.overrideWithValue(offline),
      serverUnreachableProvider.overrideWithValue(false),
    ],
  );
  addTearDown(container.dispose);
  container.listen(libraryGroupedTabsProvider, (_, _) {});
  await container.read(webUiSettingsProvider.future);
  return container;
}

void main() {
  group('applySectionOrder', () {
    test('leads with stored groups and keeps the rest in order', () {
      expect(_keys(applySectionOrder(_natural, ['c', 'gone', 'a'])), [
        'c',
        'a',
        'b',
        'd',
      ]);
    });
  });

  group('compactSectionOrder', () {
    final natural = ['a', 'b', 'c', 'd'];

    test('stores only the moved groups', () {
      expect(compactSectionOrder(['c', 'a', 'b', 'd'], natural), ['c']);
      expect(compactSectionOrder(['a', 'd', 'b', 'c'], natural), ['a', 'd']);
      expect(compactSectionOrder(natural, natural), isEmpty);
    });

    test('expands back to the order it was given', () {
      final ordered = ['d', 'b', 'a', 'c'];
      final stored = compactSectionOrder(ordered, natural);
      expect(
        _keys(applySectionOrder([for (final k in natural) _tab(k)], stored)),
        ordered,
      );
    });
  });

  test('saves the compact order of the active grouping', () async {
    final container = await _container(stored: '{"5":["gone"]}');

    await container.read(librarySectionOrderProvider.notifier).save([
      'b',
      'a',
      'c',
      'd',
    ]);

    expect(container.read(librarySectionOrderProvider), ['b']);
    expect(_keys(await container.read(libraryGroupedTabsProvider.future)), [
      'b',
      'a',
      'c',
      'd',
    ]);
  });

  test('keeps groups the offline library did not load', () async {
    final container = await _container(stored: '{"5":["gone"]}', offline: true);

    await container.read(librarySectionOrderProvider.notifier).save([
      'd',
      'a',
      'b',
      'c',
    ]);

    expect(container.read(librarySectionOrderProvider), ['d', 'gone']);
  });

  test('categories keep the order set in Edit categories', () async {
    SharedPreferences.setMockInitialValues({
      DBKeys.libraryGroupType.name: LibraryGroup.byDefault,
      kSectionOrderMetaKey: '{"0":["2","1"]}',
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        webUiSettingsProvider.overrideWith(_NoServerMetas.new),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(librarySectionOrderProvider), isEmpty);
  });
}
