import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '/services/payment_service.dart';

class PaymentButton extends StatefulWidget {
  final String bagId;
  final String bagName;
  final double amount;
  final String customerEmail;
  final String customerPhone;
  final VoidCallback onPaymentSuccess;
  final Function(String) onPaymentError;

  const PaymentButton({
    Key? key,
    required this.bagId,
    required this.bagName,
    required this.amount,
    required this.customerEmail,
    required this.customerPhone,
    required this.onPaymentSuccess,
    required this.onPaymentError,
  }) : super(key: key);

  @override
  State<PaymentButton> createState() => _PaymentButtonState();
}

class _PaymentButtonState extends State<PaymentButton> {
  bool _isProcessing = false;

  Future<void> _initiatePayment() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      // Generate unique order ID
      const uuid = Uuid();
      final orderId = 'order_${uuid.v4()}';

      // Initialize payment service
      final paymentService = PaymentService();

      // Process payment
      await paymentService.processPayment(
        context: context,
        orderId: orderId,
        bagId: widget.bagId,
        bagName: widget.bagName,
        amount: widget.amount,
        customerEmail: widget.customerEmail,
        customerPhone: widget.customerPhone,
        onSuccess: (paymentId, orderId) {
          widget.onPaymentSuccess();
        },
        onError: (error) {
          widget.onPaymentError(error);
        },
      );
    } catch (e) {
      widget.onPaymentError('Error: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _isProcessing ? null : _initiatePayment,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1a4731),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      child: Text(
        _isProcessing ? 'Processing...' : 'Pay & Book Bag (₹${widget.amount.toStringAsFixed(0)})',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}
