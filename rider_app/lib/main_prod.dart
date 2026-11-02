import 'package:jivo_core/jivo_core.dart';

import 'app/bootstrap.dart';

/// Entry point for the `prod` flavor:
/// `flutter run --flavor prod -t lib/main_prod.dart`
Future<void> main() => bootstrap(Flavor.prod);
