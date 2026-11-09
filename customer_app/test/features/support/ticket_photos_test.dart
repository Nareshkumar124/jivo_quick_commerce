import 'dart:typed_data';

import 'package:customer_app/app/repositories.dart';
import 'package:customer_app/features/cart/data/fake_commerce_backend.dart';
import 'package:customer_app/features/support/data/support_repository.dart';
import 'package:customer_app/features/support/data/ticket_photo_picker.dart';
import 'package:customer_app/features/support/domain/support_models.dart';
import 'package:customer_app/features/support/presentation/support_controllers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../helpers/test_app.dart';
import 'photo_fixtures.dart';

/// Support ticket photos (`support_tickets_attachments_create`, then
/// `attachment_keys` on a reply; P7).
void main() {
  group('uploadTicketPhotos', () {
    test('uploads each photo once; a retry reuses the keys', () async {
      final repo = FakeSupportRepository();
      final photos = [
        PendingTicketPhoto(pngPhoto()),
        PendingTicketPhoto(pngPhoto()),
      ];
      repo.failNextUpload = const ApiError(code: ApiErrorCode.network);
      await expectLater(
        uploadTicketPhotos(repo, 1, photos),
        throwsA(isA<ApiError>()),
      );
      final keys = await uploadTicketPhotos(repo, 1, photos);
      expect(keys, hasLength(2));
      expect(repo.uploads, hasLength(2));
      // Already uploaded: nothing goes up again.
      expect(await uploadTicketPhotos(repo, 1, photos), keys);
      expect(repo.uploads, hasLength(2));
    });

    test('more than three photos are refused', () {
      expect(
        uploadTicketPhotos(FakeSupportRepository(), 1, [
          for (var i = 0; i < 4; i++) PendingTicketPhoto(pngPhoto()),
        ]),
        throwsA(isA<TicketPhotoException>()),
      );
    });
  });

  group('screens', () {
    late FakeSupportRepository support;
    late FakeTicketPhotoPicker picker;

    setUp(() {
      support = FakeSupportRepository();
      picker = FakeTicketPhotoPicker();
    });

    TestApp app() => TestApp(
      tokens: signedInTokens,
      commerce: FakeCommerceBackend(latency: Duration.zero)..seedDemoOrders(),
      extraOverrides: [
        supportAvailableProvider.overrideWithValue(true),
        supportRepositoryProvider.overrideWithValue(support),
        ticketPhotoPickerProvider.overrideWithValue(picker),
      ],
    );

    Future<void> showIn(WidgetTester tester, String list, Finder f) async {
      await tester.scrollUntilVisible(
        f,
        150,
        scrollable: find
            .descendant(
              of: find.byKey(Key(list)),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
    }

    Future<void> openHelp(WidgetTester tester) async {
      await app().pump(tester);
      await tester.tap(find.byTooltip('Account'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('account-help')),
        100,
      );
      await tester.tap(find.byKey(const Key('account-help')));
      await tester.pumpAndSettle();
    }

    Future<void> openTicket1(WidgetTester tester) async {
      await openHelp(tester);
      await tester.tap(find.byKey(const Key('help-tickets')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ticket-1')));
      await tester.pumpAndSettle();
    }

    Future<void> addReplyPhoto(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('ticket-reply-photo')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('photo-gallery')));
      await tester.pumpAndSettle();
    }

    testWidgets('reply with a photo: uploaded, sent with its key, shown in '
        'the thread', (tester) async {
      picker.queue.add(pngPhoto());
      await openTicket1(tester);
      await addReplyPhoto(tester);
      expect(picker.sources, [TicketPhotoSource.gallery]);
      expect(find.byKey(const Key('remove-photo-0')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('ticket-reply')), 'See this');
      await tester.tap(find.byKey(const Key('ticket-send')));
      await tester.pumpAndSettle();

      expect(support.uploads.single.$1, 1);
      expect(support.replyPhotoKeys.single, ['photo1']);
      expect(find.byKey(const Key('message-photo-photo1')), findsOneWidget);
      expect(find.byKey(const Key('remove-photo-0')), findsNothing);
      final thread = await support.ticket(1);
      expect(thread.messages.last.body, 'See this');
      expect(thread.messages.last.photos.single.key, 'photo1');
    });

    testWidgets('photos alone send "Photos of the issue"', (tester) async {
      picker.queue.add(pngPhoto());
      await openTicket1(tester);
      await addReplyPhoto(tester);
      await tester.tap(find.byKey(const Key('ticket-send')));
      await tester.pumpAndSettle();
      final thread = await support.ticket(1);
      expect(thread.messages.last.body, 'Photos of the issue');
      expect(thread.messages.last.photos, hasLength(1));
    });

    testWidgets('at most three photos per message; one can be removed', (
      tester,
    ) async {
      picker.queue.addAll([pngPhoto(), pngPhoto(), pngPhoto()]);
      await openTicket1(tester);
      for (var i = 0; i < 3; i++) {
        await addReplyPhoto(tester);
      }
      expect(find.byKey(const Key('remove-photo-2')), findsOneWidget);
      final add = tester.widget<IconButton>(
        find.byKey(const Key('ticket-reply-photo')),
      );
      expect(add.onPressed, isNull);

      await tester.tap(find.byKey(const Key('remove-photo-2')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('remove-photo-2')), findsNothing);
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('ticket-reply-photo')))
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('an unsupported or oversized photo is refused with a reason', (
      tester,
    ) async {
      picker.queue.addAll([
        TicketPhotoFile(
          bytes: Uint8List.fromList('GIF89a....'.codeUnits),
          filename: 'a.gif',
        ),
        TicketPhotoFile(
          bytes: Uint8List(ticketPhotoMaxBytes + 1)..setAll(0, jpegBytes),
          filename: 'big.jpg',
        ),
      ]);
      await openTicket1(tester);
      await addReplyPhoto(tester);
      expect(
        find.text(
          "This file type isn't supported. Choose a JPEG, PNG or WebP photo.",
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('remove-photo-0')), findsNothing);

      ScaffoldMessenger.of(
        tester.element(find.byKey(const Key('ticket-thread'))),
      ).clearSnackBars();
      await tester.pumpAndSettle();
      await addReplyPhoto(tester);
      expect(
        find.text('This photo is larger than 5 MB. Choose a smaller one.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('remove-photo-0')), findsNothing);
    });

    testWidgets('a picker failure (permission denied) is explained', (
      tester,
    ) async {
      picker.failNext = Exception('camera_access_denied');
      await openTicket1(tester);
      await tester.tap(find.byKey(const Key('ticket-reply-photo')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('photo-camera')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining("Couldn't open the camera or gallery."),
        findsOneWidget,
      );
    });

    testWidgets('a 413 keeps the text and photo and says the photo is too '
        'large; a retry sends it', (tester) async {
      picker.queue.add(pngPhoto());
      await openTicket1(tester);
      await addReplyPhoto(tester);
      await tester.enterText(find.byKey(const Key('ticket-reply')), 'See this');
      support.failNextUpload = const TicketPhotoException(
        TicketPhotoProblem.rejectedSize,
      );
      await tester.tap(find.byKey(const Key('ticket-send')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'This photo is too large to upload. Try a smaller photo or a '
          'screenshot of it.',
        ),
        findsOneWidget,
      );
      expect(find.text('See this'), findsOneWidget);
      expect(find.byKey(const Key('remove-photo-0')), findsOneWidget);
      expect(support.replyPhotoKeys, isEmpty);

      ScaffoldMessenger.of(
        tester.element(find.byKey(const Key('ticket-thread'))),
      ).clearSnackBars();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ticket-send')));
      await tester.pumpAndSettle();
      expect(support.replyPhotoKeys.single, hasLength(1));
      expect(support.uploads, hasLength(1));
    });

    testWidgets('new ticket with a photo: created, then the photo goes up '
        'as a second message', (tester) async {
      picker.queue.add(pngPhoto());
      await openHelp(tester);
      await tester.tap(find.byKey(const Key('help-new-ticket')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('category-ACCOUNT')));
      await tester.enterText(
        find.byKey(const Key('ticket-message')),
        'My profile photo is wrong',
      );
      await showIn(
        tester,
        'new-ticket',
        find.byKey(const Key('ticket-add-photo')),
      );
      await tester.tap(find.byKey(const Key('ticket-add-photo')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('photo-gallery')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('remove-photo-0')), findsOneWidget);

      await showIn(
        tester,
        'new-ticket',
        find.byKey(const Key('ticket-submit')),
      );
      await tester.tap(find.byKey(const Key('ticket-submit')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ticket-thread')), findsOneWidget);
      expect(
        find.text("Ticket created. We'll reply here soon."),
        findsOneWidget,
      );
      final ticketId = support.uploads.single.$1;
      final thread = await support.ticket(ticketId);
      expect(thread.messages.first.body, 'My profile photo is wrong');
      expect(thread.messages.last.body, 'Photos of the issue');
      expect(thread.messages.last.photos, hasLength(1));
    });

    testWidgets('new ticket: a failed photo still opens the ticket and says '
        'the photos were not added', (tester) async {
      picker.queue.add(pngPhoto());
      await openHelp(tester);
      await tester.tap(find.byKey(const Key('help-new-ticket')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('category-ACCOUNT')));
      await tester.enterText(
        find.byKey(const Key('ticket-message')),
        'My profile photo is wrong',
      );
      await showIn(
        tester,
        'new-ticket',
        find.byKey(const Key('ticket-add-photo')),
      );
      await tester.tap(find.byKey(const Key('ticket-add-photo')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('photo-gallery')));
      await tester.pumpAndSettle();
      support.failNextUpload = const ApiError(
        code: ApiErrorCode.validationError,
        statusCode: 413,
      );
      await showIn(
        tester,
        'new-ticket',
        find.byKey(const Key('ticket-submit')),
      );
      await tester.tap(find.byKey(const Key('ticket-submit')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ticket-thread')), findsOneWidget);
      expect(
        find.textContaining("Ticket created, but the photos weren't added."),
        findsOneWidget,
      );
      expect(
        find.textContaining('This photo is too large to upload.'),
        findsOneWidget,
      );
      expect(support.replyPhotoKeys, isEmpty);
    });
  });
}
