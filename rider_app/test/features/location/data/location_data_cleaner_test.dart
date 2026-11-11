import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/features/location/data/location_buffer_file.dart';
import 'package:rider_app/features/location/data/location_service_protocol.dart';

/// Sign-out deletes the rider's location data on the phone (the sign-out
/// hook calls this cleaner; see rider_account_controller_test). P8 security
/// audit: that includes the online service's SharedPreferences keys, not
/// only the buffer file.
void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('rider_cleaner_');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  test('deletes the buffer, its temp file and the service keys', () async {
    final buffer = File('${dir.path}/buffer.jsonl')
      ..writeAsStringSync('{"lat":28.5}\n');
    final temp = File('${buffer.path}.tmp')..writeAsStringSync('x');
    final removed = <String>[];

    await FileLocationDataCleaner(
      bufferFile: () async => buffer,
      clearServiceSettings: () => LocationTaskSettings.clearStored(
        remove: ({required key}) async {
          removed.add(key);
          return true;
        },
      ),
    ).clear();

    expect(buffer.existsSync(), isFalse);
    expect(temp.existsSync(), isFalse);
    expect(removed, ['rider.location.settings', 'rider.location.server_stop']);
  });

  test('the keys go even when the buffer cannot be found', () async {
    var cleared = 0;
    await FileLocationDataCleaner(
      bufferFile: () async => throw const FileSystemException('no dir'),
      clearServiceSettings: () async => cleared++,
    ).clear();
    expect(cleared, 1);
  });
}
