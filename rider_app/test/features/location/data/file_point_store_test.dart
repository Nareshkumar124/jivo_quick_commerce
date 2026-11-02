import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/features/location/data/file_point_store.dart';
import 'package:rider_app/features/location/domain/location_buffer.dart';

import '../../../helpers/location_fakes.dart';

void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('rider_points_');
    file = File('${dir.path}/location/buffer.jsonl');
  });

  tearDown(() => dir.delete(recursive: true));

  test('missing file loads as empty', () async {
    expect(await FilePointStore(file).load(), isEmpty);
  });

  test('append then load returns points in order', () async {
    final store = FilePointStore(file);
    await store.append([pointN(0), pointN(1)]);
    await store.append([pointN(2)]);

    expect(await FilePointStore(file).load(), [
      pointN(0),
      pointN(1),
      pointN(2),
    ]);
  });

  test('replaceAll swaps the content; empty deletes the file', () async {
    final store = FilePointStore(file);
    await store.append([pointN(0), pointN(1)]);

    await store.replaceAll([pointN(5)]);
    expect(await store.load(), [pointN(5)]);
    expect(File('${file.path}.tmp').existsSync(), isFalse);

    await store.replaceAll([]);
    expect(file.existsSync(), isFalse);
  });

  test('skips a torn last line left by a crash mid-append', () async {
    final store = FilePointStore(file);
    await store.append([pointN(0), pointN(1)]);
    await file.writeAsString('{"lat": 28.6, "lng"', mode: FileMode.append);

    expect(await store.load(), [pointN(0), pointN(1)]);
  });

  test('a buffer survives a restart (service killed while offline)', () async {
    final first = LocationBuffer(store: FilePointStore(file), maxPoints: 100);
    for (var i = 0; i < 3; i++) {
      await first.add(pointN(i));
    }
    await first.acknowledge(first.peekBatch(1)!);
    await first.settle();

    final second = LocationBuffer(store: FilePointStore(file), maxPoints: 100);
    await second.restore();

    expect(second.points, [pointN(1), pointN(2)]);
  });
}
