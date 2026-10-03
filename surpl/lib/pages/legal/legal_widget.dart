import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';

const _kGreen = Color(0xFF1A4731);
const _kBgLight = Color(0xFFF4F7F4);
const _kBorder = Color(0xFFD4E8D4);
const _kTextDark = Color(0xFF0D1F12);
const _kTextSecondary = Color(0xFF4D6B57);

class TermsOfServiceWidget extends StatelessWidget {
  const TermsOfServiceWidget({super.key});
  static String routeName = 'TermsOfService';
  static String routePath = '/termsOfService';

  @override
  Widget build(BuildContext context) {
    return _LegalScaffold(
      title: 'Terms of Service',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _section('1. About Surpl',
            'Surpl is a food surplus marketplace connecting local food vendors across Telangana with customers who want to buy surplus end-of-day food at a discount. Food is sold as Surprise Bags — customers pay online and collect in person from the vendor. There is no delivery service.'),
        _section('2. Account Registration',
            'You must be at least 18 years old to use Surpl. Register using a valid phone number verified via OTP. You are responsible for keeping your account secure and for all activity under your account.'),
        _section('3. Pricing and Platform Fee',
            'Each Surprise Bag has a price set by the vendor, subject to a minimum of ₹29. Surpl charges customers a flat platform convenience fee of ₹5 per order, shown transparently at checkout before payment. Prices displayed are inclusive of applicable Goods and Services Tax (GST), where such tax applies. Surpl is registered under GSTIN: 36CXUPM2129K1ZW.'),
        _section('4. Orders and Payment',
            'Payment is processed online via Razorpay (UPI, card, net banking) or your Surpl Wallet. Once payment is confirmed, your order is final and cannot be cancelled. You will receive a unique 6-digit pickup code to collect your bag.'),
        _section('5. Pickup Window',
            'Each order has a pickup window set by the vendor. You must collect your bag from the vendor\'s premises during this window using your pickup code.'),
        _section('6. No-Show Policy',
            'If you do not collect your order within the pickup window, the order is marked as missed. The vendor has prepared the food on your behalf — no refund will be issued for missed pickups.'),
        _section('7. Cancellations and Refunds',
            'Once payment is confirmed, cancellations are not permitted. Refunds are issued in the following situations:\n\n• Vendor cancels your order → full refund to your original payment method (card/UPI) within 5–7 business days\n• Vendor runs out of stock after your payment → full refund to original payment method\n• Technical error on Surpl\'s part → full refund to original payment method\n• Serious verified complaint (food safety issue) → Surpl Wallet credit at Surpl\'s discretion\n\nNo refund for customer no-shows or dissatisfaction with Surprise Bag contents.'),
        _section('8. Surpl Wallet',
            'Your Surpl Wallet holds referral bonuses (₹20 per successful referral) and first-order discounts (10% for referred new users). Wallet balance cannot be withdrawn as cash or transferred to another user. It has no expiry.'),
        _section('9. Vendor Terms',
            'Vendors must hold a valid FSSAI licence to register on Surpl. There is no registration fee — Surpl charges vendors a 10% commission on completed orders only. During the launch period (first 30 days), vendor commission is 0%. Vendor payouts are processed weekly every Monday via UPI or bank transfer.'),
        _section('10. Referral Programme',
            'Refer a new user with your referral code — they get 10% off their first order, and you get ₹20 credited to your Surpl Wallet once they complete their first order.'),
        _section('11. Surprise Bag Contents',
            'Bag contents are not disclosed in advance and will vary daily. The value of contents always exceeds the price paid. By booking a Surprise Bag, you accept this.'),
        _section('12. Food Safety',
            'Vendors are solely responsible for the quality, safety, and fitness for consumption of all food in their bags. Surpl is a technology platform and does not prepare, handle, or inspect food.'),
        _section('13. Governing Law',
            'These Terms are governed by the laws of India. Disputes are subject to the jurisdiction of the courts in Jagtial, Telangana.'),
        _section('14. Contact',
            'Grievance Officer: Shankara Chary Malepu\nEmail: hello@surpl.in\nPhone: +91 8143032333\nHours: Monday–Saturday, 10:00 AM – 7:00 PM IST\nFSSAI Registration No: 23626015000811'),
        const SizedBox(height: 8),
        Text('Last updated: July 2026', style: GoogleFonts.plusJakartaSans(
          fontSize: 12, color: _kTextSecondary, fontStyle: FontStyle.italic)),
      ]),
    );
  }

  Widget _section(String title, String body) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: GoogleFonts.plusJakartaSans(
        fontSize: 15, fontWeight: FontWeight.w700, color: _kTextDark)),
      const SizedBox(height: 6),
      Text(body, style: GoogleFonts.plusJakartaSans(
        fontSize: 13, color: _kTextSecondary, height: 1.6)),
    ]));
}

