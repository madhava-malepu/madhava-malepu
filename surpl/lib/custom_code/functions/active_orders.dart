
import '/backend/backend.dart';

List<OrdersRecord> activeOrders(List<OrdersRecord> orders) {
  return orders.where((o) => o.status == "Active").toList();
}
