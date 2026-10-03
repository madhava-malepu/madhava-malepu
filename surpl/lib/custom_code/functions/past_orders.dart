
import '/backend/backend.dart';

List<OrdersRecord> pastOrders(List<OrdersRecord> orders) {
  return orders.where((o) => o.status == "Picked up").toList();
}
