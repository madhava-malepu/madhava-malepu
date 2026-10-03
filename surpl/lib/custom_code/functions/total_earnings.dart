
import '/backend/backend.dart';

double totalEarnings(List<OrdersRecord> orders) {
  return orders
      .where((o) => o.status == "Picked up")
      .fold(0.0, (sum, o) => sum + o.amountPaid);
}
