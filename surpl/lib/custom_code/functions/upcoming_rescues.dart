
import '/backend/backend.dart';

List<OrdersRecord> upcomingRescues(List<OrdersRecord> orders) {
  return orders.where((o) => o.status == "Active").toList();
}
