import 'package:jivo_api/jivo_api.dart' show AppConfig;
import 'package:rider_app/features/launch/data/fake_app_config_repository.dart';

/// The normal fake config with other `support` contacts (for example a blank
/// email, as when the server has none set).
class SupportConfigRepository extends FakeAppConfigRepository {
  SupportConfigRepository({
    this.phone = '+919910557187',
    this.email = 'info@jivo.in',
  }) : super(delay: Duration.zero);

  final String phone;
  final String email;

  @override
  Future<AppConfig> fetch() async {
    fetchCount++;
    return AppConfig.fromJson({
      ...FakeAppConfigRepository.exampleJson(scenario),
      'support': {'phone': phone, 'email': email},
    });
  }
}
