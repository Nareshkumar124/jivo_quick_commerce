import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/onboarding_forms.dart';
import '../domain/registration_draft_store.dart';

/// [RegistrationDraftStore] in the app's private support directory (the
/// same place as the KYC pending-capture marker). Not readable by other
/// apps; holds no document numbers.
///
/// Reads, writes and clears run one at a time, in call order, so a write
/// already on disk when sign-out calls [clear] is deleted by it. A write
/// requested before a [clear] but not yet started is dropped (the clear
/// generation changed), so it can never land after the clear.
class FileRegistrationDraftStore implements RegistrationDraftStore {
  FileRegistrationDraftStore({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directory;
  int _generation = 0;
  Future<void> _queue = Future.value();

  Future<T> _serial<T>(Future<T> Function() op) {
    final result = _queue.then((_) => op());
    _queue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<File> _file() async {
    final dir = await _directory();
    return File('${dir.path}/onboarding/registration_draft.json');
  }

  @override
  Future<RegistrationDraft?> read() => _serial(() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      final json = jsonDecode(await file.readAsString());
      return json is Map<String, Object?>
          ? RegistrationDraft.fromJson(json)
          : null;
    } on Object catch (error) {
      debugPrint('FileRegistrationDraftStore.read: ${error.runtimeType}');
      return null;
    }
  });

  @override
  Future<void> write(RegistrationDraft draft) {
    final generation = _generation;
    return _serial(() async {
      if (generation != _generation) return;
      try {
        final file = await _file();
        await file.parent.create(recursive: true);
        await file.writeAsString(jsonEncode(draft.toJson()), flush: true);
      } on Object catch (error) {
        debugPrint('FileRegistrationDraftStore.write: ${error.runtimeType}');
      }
    });
  }

  @override
  Future<void> clear() {
    _generation++;
    return _serial(() async {
      try {
        final file = await _file();
        if (await file.exists()) await file.delete();
      } on Object catch (error) {
        debugPrint('FileRegistrationDraftStore.clear: ${error.runtimeType}');
      }
    });
  }
}
