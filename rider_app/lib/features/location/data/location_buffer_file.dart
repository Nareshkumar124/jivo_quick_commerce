import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'location_service_protocol.dart';

/// The offline location buffer file. The location service isolate is its
/// only writer while the rider is online; logout deletes it.
Future<File> locationBufferFile() async {
  final dir = await getApplicationSupportDirectory();
  return File('${dir.path}/location/buffer.jsonl');
}

/// Deletes rider location data kept on the device.
abstract interface class LocationDataCleaner {
  Future<void> clear();
}

/// Deletes the buffer file (and its temp file) and the online service's
/// SharedPreferences keys (its settings and the "set offline" marker). Only
/// call while offline: the service isolate must not be running.
///
/// [bufferFile] and [clearServiceSettings] are replaced in tests.
class FileLocationDataCleaner implements LocationDataCleaner {
  const FileLocationDataCleaner({
    this.bufferFile = locationBufferFile,
    this.clearServiceSettings = LocationTaskSettings.clearStored,
  });

  final Future<File> Function() bufferFile;
  final Future<void> Function() clearServiceSettings;

  @override
  Future<void> clear() async {
    try {
      final file = await bufferFile();
      for (final f in [file, File('${file.path}.tmp')]) {
        if (await f.exists()) await f.delete();
      }
    } on Object catch (error) {
      debugPrint('FileLocationDataCleaner: $error');
    }
    // Separately, so a file error never leaves the keys behind.
    try {
      await clearServiceSettings();
    } on Object catch (error) {
      debugPrint('FileLocationDataCleaner: settings: $error');
    }
  }
}
