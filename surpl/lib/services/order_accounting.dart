class OrderAccounting {
  static bool isPaid(Map<String, dynamic> order) {
    if (!['confirmed', 'preparing', 'ready', 'completed', 'missed'].contains(order['status']) ||
        order['paymentStatus'] == 'refunded' || order['refundStatus'] == 'processed') return false;
    final paymentId = order['razorpayPaymentId'] ?? order['paymentId'] ?? '';
    return order['status'] != 'missed' || order['paymentVerifiedAt'] != null ||
        (paymentId is String && paymentId.startsWith('pay_')) ||
        (order['paymentMethod'] == 'wallet' && order['paymentId'] == 'WALLET');
  }

  static double vendorEarned(Map<String, dynamic> order) {
    final payout = order['vendorPayout'];
    return isPaid(order) && order['vendorAtFault'] != true && payout is num && payout.isFinite && payout >= 0
        ? (payout * 100).round() / 100 : 0;
  }
}
