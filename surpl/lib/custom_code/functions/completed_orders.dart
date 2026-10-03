
import '/backend/backend.dart';

List<OrdersRecord> completedOrders(List<OrdersRecord> orders) {
  return orders.where((o) => o.status == "Picked up").toList();
}
