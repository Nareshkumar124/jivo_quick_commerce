import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/repositories.dart';
import '../domain/order.dart';

/// One order from the server (`GET /orders/{id}/`).
final orderProvider = FutureProvider.autoDispose.family<PlacedOrder, int>(
  (ref, id) => ref.watch(orderRepositoryProvider).getOrder(id),
);
