// Host-side driver for `flutter drive`, the fallback for devices where
// `flutter test integration_test` can't attach (see README, Tests).
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();
