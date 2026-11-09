import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:jivo_api/jivo_api.dart' as api show JivoApi;
import 'package:jivo_core/jivo_core.dart';

/// A CMS page (06 §2.7 `GET /pages/{slug}/`, public).
@immutable
class LegalPage {
  const LegalPage({
    required this.slug,
    required this.title,
    required this.html,
    this.updatedAt,
  });

  final String slug;
  final String title;

  /// Server HTML. Shown only through `parseSafeHtml`, never a web view.
  final String html;
  final DateTime? updatedAt;
}

/// The legal pages the rider app shows (04 §2.9, P7).
///
/// `privacy` is one of the server's seeded slugs. `rider-agreement` and
/// `rider-location-disclosure` are not seeded yet (TODO(api): api-requests,
/// P7 rider report); the server serves any published slug, so they appear
/// once ops publish them. Until then the agreement shows "not published
/// yet" and the disclosure falls back to the app's own disclosure text.
enum LegalSlug {
  riderAgreement('rider-agreement'),
  privacy('privacy'),
  locationDisclosure('rider-location-disclosure');

  const LegalSlug(this.slug);

  final String slug;

  static LegalSlug? fromSlug(String? slug) {
    for (final value in values) {
      if (value.slug == slug) return value;
    }
    return null;
  }
}

/// Throws [ApiError] (`NOT_FOUND` for an unknown or unpublished slug).
abstract interface class LegalRepository {
  Future<LegalPage> page(String slug);
}

class ApiLegalRepository implements LegalRepository {
  const ApiLegalRepository(this._api);

  final api.JivoApi _api;

  @override
  Future<LegalPage> page(String slug) async {
    try {
      final page = (await _api.getCmsApi().pagesRetrieve(slug: slug)).data!;
      return LegalPage(
        slug: page.slug,
        title: page.title,
        html: page.html,
        updatedAt: page.updatedAt,
      );
    } on DioException catch (e) {
      throw ApiError.fromDioException(e);
    }
  }
}

/// Demo pages (`FAKE_API` builds and tests). The agreement carries markup
/// the viewer must neutralise (a script and a `javascript:` link); the
/// disclosure page is missing, as on a fresh server.
class FakeLegalBackend implements LegalRepository {
  FakeLegalBackend({Map<String, LegalPage>? pages})
    : pages = pages ?? Map.of(_demo);

  final Map<String, LegalPage> pages;
  final List<String> requests = [];

  /// When set, the next call throws it once.
  ApiError? failNext;

  @override
  Future<LegalPage> page(String slug) async {
    requests.add(slug);
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      throw failure;
    }
    final page = pages[slug];
    if (page == null) {
      throw const ApiError(code: ApiErrorCode.notFound, statusCode: 404);
    }
    return page;
  }

  static final _demo = {
    LegalSlug.riderAgreement.slug: LegalPage(
      slug: LegalSlug.riderAgreement.slug,
      title: 'Rider agreement',
      updatedAt: DateTime.utc(2026, 11, 1),
      html:
          '<h1>Rider agreement</h1>'
          '<script>alert("x")</script>'
          '<p>Placeholder; legal text pending.</p>'
          '<h2>1. Deliveries</h2><ol><li>Accept only orders you can '
          'deliver.</li><li>Hand over the order only with the delivery '
          'OTP.</li></ol>'
          '<p><a href="javascript:steal()">Do not follow</a> or '
          '<a href="https://jivo.in/terms">read online</a>.</p>',
    ),
    LegalSlug.privacy.slug: const LegalPage(
      slug: 'privacy',
      title: 'Privacy Policy',
      html:
          '<h1>Privacy Policy</h1><p>Placeholder; legal text pending.</p>'
          '<p>Your location is collected only while you are online.</p>',
    ),
  };
}
