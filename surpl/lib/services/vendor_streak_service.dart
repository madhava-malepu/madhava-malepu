import 'package:cloud_firestore/cloud_firestore.dart';

/// Counts how many consecutive calendar days (ending today or yesterday)
/// a vendor has had at least one active bag listed. Pure read of existing
/// bag data — no new writes, no risk of double-counting or gaming beyond
/// what listing itself already requires.
class VendorStreakService {
  static Future<int> currentStreak(String merchantId) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('bags')
          .where('merchantId', isEqualTo: merchantId)
          // No .orderBy() - this query's result is only ever used to
          // build a Set of dates (membership-checked, not order-
          // dependent), so sorting was requiring a composite index for
          // zero actual benefit. No .limit() either - unlike
          // .orderBy()+.limit() which reliably gets the most recent N,
          // .limit() alone without a sort would return an arbitrary N,
          // which could miss the exact recent bags this streak
          // calculation needs. A single vendor's total bag count over a
          // realistic business lifetime isn't large enough for this to
          // be a genuine performance concern.
          .get();

      final days = <DateTime>{};
      for (final doc in snap.docs) {
        final ts = doc.data()['createdAt'];
        if (ts is Timestamp) {
          final d = ts.toDate();
          days.add(DateTime(d.year, d.month, d.day));
        }
      }
      if (days.isEmpty) return 0;

      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      // Streak can start from today or yesterday (so a vendor who listed
      // yesterday but hasn't yet today doesn't lose their streak mid-day).
      var cursor = days.contains(todayDate)
          ? todayDate
          : todayDate.subtract(const Duration(days: 1));
      if (!days.contains(cursor)) return 0;

      var streak = 0;
      while (days.contains(cursor)) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
      }
      return streak;
    } catch (_) {
      return 0;
    }
  }
}