class PrivacyPolicyWidget extends StatelessWidget {
  const PrivacyPolicyWidget({super.key});
  static String routeName = 'PrivacyPolicy';
  static String routePath = '/privacyPolicy';

  @override
  Widget build(BuildContext context) {
    return _LegalScaffold(
      title: 'Privacy Policy',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _section('1. Information We Collect',
            'From customers: phone number (mandatory), name and email (optional), order history, Surpl Wallet balance and transactions, saved bags, approximate location (to show distance to vendors and enable navigation).\n\nFrom vendors: shop name, owner name, FSSAI licence number, shop address, GPS coordinates, bank account details (for payouts).'),
        _section('2. How We Use Your Information',
            'To create and manage your account, process and fulfil orders, operate the Surpl Wallet, send push notifications about new bags, calculate distance to vendors, enable navigation, process weekly vendor payouts, and detect fraud.'),
        _section('3. Location Data',
            'We use your approximate location to show distance from you to vendors and to enable navigation. We do not track your location continuously. You may deny location permission — the app still works but distance and navigation features will be unavailable.'),
        _section('4. Payment Information',
            'Payments are processed by Razorpay. Surpl does not store your card, UPI PIN, or bank account credentials.'),
        _section('5. Data Processors',
            'Your data is processed by Google Firebase (database, authentication, storage, notifications) and Razorpay (payments). We do not sell your personal data or use it for advertising.'),
        _section('6. Push Notifications',
            'With your permission, we send push notifications when new bags are listed near you and when your orders are updated. You can disable these in your device settings at any time.'),
        _section('7. Your Rights',
            'You may request access to, correction of, or deletion of your data by contacting hello@surpl.in.'),
        _section('8. Children\'s Privacy',
            'Surpl is for users aged 18 and over. We do not knowingly collect data from minors.'),
        _section('9. Contact',
            'Data Protection Officer: Shankara Chary Malepu\nEmail: hello@surpl.in\nPhone: +91 8143032333'),
        const SizedBox(height: 8),
        Text('Last updated: July 2026', style: GoogleFonts.plusJakartaSans(
          fontSize: 12, color: _kTextSecondary, fontStyle: FontStyle.italic)),
      ]),
    );
  }

  Widget _section(String title, String body) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: GoogleFonts.plusJakartaSans(
        fontSize: 15, fontWeight: FontWeight.w700, color: _kTextDark)),
      const SizedBox(height: 6),
      Text(body, style: GoogleFonts.plusJakartaSans(
        fontSize: 13, color: _kTextSecondary, height: 1.6)),
    ]));
}

class _LegalScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  const _LegalScaffold({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBgLight,
      body: Column(children: [
        Container(
          color: _kGreen,
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 14,
            left: 16, right: 16, bottom: 16),
          child: Row(children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.arrow_back_rounded,
                  color: Colors.white, size: 18))),
            const SizedBox(width: 12),
            Text(title, style: GoogleFonts.plusJakartaSans(
              fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
          ]),
        ),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: child)),
      ]),
    );
  }
}