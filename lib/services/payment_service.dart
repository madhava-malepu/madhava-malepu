import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:flutter/material.dart';

// NOTE: as of this check, this file and widgets/payment_button.dart are
// not referenced anywhere else in the app - checkout_widget.dart has its
// own separate, actively-used Razorpay integration. This key is kept in
// sync with that one so that if this widget is ever wired up in future,
// it won't silently route payments through a different/wrong key.
class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  late Razorpay _razorpay;

  static const String RAZORPAY_KEY = String.fromEnvironment('RAZORPAY_KEY', defaultValue: '');

  factory PaymentService() => _instance;

  PaymentService._internal() {
    _razorpay = Razorpay();
  }

  Future<bool> processPayment({
    required BuildContext context,
    required String orderId,
    required String bagId,
    required String bagName,
    required double amount,
    required String customerEmail,
    required String customerPhone,
    required Function(String paymentId, String orderId) onSuccess,
    required Function(String error) onError,
  }) async {
    try {
      // Clear previous listeners first to avoid duplicates
      _razorpay.clear();

      _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse response) {
        onSuccess(response.paymentId ?? '', orderId);
      });

      _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse response) {
        onError(response.message ?? 'Payment failed');
      });

      _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse response) {
        // External wallet selected — treat as pending
      });

      // IMPORTANT: Do NOT pass 'order_id' here unless you have a Razorpay order ID
      // from their API. Passing a Firestore doc ID causes payment failure.
      final options = {
        'key': RAZORPAY_KEY,
        'amount': (amount * 100).toInt(), // paise
        'name': 'Surpl',
        'description': bagName,
        'prefill': {
          'contact': customerPhone.isNotEmpty ? customerPhone : '',
          'email': customerEmail.isNotEmpty ? customerEmail : 'user@surpl.in',
        },
        'notes': {
          'surpl_order_id': orderId,
          'bag_id': bagId,
        },
        'theme': {
          'color': '#1A4731',
        },
      };

      _razorpay.open(options);
      return true;
    } catch (e) {
      onError('Could not open payment: $e');
      return false;
    }
  }

  void dispose() {
    _razorpay.clear();
  }
}
