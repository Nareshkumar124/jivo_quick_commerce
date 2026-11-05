import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:jivo_api/jivo_api.dart' as api show JivoApi;
import 'package:jivo_core/jivo_core.dart';

/// A CMS page (`06 §2.7` `GET /pages/{slug}/`, Phase 7): About, Terms,
/// Privacy, Refund policy.
@immutable
class CmsPage {
  const CmsPage({
    required this.slug,
    required this.title,
    required this.html,
    this.updatedAt,
  });

  final String slug;
  final String title;

  /// Server HTML. Never rendered as-is: see `parseSafeHtml`.
  final String html;
  final DateTime? updatedAt;
}

/// The page slugs the app links to (`pages_retrieve`).
abstract final class CmsSlugs {
  static const about = 'about';
  static const terms = 'terms';
  static const privacy = 'privacy';
  static const refund = 'refund-policy';
}

/// CMS pages: [ApiCmsRepository] on the API, [FakeCmsRepository] with
/// `FAKE_API` and in tests. An unknown or unpublished slug is 404; the
/// viewer then offers the policy URL from `config/app`.
abstract interface class CmsRepository {
  /// Throws [ApiError] (`NOT_FOUND` for an unknown or unpublished slug).
  Future<CmsPage> page(String slug);
}

/// `GET /pages/{slug}/` (public). The server sanitises the HTML too; the
/// app still renders it only through `parseSafeHtml`.
class ApiCmsRepository implements CmsRepository {
  const ApiCmsRepository(this._api);

  final api.JivoApi _api;

  @override
  Future<CmsPage> page(String slug) async {
    try {
      final page = (await _api.getCmsApi().pagesRetrieve(slug: slug)).data!;
      return CmsPage(
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

class UnavailableCmsRepository implements CmsRepository {
  const UnavailableCmsRepository();

  @override
  Future<CmsPage> page(String slug) async =>
      throw const ApiError(code: ApiErrorCode.notFound, statusCode: 404);
}

/// Demo pages (`FAKE_API=true` and tests). The terms page carries markup
/// the viewer must neutralise (a script, an inline handler, a `javascript:`
/// link).
class FakeCmsRepository implements CmsRepository {
  FakeCmsRepository({Map<String, CmsPage>? pages})
    : pages = pages ?? Map.of(_demo);

  final Map<String, CmsPage> pages;

  /// When set, the next call throws it once.
  Object? failNext;

  final List<String> requests = [];

  @override
  Future<CmsPage> page(String slug) async {
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      throw failure;
    }
    requests.add(slug);
    final page = pages[slug];
    if (page == null) {
      throw const ApiError(code: ApiErrorCode.notFound, statusCode: 404);
    }
    return page;
  }

  static final _demo = {
    CmsSlugs.about: CmsPage(
      slug: CmsSlugs.about,
      title: 'About Jivo',
      updatedAt: DateTime.utc(2026, 11, 1),
      html:
          '<h1>About Jivo</h1><p>Jivo Wellness brings cold-pressed oils, '
          'ghee and wellness foods to your door in minutes.</p>'
          '<p>Questions? Write to <a href="mailto:care@jivo.in">'
          'care@jivo.in</a>.</p>',
    ),
    CmsSlugs.terms: CmsPage(
      slug: CmsSlugs.terms,
      title: 'Terms of Service',
      updatedAt: DateTime.utc(2026, 11, 1),
      html:
          '<h1>Terms of Service</h1>'
          '<script>alert("x")</script>'
          '<p onclick="steal()">By using the app you agree to these '
          '<strong>terms</strong>.</p>'
          '<h2>1. Orders</h2><ol><li>Prices are set by Jivo.</li>'
          '<li>Orders can be cancelled until packing starts.</li></ol>'
          '<h2>2. Payments</h2><ul><li>UPI, cards and <em>cash on '
          'delivery</em>.</li></ul>'
          '<p><a href="javascript:steal()">Do not follow</a> &amp; '
          '<a href="https://jivo.in/terms">read online</a>.</p>',
    ),
    CmsSlugs.privacy: const CmsPage(
      slug: CmsSlugs.privacy,
      title: 'Privacy Policy',
      html:
          '<h1>Privacy Policy</h1><p>We collect your phone number, '
          'addresses and orders to deliver to you.</p>',
    ),
    CmsSlugs.refund: const CmsPage(
      slug: CmsSlugs.refund,
      title: 'Refund Policy',
      html:
          '<h1>Refund Policy</h1><p>Refunds go back to the original '
          'payment method within 5–7 working days.</p>',
    ),
  };
}
