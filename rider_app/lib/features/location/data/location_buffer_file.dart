import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

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

/// Deletes the buffer file (and its temp file). Only call while offline: the
/// service isolate must not be running.
class FileLocationDataCleaner implements LocationDataCleaner {
  const FileLocationDataCleaner();

  @override
  Future<void> clear() async {
    try {
      final file = await locationBufferFile();
      for (final f in [file, File('${file.path}.tmp')]) {
        if (await f.exists()) await f.delete();
      }
    } on Object catch (error) {
      debugPrint('FileLocationDataCleaner: $error');
    }
  }
}
