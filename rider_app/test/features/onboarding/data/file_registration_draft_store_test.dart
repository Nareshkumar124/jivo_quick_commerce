import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/features/onboarding/data/file_registration_draft_store.dart';
import 'package:rider_app/features/onboarding/domain/onboarding_forms.dart';
import 'package:rider_app/features/onboarding/domain/vehicle_type.dart';

/// RA-07 saved registration form on disk (code review follow-up).
void main() {
  late Directory dir;
  late FileRegistrationDraftStore store;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('jqc_draft_');
    addTearDown(() => dir.delete(recursive: true));
    store = FileRegistrationDraftStore(directory: () async => dir);
    file = File('${dir.path}/onboarding/registration_draft.json');
  });

  const draft = RegistrationDraft(
    fullName: 'Ravi Kumar',
    emergencyName: 'Sunita Kumar',
    storeId: 3,
    vehicleType: VehicleType.bicycle,
  );

  test('a missing file reads as null', () async {
    expect(await store.read(), isNull);
  });

  test('write then read round-trips', () async {
    await store.write(draft);
    final back = await store.read();
    expect(back?.fullName, 'Ravi Kumar');
    expect(back?.storeId, 3);
    expect(back?.vehicleType, VehicleType.bicycle);
  });

  test('corrupt JSON reads as null, never throws', () async {
    await file.parent.create(recursive: true);
    await file.writeAsString('{"full_name": "Ravi"');
    expect(await store.read(), isNull);
  });

  test('a JSON root that is not an object reads as null', () async {
    await file.parent.create(recursive: true);
    await file.writeAsString('["Ravi"]');
    expect(await store.read(), isNull);
  });

  test('clear without a file is fine; clear deletes the file', () async {
    await store.clear();
    await store.write(draft);
    expect(file.existsSync(), isTrue);
    await store.clear();
    expect(file.existsSync(), isFalse);
  });

  test('a write requested before clear() never lands after it', () async {
    final pending = store.write(draft);
    final cleared = store.clear();
    await Future.wait([pending, cleared]);
    expect(file.existsSync(), isFalse);
    expect(await store.read(), isNull);
  });

  test('writes after a clear are saved again (a new registration)', () async {
    await store.clear();
    await store.write(draft);
    expect((await store.read())?.fullName, 'Ravi Kumar');
  });
}
