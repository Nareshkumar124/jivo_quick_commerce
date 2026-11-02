import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../domain/location_point.dart';
import '../domain/point_store.dart';

/// [PointStore] backed by a JSON-lines file: one point per line.
///
/// - [append] adds lines, so a fix costs one small write.
/// - [replaceAll] writes a temp file and renames it over the old one, so a
///   crash mid-write never leaves a half-written buffer.
/// - [load] skips lines it cannot parse (for example, a torn last line after
///   the process was killed during an append).
///
/// Only the location service isolate uses this file, so there is a single
/// writer.
class FilePointStore implements PointStore {
  FilePointStore(this.file);

  final File file;

  File get _tempFile => File('${file.path}.tmp');

  @override
  Future<List<LocationPoint>> load() async {
    if (!await file.exists()) return const [];
    final List<String> lines;
    try {
      lines = await file.readAsLines();
    } on FileSystemException catch (error) {
      debugPrint('FilePointStore: cannot read ${file.path}: $error');
      return const [];
    } on FormatException catch (error) {
      debugPrint('FilePointStore: unreadable ${file.path}: $error');
      return const [];
    }
    final points = <LocationPoint>[];
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      try {
        points.add(
          LocationPoint.fromJson(jsonDecode(line) as Map<String, dynamic>),
        );
      } on Object catch (_) {
        // Skip a corrupt line rather than losing the whole buffer.
      }
    }
    return points;
  }

  @override
  Future<void> append(List<LocationPoint> points) async {
    if (points.isEmpty) return;
    await file.parent.create(recursive: true);
    await file.writeAsString(
      _encode(points),
      mode: FileMode.append,
      flush: true,
    );
  }

  @override
  Future<void> replaceAll(List<LocationPoint> points) async {
    if (points.isEmpty) {
      if (await file.exists()) await file.delete();
      return;
    }
    await file.parent.create(recursive: true);
    final temp = _tempFile;
    await temp.writeAsString(_encode(points), flush: true);
    await temp.rename(file.path);
  }

  static String _encode(List<LocationPoint> points) {
    final buffer = StringBuffer();
    for (final point in points) {
      buffer.writeln(jsonEncode(point.toJson()));
    }
    return buffer.toString();
  }
}
