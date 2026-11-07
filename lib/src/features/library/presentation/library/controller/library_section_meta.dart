// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../global_providers/global_providers.dart';
import '../../../../../utils/webui_meta/webui_settings.dart';
import '../../../../offline/data/server_reachability.dart';
import '../../../../settings/presentation/downloads/data/delete_chapters_settings_repository.dart';

part 'library_section_meta.g.dart';

/// Per-group-type section state kept in the user's global meta under [key].
/// The device copy covers offline launches; a differing server value replaces it.
@riverpod
class LibrarySectionMeta extends _$LibrarySectionMeta {
  @override
  Map<String, dynamic> build(String key) {
    final prefs = ref.watch(sharedPreferencesProvider);
    ref.listen(webUiSettingsProvider, (_, metas) {
      final next = metas.value?[key];
      if (next == null || next == prefs.getString(key)) return;
      prefs.setString(key, next);
      state = _decode(next);
    });
    final current = ref.read(webUiSettingsProvider).value?[key];
    if (current != null) prefs.setString(key, current);
    return _decode(current ?? prefs.getString(key));
  }

  Map<String, dynamic> _decode(String? raw) {
    if (raw == null) return const {};
    try {
      final value = jsonDecode(raw);
      return value is Map<String, dynamic> ? value : const {};
    } on FormatException {
      return const {};
    }
  }

  void write(Map<String, dynamic> value) {
    final raw = jsonEncode(value);
    state = value;
    ref.read(sharedPreferencesProvider).setString(key, raw);
    ref.read(webUiSettingsProvider.notifier).remember(key, raw);
    ref
        .read(deleteChaptersSettingsRepositoryProvider)
        .setRawGlobalMeta(key, raw)
        .catchError((Object _) {});
  }
}

/// Loaded groups cover the whole library only while the server answers.
bool libraryGroupsComplete(Ref ref) =>
    !ref.read(viewOfflineNowProvider) && !ref.read(serverUnreachableProvider);
