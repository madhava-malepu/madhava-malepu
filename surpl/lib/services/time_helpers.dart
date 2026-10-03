import 'package:timeago/timeago.dart' as timeago;

/// Small shared helpers for the freshness/urgency features across bag
/// cards, bag detail, and the expiring-soon list.
class TimeHelpers {
  /// "Listed 12m ago" / "Listed 3h ago" style text from a bag's createdAt.
  static String listedAgo(DateTime? createdAt) {
    if (createdAt == null) return '';
    return 'Listed ${timeago.format(createdAt, allowFromNow: true)}';
  }

  /// Minutes remaining until [pickupEndMillis]. Negative if already past.
  static int minutesUntil(int? pickupEndMillis) {
    if (pickupEndMillis == null || pickupEndMillis == 0) return 9999;
    final end = DateTime.fromMillisecondsSinceEpoch(pickupEndMillis);
    return end.difference(DateTime.now()).inMinutes;
  }

  /// Human label for how soon a bag's pickup window closes.
  static String expiryLabel(int minutesLeft) {
    if (minutesLeft <= 0) return 'Pickup window closed';
    if (minutesLeft < 60) return '$minutesLeft min left';
    final hours = (minutesLeft / 60).floor();
    final mins = minutesLeft % 60;
    return mins > 0 ? '${hours}h ${mins}m left' : '${hours}h left';
  }
}
