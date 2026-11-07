import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsumiru/src/features/library/presentation/library/controller/library_section_meta.dart';
import 'package:tsumiru/src/features/settings/presentation/downloads/data/delete_chapters_settings_repository.dart';
import 'package:tsumiru/src/global_providers/global_providers.dart';
import 'package:tsumiru/src/utils/webui_meta/webui_settings.dart';

const _key = 'tsumiru_test_sections';

class _ServerMetas extends WebUiSettings {
  _ServerMetas(this.metas);

  final Map<String, String> metas;

  @override
  Future<Map<String, String>> build() async => metas;
}

class _Repo extends Fake implements DeleteChaptersSettingsRepository {
  final writes = <String, String>{};

  @override
  Future<void> setRawGlobalMeta(String key, String value) async =>
      writes[key] = value;
}

Future<ProviderContainer> _container(
  Map<String, Object> local,
  Map<String, String> server,
  _Repo repo,
) async {
  SharedPreferences.setMockInitialValues(local);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      webUiSettingsProvider.overrideWith(() => _ServerMetas(server)),
      deleteChaptersSettingsRepositoryProvider.overrideWithValue(repo),
    ],
  );
  addTearDown(container.dispose);
  await container.read(webUiSettingsProvider.future);
  return container;
}

void main() {
  test('falls back to the device copy without a server value', () async {
    final container = await _container(
      {_key: '{"2":["ONGOING"]}'},
      {},
      _Repo(),
    );

    expect(container.read(librarySectionMetaProvider(_key)), {
      '2': ['ONGOING'],
    });
  });

  test('adopts the server value over the device copy', () async {
    final container = await _container(
      {_key: '{"2":["ONGOING"]}'},
      {_key: '{"3":["reading"]}'},
      _Repo(),
    );

    expect(container.read(librarySectionMetaProvider(_key)), {
      '3': ['reading'],
    });
    expect(
      container.read(sharedPreferencesProvider).getString(_key),
      '{"3":["reading"]}',
    );
  });

  test('keeps a written value across rebuilds', () async {
    final repo = _Repo();
    final container = await _container({}, {_key: '{"3":[]}'}, repo);
    final sub = container.listen(librarySectionMetaProvider(_key), (_, _) {});

    container.read(librarySectionMetaProvider(_key).notifier).write({
      '3': ['dropped'],
    });
    sub.close();
    await container.pump();

    expect(container.read(librarySectionMetaProvider(_key)), {
      '3': ['dropped'],
    });
    expect(repo.writes, {_key: '{"3":["dropped"]}'});
  });
}
