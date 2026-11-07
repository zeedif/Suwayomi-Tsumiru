import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsumiru/src/constants/db_keys.dart';
import 'package:tsumiru/src/constants/enum.dart';
import 'package:tsumiru/src/features/library/presentation/library/controller/library_controller.dart';
import 'package:tsumiru/src/global_providers/global_providers.dart';

Future<ProviderContainer> _container(Map<String, Object> prefs) async {
  SharedPreferences.setMockInitialValues(prefs);
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(
        await SharedPreferences.getInstance(),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('tab bars and headers show always by default', () async {
    final container = await _container({});

    expect(container.read(libraryTabsModeProvider), LibraryBarMode.always);
    expect(container.read(sectionHeadersModeProvider), LibraryBarMode.always);
  });

  test('a hidden tab bar keeps hiding under the new modes', () async {
    final container = await _container({DBKeys.categoryTabs.name: false});

    expect(container.read(libraryTabsModeProvider), LibraryBarMode.never);
  });

  test('a picked mode wins over the former switch', () async {
    final container = await _container({
      DBKeys.categoryTabs.name: false,
      DBKeys.libraryTabsMode.name: LibraryBarMode.top.index,
    });

    expect(container.read(libraryTabsModeProvider), LibraryBarMode.top);
  });
}
