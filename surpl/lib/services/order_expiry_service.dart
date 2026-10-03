import 'package:cloud_firestore/cloud_firestore.dart';

/// Checks and expires orders whose pickup window has passed.
/// Call this from MyOrders and VendorDashboard on load — cheap, client-side,
/// no Cloud Functions cost. Runs a lightweight query each time.
class OrderExpiryService {
  /// Expires orders for a single bag (call when viewing a bag).
  /// Pass merchantId when known (e.g. from the vendor dashboard) — the
  /// underlying query needs it as an explicit filter for security rules
  /// to verify the query itself, not just individual document reads.
  static Future<void> expireForBag(String bagId, {String? merchantId}) async {
    await _expireOrders(bagFilter: bagId, merchantFilter: merchantId);
  }

  /// Expires all relevant orders for a customer (call from MyOrders).
  static Future<void> expireForCustomer(String customerId) async {
    await _expireOrders(customerFilter: customerId);
  }

  /// Expires all relevant orders for a merchant (call from VendorDashboard).
  static Future<void> expireForMerchant(String merchantId) async {
    await _expireOrders(merchantFilter: merchantId);
  }

  static Future<void> _expireOrders({
    String? bagFilter,
    String? customerFilter,
    String? merchantFilter,
  }) async {
    try {
      final db = FirebaseFirestore.instance;
      final now = DateTime.now().millisecondsSinceEpoch;

      Query query = db.collection('orders').where(
        'status', whereIn: ['pending', 'confirmed']);

      if (customerFilter != null) {
        query = query.where('customerId', isEqualTo: customerFilter);
      }
      if (merchantFilter != null) {
        query = query.where('merchantId', isEqualTo: merchantFilter);
      }
      if (bagFilter != null) {
        query = query.where('bagId', isEqualTo: bagFilter);
      }

      final snap = await query.get();
      if (snap.docs.isEmpty) {
        return;
      }

      // Cache bag pickup-end times to avoid repeat reads
      final bagCache = <String, int>{};

      for (final doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final bagId = data['bagId'] as String? ?? '';
        final status = data['status'] as String? ?? '';
        if (bagId.isEmpty) continue;

        int? pickupEndMillis = bagCache[bagId];
        if (pickupEndMillis == null) {
          try {
            final bagDoc = await db.collection('bags').doc(bagId).get();
            pickupEndMillis =
                (bagDoc.data()?['pickupEndMillis'] as num?)?.toInt() ?? 0;
            bagCache[bagId] = pickupEndMillis;
          } catch (_) {
            continue;
          }
        }

        // No expiry time set (old listings) — skip
        if (pickupEndMillis == 0) continue;

        // Pickup window hasn't ended yet
        if (now <= pickupEndMillis) continue;

        if (status == 'pending') {
          // Payment was never completed — cancel and restore quantity
          final qty = (data['quantity'] as num?)?.toInt() ?? 1;
          await doc.reference.update({
            'status': 'cancelled',
            'cancelReason': 'expired_unpaid',
          });
          try {
            await db.collection('bags').doc(bagId).update({
              'availableQuantity': FieldValue.increment(qty),
            });
          } catch (_) {}
        } else if (status == 'confirmed') {
          // Paid but never picked up — vendor keeps the sale, no refund.
          // This is the customer's responsibility for missing pickup.
          // Note: the pickupWindowReminders Cloud Function also handles
          // this server-side every 5 minutes now - this client-side path
          // remains only as a same-session fallback if that's ever delayed.
          await doc.reference.update({
            'status': 'missed',
            'missedReason': 'pickup_window_expired',
          });
        }
      }
    } catch (_) {
      // Fail silently — this is a best-effort background check
    }
  }
}