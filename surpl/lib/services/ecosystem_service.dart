import 'package:cloud_firestore/cloud_firestore.dart';

/// Foundation for Surpl's food-lifecycle data layer.
///
/// Design rule: current customer/vendor flows must keep working even if this
/// analytics layer fails. Every public method is therefore best-effort and
/// idempotent where possible.
class EcosystemService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Called when a new listing is created. Creates one lifecycle lot per bag
  /// listing, using the bag id as the lot id so retries cannot create duplicates.
  static Future<void> registerSurplusListing({
    required String bagId,
    required String vendorId,
    required String city,
    required String category,
    required String foodType,
    required int quantity,
    required double retailValuePerUnit,
    required double recoveryPricePerUnit,
    required int pickupEndMillis,
  }) async {
    if (bagId.isEmpty || vendorId.isEmpty || quantity <= 0) return;
    try {
      await _db.collection('inventoryLots').doc(bagId).set({
        'vendorId': vendorId,
        'bagId': bagId,
        'city': city,
        'category': category,
        'foodType': foodType,
        'source': 'surpl_listing',
        'initialQuantity': quantity,
        'remainingQuantity': quantity,
        'retailValuePerUnit': retailValuePerUnit,
        'recoveryPricePerUnit': recoveryPricePerUnit,
        'status': 'open',
        'createdAtMillis': DateTime.now().millisecondsSinceEpoch,
        'pickupEndMillis': pickupEndMillis,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Analytics/infrastructure must never block a vendor from listing food.
    }
  }

  /// Converts confirmed orders into immutable recovery events and decrements
  /// the related inventory lot. Uses order id as event id for idempotency.
  static Future<void> recordConfirmedOrders(List<String> orderIds) async {
    for (final orderId in orderIds.toSet()) {
      if (orderId.isEmpty) continue;
      try {
        final orderRef = _db.collection('orders').doc(orderId);
        final orderSnap = await orderRef.get();
        final order = orderSnap.data();
        if (order == null || order['status'] != 'confirmed') continue;

        final bagId = order['bagId'] as String? ?? '';
        final vendorId = order['merchantId'] as String? ?? '';
        final quantity = (order['quantity'] as num?)?.toInt() ?? 1;
        final originalPrice = (order['originalPrice'] as num?)?.toDouble() ?? 0.0;
        final amountPaid = (order['amountPaid'] as num?)?.toDouble() ?? 0.0;
        final vendorPayout = (order['vendorPayout'] as num?)?.toDouble() ?? 0.0;
        final surplRevenue = (order['surplRevenue'] as num?)?.toDouble() ?? 0.0;

        final eventRef = _db.collection('recoveryEvents').doc(orderId);
        await _db.runTransaction((tx) async {
          // Firestore transactions require every read to happen before the
          // first write. Read both possible documents up front.
          final existing = await tx.get(eventRef);
          if (existing.exists) return;

          final lotRef = bagId.isEmpty
              ? null
              : _db.collection('inventoryLots').doc(bagId);
          final lotSnap = lotRef == null ? null : await tx.get(lotRef);

          tx.set(eventRef, {
            'vendorId': vendorId,
            'customerId': order['customerId'] as String? ?? '',
            'bagId': bagId,
            'orderId': orderId,
            'inventoryLotId': bagId,
            'city': order['city'] as String? ?? '',
            'route': 'surpl_sale',
            'quantity': quantity,
            'retailValue': originalPrice * quantity,
            'recoveredValue': amountPaid,
            'vendorPayout': vendorPayout,
            'surplRevenue': surplRevenue,
            'createdAtMillis': DateTime.now().millisecondsSinceEpoch,
            'createdAt': FieldValue.serverTimestamp(),
          });

          if (lotRef != null && lotSnap != null && lotSnap.exists) {
            final data = lotSnap.data() as Map<String, dynamic>? ?? const {};
            final remaining = (data['remainingQuantity'] as num?)?.toInt() ?? 0;
            final next = (remaining - quantity).clamp(0, 1 << 30).toInt();
            tx.update(lotRef, {
              'remainingQuantity': next,
              'status': next == 0 ? 'recovered' : 'open',
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        });
      } catch (_) {
        // Best-effort only. A later server reconciliation job can backfill.
      }
    }
  }

  /// Records food that ultimately was not sold. This is intentionally not wired
  /// into the UI yet: waste data should only be collected when Surpl can do so
  /// without making vendors maintain another complicated system.
  static Future<void> recordWaste({
    required String vendorId,
    required String city,
    required int quantity,
    required double retailValue,
    String inventoryLotId = '',
    String reason = 'unknown',
  }) async {
    if (vendorId.isEmpty || quantity <= 0) return;
    await _db.collection('recoveryEvents').add({
      'vendorId': vendorId,
      'inventoryLotId': inventoryLotId,
      'city': city,
      'route': 'waste',
      'reason': reason,
      'quantity': quantity,
      'retailValue': retailValue,
      'recoveredValue': 0.0,
      'createdAtMillis': DateTime.now().millisecondsSinceEpoch,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Lightweight summary for future vendor/admin dashboards.
  static Future<Map<String, num>> vendorRecoverySummary(String vendorId) async {
    final result = <String, num>{
      'unitsRecovered': 0,
      'retailValueRecovered': 0,
      'cashRecovered': 0,
      'vendorPayout': 0,
      'surplRevenue': 0,
    };
    if (vendorId.isEmpty) return result;
    try {
      final snap = await _db.collection('recoveryEvents')
          .where('vendorId', isEqualTo: vendorId)
          .where('route', isEqualTo: 'surpl_sale')
          .get();
      for (final doc in snap.docs) {
        final d = doc.data();
        result['unitsRecovered'] = result['unitsRecovered']! + ((d['quantity'] as num?) ?? 0);
        result['retailValueRecovered'] = result['retailValueRecovered']! + ((d['retailValue'] as num?) ?? 0);
        result['cashRecovered'] = result['cashRecovered']! + ((d['recoveredValue'] as num?) ?? 0);
        result['vendorPayout'] = result['vendorPayout']! + ((d['vendorPayout'] as num?) ?? 0);
        result['surplRevenue'] = result['surplRevenue']! + ((d['surplRevenue'] as num?) ?? 0);
      }
    } catch (_) {}
    return result;
  }
}
