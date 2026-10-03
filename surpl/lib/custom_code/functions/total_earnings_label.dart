
import '/backend/backend.dart';

String totalEarningsLabel(List<OrdersRecord> orders) {
  double total = 0;
  for (final o in orders) {
    total += (o.snapshotData['amount'] as num?)?.toDouble() ?? 0;
  }
  return "₹${total.toStringAsFixed(0)}";
}
