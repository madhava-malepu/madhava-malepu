
import '/backend/backend.dart';

dynamic currentBag(
  List<BagsRecord> bags,
  List<MerchantsRecord> merchants,
  String bagId,
) {
  final b = bags
      .where((b) => b.reference.id == (bagId ?? ""))
      .firstOrNull
      ?.snapshotData;
  if (b == null) return {};
  final m = merchants
      .where((m) => m.reference.id == (b['merchant_id'] ?? ""))
      .firstOrNull
      ?.snapshotData;
  return {
    "id": b['id'] ?? "",
    "title": b['title'] ?? "",
    "description": b['description'] ?? "",
    "price": b['price'] ?? 0,
    "original_price": b['original_price'] ?? 0,
    "discount_pct": b['discount_pct'] ?? 0,
    "pickup_start": b['pickup_start'] ?? "",
    "pickup_end": b['pickup_end'] ?? "",
    "image": b['image'] ?? "",
    "merchant_name": m == null ? "Merchant" : m['name'] ?? "",
    "merchant_location": m == null ? "" : m['location'] ?? "",
    "pickup_window":
        "Today, " + (b['pickup_start'] ?? "") + " - " + (b['pickup_end'] ?? "")
  };
}
