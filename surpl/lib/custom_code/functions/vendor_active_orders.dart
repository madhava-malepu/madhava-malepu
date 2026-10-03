
import '/backend/backend.dart';

List<OrdersRecord> vendorActiveOrders(List<OrdersRecord> orders) {
  // In a real app we'd filter by merchant_id of the logged in user
  return orders.where((o) => o.status == "Active").toList();
}
