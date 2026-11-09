import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router.dart';
import '../../../app/routes.dart';

/// The screen for a backend `jivo://rider/...` link (inbox `link`, P7
/// notifications), or null for a link the app does not know (it is then
/// ignored, so the server can add links without breaking older apps):
///
/// - `jivo://rider/help/tickets/{id}`: that support ticket (a staff reply);
/// - `jivo://rider/cash`: the cash ledger (deposits, adjustments, deposit
///   required);
/// - `jivo://rider/task`: the current task (the guard sends the rider home
///   when there is none any more).
///
/// The route guard still decides: a link to a screen the build or the
/// rider's state doesn't allow lands on home.
String? routeForRiderLink(String? link) {
  final uri = Uri.tryParse(link ?? '');
  if (uri == null || uri.scheme != 'jivo' || uri.host != 'rider') return null;
  final segments = [
    for (final s in uri.pathSegments)
      if (s.isNotEmpty) s,
  ];
  switch (segments) {
    case ['help', 'tickets', final id]:
      final ticketId = int.tryParse(id);
      return ticketId == null || ticketId <= 0 ? null : Routes.ticket(ticketId);
    case ['help', 'tickets']:
      return Routes.tickets;
    case ['help']:
      return Routes.help;
    case ['cash']:
      return Routes.cash;
    case ['task']:
      return Routes.task;
    case ['rating']:
      return Routes.rating;
    default:
      return null;
  }
}

/// Opens [route] from a notification (an inbox tap or a tapped push).
/// The task screen replaces the stack (it is the only place during a task);
/// anything else is pushed so Back returns to where the rider was.
typedef RiderLinkNavigator = void Function(String route);

final riderLinkNavigatorProvider = Provider<RiderLinkNavigator>((ref) {
  return (route) {
    final router = ref.read(routerProvider);
    if (Routes.isTaskRoute(route)) {
      router.go(route);
    } else {
      router.push(route);
    }
  };
});
