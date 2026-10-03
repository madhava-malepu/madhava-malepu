// lib/services/streak_service.dart
// Checks if customer has ordered 3+ times in last 7 days
// Awards ₹10 wallet credit automatically

import 'package:cloud_firestore/cloud_firestore.dart';

class StreakService {
  static Future<void> checkAndAwardStreak(String userId) async {
    try {
      // Get orders from last 7 days
      final sevenDaysAgo = DateTime.now()
          .subtract(const Duration(days: 7))
          .millisecondsSinceEpoch ~/ 1000;

      final orders = await FirebaseFirestore.instance
          .collection('orders')
          .where('customerId', isEqualTo: userId)
          .where('status', isEqualTo: 'confirmed')
          .where('timestamp', isGreaterThan: sevenDaysAgo)
          .get();

      if (orders.docs.length >= 3) {
        // Check if already rewarded this week
        final userDoc = await FirebaseFirestore.instance
            .collection('users').doc(userId).get();
        final lastStreakReward = userDoc.data()?['lastStreakReward'] as int? ?? 0;
        final lastRewardDate =
            DateTime.fromMillisecondsSinceEpoch(lastStreakReward * 1000);
        final daysSinceReward =
            DateTime.now().difference(lastRewardDate).inDays;

        if (daysSinceReward >= 7) {
          // Award ₹10 wallet credit
          final batch = FirebaseFirestore.instance.batch();

          batch.update(
            FirebaseFirestore.instance.collection('users').doc(userId),
            {
              'walletBalance': FieldValue.increment(10),
              'lastStreakReward':
                  DateTime.now().millisecondsSinceEpoch ~/ 1000,
            });

          final txRef = FirebaseFirestore.instance
              .collection('wallet_transactions').doc();
          batch.set(txRef, {
            'userId': userId,
            'type': 'credit',
            'amount': 10,
            'note': '🔥 Weekly streak reward — 3 bags this week!',
            'createdAt': FieldValue.serverTimestamp(),
          });

          await batch.commit();
        }
      }
    } catch (e) {
      // Silent fail — streak reward is a bonus, not critical
    }
  }

  static Future<int> getWeeklyOrderCount(String userId) async {
    try {
      final sevenDaysAgo = DateTime.now()
          .subtract(const Duration(days: 7))
          .millisecondsSinceEpoch ~/ 1000;
      final orders = await FirebaseFirestore.instance
          .collection('orders')
          .where('customerId', isEqualTo: userId)
          .where('status', isEqualTo: 'confirmed')
          .where('timestamp', isGreaterThan: sevenDaysAgo)
          .get();
      return orders.docs.length;
    } catch (_) {
      return 0;
    }
  }
}
