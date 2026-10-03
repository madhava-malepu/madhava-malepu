
import '/backend/backend.dart';

dynamic currentOrder(
  List<BagsRecord> bags,
  List<MerchantsRecord> merchants,
  List<OrdersRecord> orders,
  String orderId,
) {
  final o = orders
      .where((o) => o.reference.id == (orderId ?? ""))
      .firstOrNull
      ?.snapshotData;
  if (o == null) return {};
  final b = bags
      .where((b) => b.reference.id == (o['bag_id'] ?? ""))
      .firstOrNull
      ?.snapshotData;
  final m = merchants
      .where((m) => m.reference.id == (o['merchant_id'] ?? ""))
      .firstOrNull
      ?.snapshotData;
  return {
    "pickup_code": o['pickup_code'] ?? "---",
    "merchant_name": m == null ? "Merchant" : m['name'] ?? "",
    "merchant_address": m == null ? "Location" : m['address'] ?? "",
    "pickup_window": b == null
        ? "Pickup Window"
        : ((b['pickup_start'] ?? "") + " - " + (b['pickup_end'] ?? "")),
    "lat": 12.9716,
    "lng": 77.6025
  };
}
