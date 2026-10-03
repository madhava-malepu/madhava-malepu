import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/services/cart_service.dart';
import '/index.dart';
import '/pages/legal/legal_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'profile_model.dart';
export 'profile_model.dart';

const _kGreen = Color(0xFF1A4731);
const _kAmber = Color(0xFFF5A623);
const _kBgLight = Color(0xFFF4F7F4);
const _kBorder = Color(0xFFD4E8D4);
const _kTextDark = Color(0xFF0D1F12);
const _kTextSecondary = Color(0xFF4D6B57);
const _kMintBg = Color(0xFFE6F4ED);

class ProfileWidget extends StatefulWidget {
  const ProfileWidget({super.key});
  static String routeName = 'Profile';
  static String routePath = '/profile';
  @override
  State<ProfileWidget> createState() => _ProfileWidgetState();
}

class _ProfileWidgetState extends State<ProfileWidget> {
  late ProfileModel _model;
  bool _signingOut = false;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ProfileModel());
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'S';
    if (parts.length == 1) {
      return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
    }
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  Widget _statCard(String value, String label, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12, offset: const Offset(0, 4)),
            BoxShadow(
              color: _kGreen.withValues(alpha: 0.04),
              blurRadius: 6, offset: const Offset(0, 1)),
          ]),
        child: Column(children: [
          Icon(icon, size: 20, color: _kGreen),
          const SizedBox(height: 6),
          Text(value, style: GoogleFonts.plusJakartaSans(
            fontSize: 18, fontWeight: FontWeight.w800, color: _kTextDark, letterSpacing: -0.3)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(fontSize: 10, color: _kTextSecondary)),
        ])));
  }

  Widget _menuRow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? labelColor,
    Color? iconColor,
    String? badge,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _kBorder, width: 1))),
        child: Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(color: _kMintBg, borderRadius: BorderRadius.circular(8)),
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: iconColor ?? _kGreen)),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: GoogleFonts.plusJakartaSans(
            fontSize: 14, fontWeight: FontWeight.w600,
            color: labelColor ?? _kTextDark))),
          if (badge != null) Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _kAmber, borderRadius: BorderRadius.circular(10)),
            child: Text(badge, style: GoogleFonts.plusJakartaSans(
              fontSize: 10, fontWeight: FontWeight.w700, color: _kGreen))),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right_rounded, size: 18,
            color: _kTextSecondary.withValues(alpha: 0.5)),
        ])));
  }

  void _showWallet(String uid) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WalletSheet(uid: uid));
  }

  void _showVendorRegistration(String uid) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VendorRegSheet(uid: uid));
  }

  void _showHelpSupport() {
    final faqs = [
      ['What is a surprise bag?',
        'A discounted food package from a local restaurant or bakery containing surplus food. The exact contents are a surprise!'],
      ['How do I pick up my bag?',
        'After booking you get a 6-character pickup code. Show it to the vendor during the pickup window.'],
      ['Can I cancel my order?',
        'Once payment is confirmed, orders cannot be cancelled. Refunds are only issued if the vendor cancels, runs out of stock, or there is a technical error on our side.'],
      ['What if the vendor has run out?',
        'You will receive a full refund to your original payment method (card/UPI) within 5–7 business days.'],
      ['What is the refund policy?',
        'Refunds go to your original payment method for vendor cancellations, out-of-stock items, or Surpl errors. Serious verified complaints may receive a Surpl Wallet credit at Surpl\'s discretion. No refund for missed pickups or changed minds.'],
      ['How does the Surpl Wallet work?',
        'Your wallet holds refunds and credits. Use it to pay for future orders. Balance never expires.'],
      ['How does the referral program work?',
        'Share your referral code with friends. When they register and place their first order, you earn Rs.20 wallet credit. Your friend gets 10% off their first order!'],
      ['What payment methods are accepted?',
        'UPI, debit/credit cards, and net banking via Razorpay. All payments are secure.'],
      ['How do I become a vendor?',
        'Tap Become a Vendor in your profile. Fill the registration form with your FSSAI number. No registration fee — free to join.'],
      ['I have a problem. Who do I contact?',
        'Email hello@surpl.in — we respond within 2 hours during business hours.'],
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: Column(children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                const Icon(Icons.help_outline_rounded, color: _kGreen, size: 22),
                const SizedBox(width: 10),
                Text('Help & Support', style: GoogleFonts.plusJakartaSans(
                  fontSize: 18, fontWeight: FontWeight.w700, color: _kTextDark)),
              ])),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('Frequently asked questions',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13, color: _kTextSecondary))),
            const SizedBox(height: 12),
            const Divider(height: 1),
            Expanded(child: ListView.builder(
              controller: controller,
              padding: const EdgeInsets.all(16),
              itemCount: faqs.length,
              itemBuilder: (_, i) => _FaqTile(q: faqs[i][0], a: faqs[i][1]))),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: GestureDetector(
                onTap: () => launchUrl(Uri.parse(
                    'mailto:hello@surpl.in?subject=Surpl%20Support')),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _kMintBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _kBorder)),
                  child: Row(children: [
                    const Icon(Icons.mail_outline_rounded, color: _kGreen, size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      Text('Still need help?', style: GoogleFonts.plusJakartaSans(
                        fontSize: 13, fontWeight: FontWeight.w700, color: _kTextDark)),
                      Text('hello@surpl.in', style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, color: _kTextSecondary)),
                    ])),
                    Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey.shade400),
                  ])),
              ),
            ),
          ]))));
  }

  Future<void> _confirmDeleteAccount(BuildContext context, String uid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete your Surpl account?',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
        content: Text(
          'This signs you out and permanently deletes your account: your name, '
          'email, saved bags, wallet balance and referral details. Completed order '
          'records may be kept for tax purposes. This cannot be undone.',
          style: GoogleFonts.plusJakartaSans(fontSize: 14, color: _kTextSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete account', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      // Record the request first so the team erases the Firestore profile and
      // wallet even though clients cannot delete those documents themselves.
      await FirebaseFirestore.instance.collection('accountDeletionRequests').doc(uid).set({
        'uid': uid,
        'phoneNumber': currentPhoneNumber,
        'source': 'app',
        'requestedAt': FieldValue.serverTimestamp(),
      });
      await authManager.deleteUser(context);
      if (!mounted) return;
      if (currentUserUid.isNotEmpty) {
        // Firebase needs a fresh sign-in before deleting; deleteUser showed a message.
        // The request above is already saved, so the team will still complete it.
        await authManager.signOut();
      }
      CartService().clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Your account deletion request is in. You have been signed out.')));
        context.goNamed(OnboardingLoginWidget.routeName);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Couldn't delete your account right now. Please try again or email hello@surpl.in.")));
      }
    }
  }

  Future<void> _addTestCredit(BuildContext context, String uid) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'walletBalance': FieldValue.increment(500),
      });
      await FirebaseFirestore.instance.collection('wallet_transactions').add({
        'userId': uid,
        'type': 'credit',
        'amount': 500,
        'note': '[Admin Test Credit] Rs.500 added for testing',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Rs.500 test credit added to wallet'),
          backgroundColor: _kGreen));
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Something went wrong — please try again.'),
          backgroundColor: Colors.red));
      }
    }
  }

  void _showAbout() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Center(child: Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: _kAmber, borderRadius: BorderRadius.circular(18)),
              child: const Center(child: Text('S', style: TextStyle(
                color: _kGreen, fontSize: 36,
                fontWeight: FontWeight.w900, fontFamily: 'Georgia'))))),
            const SizedBox(height: 16),
            Center(child: Text('surpl', style: GoogleFonts.merriweather(
              fontSize: 28, fontWeight: FontWeight.w700, color: _kGreen))),
            Center(child: Text('Sealed with care. Open to dare.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13, fontStyle: FontStyle.italic,
                color: _kTextSecondary))),
            const SizedBox(height: 24),
            _aboutSection('Our Mission',
              'Surpl fights food waste in Jagtial, Telangana by connecting restaurants, bakeries, and cafes with customers who want great food at discounted prices.'),
            _aboutSection('How It Works',
              'Vendors list surplus food as surprise bags at 40-60% off. Customers reserve, pay online, and pick up during the listed window.'),
            _aboutSection('Where We Operate',
              'Currently serving Jagtial, Telangana - expanding to nearby towns soon.'),
            _aboutSection('Refund Policy',
              'Refunds go to your original payment method (card/UPI) for vendor cancellations, out-of-stock items, and Surpl errors. Serious verified complaints may receive a Surpl Wallet credit at Surpl\'s discretion. No refund for missed pickups or changed minds.'),
            _aboutSection('Refer and Earn',
              'Share your referral code with friends. When they register and place their first order, you earn Rs.20 wallet credit. Your friend gets 10% off their first order. No limit on referrals!'),
            _aboutSection('For Vendors',
              'No registration fee. Surpl charges a 10% commission on completed orders only — 0% for your first 30 days.'),
            _aboutSection('Contact',
              'Email: hello@surpl.in  |  surpl.in'),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const TermsOfServiceWidget())),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _kMintBg, borderRadius: BorderRadius.circular(10)),
                  alignment: Alignment.center,
                  child: Text('Terms of Service', style: GoogleFonts.plusJakartaSans(
                    fontSize: 12, fontWeight: FontWeight.w700, color: _kGreen))))),
              const SizedBox(width: 8),
              Expanded(child: GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const PrivacyPolicyWidget())),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _kMintBg, borderRadius: BorderRadius.circular(10)),
                  alignment: Alignment.center,
                  child: Text('Privacy Policy', style: GoogleFonts.plusJakartaSans(
                    fontSize: 12, fontWeight: FontWeight.w700, color: _kGreen))))),
            ]),
            const SizedBox(height: 12),
            Center(child: Text('Version 1.0.0  Surpl 2025',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11, color: _kTextSecondary.withValues(alpha: 0.5)))),
            const SizedBox(height: 20),
          ]))));
  }

  Widget _aboutSection(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: GoogleFonts.plusJakartaSans(
          fontSize: 14, fontWeight: FontWeight.w700, color: _kTextDark)),
        const SizedBox(height: 6),
        Text(body, style: GoogleFonts.plusJakartaSans(
          fontSize: 13, color: _kTextSecondary, height: 1.5)),
      ]));
  }

  @override
  Widget build(BuildContext context) {
    final uid = currentUserUid;

    return Scaffold(
      backgroundColor: _kBgLight,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            // Header
            Container(
              color: _kGreen,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(children: [
                Row(children: [
                  GestureDetector(
                    onTap: () => context.goNamed(HomeFeedWidget.routeName),
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        shape: BoxShape.circle),
                      child: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white, size: 16))),
                  const SizedBox(width: 10),
                  Expanded(child: Text('My Profile',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16, fontWeight: FontWeight.w700,
                      color: Colors.white, letterSpacing: -0.3))),
                  GestureDetector(
                    onTap: () => context.pushNamed(EditProfileWidget.routeName),
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        shape: BoxShape.circle),
                      child: const Icon(Icons.edit_rounded,
                        color: Colors.white, size: 16))),
                ]),
                const SizedBox(height: 20),
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users').doc(uid).snapshots(),
                  builder: (context, snapshot) {
                    final data = snapshot.data?.data() as Map<String, dynamic>?;
                    final name = data?['name'] as String? ?? '';
                    final isVendor = data?['isVendor'] as bool? ?? false;
                    final wallet =
                        (data?['walletBalance'] as num?)?.toDouble() ?? 0.0;
                    return Column(children: [
                      Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: _kGreen, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 16, offset: const Offset(0, 6)),
                            BoxShadow(
                              color: _kGreen.withValues(alpha: 0.25),
                              blurRadius: 8, offset: const Offset(0, 2)),
                          ]),
                        child: Container(
                          width: 80, height: 80,
                          decoration: const BoxDecoration(
                            color: _kAmber, shape: BoxShape.circle),
                          alignment: Alignment.center,
                          child: Text(
                            _initials(name.isEmpty ? 'Surpl' : name),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 26, fontWeight: FontWeight.w800,
                              color: _kGreen)))),
                      const SizedBox(height: 10),
                      Text(
                        name.isEmpty ? 'Surpl User' : name,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18, fontWeight: FontWeight.w700,
                          color: Colors.white)),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () => _showWallet(uid),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2))),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.account_balance_wallet_rounded,
                              color: _kAmber, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'Surpl Wallet: Rs.${wallet.toStringAsFixed(0)}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13, fontWeight: FontWeight.w700,
                                color: Colors.white)),
                            const SizedBox(width: 4),
                            Icon(Icons.chevron_right_rounded,
                              color: Colors.white.withValues(alpha: 0.5), size: 16),
                          ]))),
                      if (isVendor) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: _kAmber,
                            borderRadius: BorderRadius.circular(20)),
                          child: Text('Verified Vendor',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11, fontWeight: FontWeight.w700,
                              color: _kGreen))),
                      ],
                    ]);
                  }),
              ])),

            // Stats
            Padding(
              padding: const EdgeInsets.all(16),
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('orders')
                    .where('customerId', isEqualTo: uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  final orders = snapshot.data?.docs ?? [];
                  final totalOrders = orders.length;
                  final totalSpent = orders.fold<double>(0, (sum, o) {
                    final d = o.data() as Map<String, dynamic>;
                    return sum +
                        ((d['amountPaid'] as num?)?.toDouble() ?? 0);
                  });
                  return StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users').doc(uid).snapshots(),
                    builder: (context, userSnap) {
                      final data =
                          userSnap.data?.data() as Map<String, dynamic>?;
                      final saved =
                          (data?['savedBags'] as List?)?.length ?? 0;
                      return Row(children: [
                        _statCard(totalOrders.toString(), 'Orders',
                          Icons.shopping_bag_rounded),
                        const SizedBox(width: 10),
                        _statCard(
                          'Rs.${totalSpent.toStringAsFixed(0)}',
                          'Spent', Icons.currency_rupee_rounded),
                        const SizedBox(width: 10),
                        _statCard(saved.toString(), 'Saved',
                          Icons.favorite_rounded),
                      ]);
                    });
                })),

            // ── Personal Impact Report ──────────────────────────
            Builder(builder: (context) {
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('orders')
                    .where('customerId', isEqualTo: uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  final docs = (snapshot.data?.docs ?? []).where((d) {
                    final status = (d.data() as Map<String, dynamic>)['status'] as String? ?? '';
                    return status == 'confirmed' || status == 'completed';
                  }).toList();
                  if (docs.isEmpty) return const SizedBox.shrink();

                  final mealsSaved = docs.fold<int>(0, (sum, d) {
                    final data = d.data() as Map<String, dynamic>;
                    return sum + ((data['quantity'] as num?)?.toInt() ?? 1);
                  });
                  // Rough, widely-cited estimate: ~2.5kg CO2e avoided per
                  // rescued meal (food waste in landfill emits methane).
                  // Shown as an estimate, not a precise figure.
                  final co2Kg = (mealsSaved * 2.5).round();

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6F4ED),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFD4E8D4))),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          const Text('🌍', style: TextStyle(fontSize: 18)),
                          const SizedBox(width: 8),
                          Text('Your Impact', style: GoogleFonts.plusJakartaSans(
                            fontSize: 14, fontWeight: FontWeight.w800, color: _kGreen)),
                        ]),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('$mealsSaved', style: GoogleFonts.plusJakartaSans(
                              fontSize: 24, fontWeight: FontWeight.w900, color: _kGreen)),
                            Text('meals rescued', style: GoogleFonts.plusJakartaSans(
                              fontSize: 11, color: const Color(0xFF4D6B57))),
                          ])),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('~${co2Kg}kg', style: GoogleFonts.plusJakartaSans(
                              fontSize: 24, fontWeight: FontWeight.w900, color: _kGreen)),
                            Text('CO₂e avoided (est.)', style: GoogleFonts.plusJakartaSans(
                              fontSize: 11, color: const Color(0xFF4D6B57))),
                          ])),
                        ]),
                      ]),
                    ),
                  );
                },
              );
            }),

            // Menu
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users').doc(uid).snapshots(),
              builder: (context, snapshot) {
                final data =
                    snapshot.data?.data() as Map<String, dynamic>?;
                final isVendor = data?['isVendor'] as bool? ?? false;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.07),
                        blurRadius: 16, offset: const Offset(0, 4)),
                      BoxShadow(
                        color: _kGreen.withValues(alpha: 0.04),
                        blurRadius: 8, offset: const Offset(0, 2)),
                    ]),
                  clipBehavior: Clip.antiAlias,
                  child: Column(children: [
                    _menuRow(
                      icon: Icons.receipt_long_rounded,
                      label: 'My Orders',
                      onTap: () => context.pushNamed(MyOrdersWidget.routeName)),
                    _menuRow(
                      icon: Icons.support_agent_rounded,
                      label: 'Contact Support',
                      onTap: () => context.pushNamed(CustomerSupportWidget.routeName)),
                    _menuRow(
                      icon: Icons.favorite_rounded,
                      label: 'Saved Bags',
                      onTap: () =>
                          context.pushNamed(SavedBagsWidget.routeName)),
                    _menuRow(
                      icon: Icons.storefront_rounded,
                      label: 'My Favourites',
                      onTap: () =>
                          context.pushNamed(FavouritesWidget.routeName)),
                    _menuRow(
                      icon: Icons.add_business_rounded,
                      label: 'Bring Your Restaurant',
                      onTap: () =>
                          context.pushNamed(RestaurantRequestsWidget.routeName)),
                    _menuRow(
                      icon: Icons.celebration_rounded,
                      label: 'Party Mode',
                      onTap: () =>
                          context.pushNamed(PartyModeWidget.routeName)),
                    _menuRow(
                      icon: Icons.account_balance_wallet_rounded,
                      label: 'Surpl Wallet',
                      onTap: () => _showWallet(uid)),
                    if (isVendor)
                      _menuRow(
                        icon: Icons.storefront_rounded,
                        label: 'Vendor Dashboard',
                        onTap: () => context.pushNamed(
                          VendorDashboardWidget.routeName))
                    else
                      _menuRow(
                        icon: Icons.storefront_outlined,
                        label: 'Become a Vendor',
                        badge: 'Free to join',
                        onTap: () => _showVendorRegistration(uid)),
                    _menuRow(
                      icon: Icons.help_outline_rounded,
                      label: 'Help & Support',
                      onTap: _showHelpSupport),
                    _menuRow(
                      icon: Icons.info_outline_rounded,
                      label: 'About Surpl',
                      onTap: _showAbout),
                  ]));
              }),

            const SizedBox(height: 16),

            // Preferences
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 14, offset: const Offset(0, 4)),
                    BoxShadow(
                      color: _kGreen.withValues(alpha: 0.03),
                      blurRadius: 6, offset: const Offset(0, 1)),
                  ]),
                child: StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
                  builder: (context, snap) {
                    final data = snap.data?.data() as Map<String, dynamic>?;
                    final wantsEarlyAlerts = data?['wantsEarlyAlerts'] as bool? ?? false;
                    final completedOrders = (data?['completedOrderCount'] as num?)?.toInt() ?? 0;
                    const loyaltyThreshold = 5;
                    final isLoyal = completedOrders >= loyaltyThreshold;

                    if (!isLoyal) {
                      final remaining = loyaltyThreshold - completedOrders;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(children: [
                          Container(
                            width: 34, height: 34,
                            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                            alignment: Alignment.center,
                            child: Icon(Icons.lock_outline_rounded, size: 18, color: Colors.grey.shade400)),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Early bag alerts', style: GoogleFonts.plusJakartaSans(
                              fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
                            Text('Unlocks after $remaining more order${remaining == 1 ? '' : 's'} — a perk for regulars',
                              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: _kTextSecondary)),
                          ])),
                        ]),
                      );
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(children: [
                        Container(
                          width: 34, height: 34,
                          decoration: BoxDecoration(color: _kMintBg, borderRadius: BorderRadius.circular(8)),
                          alignment: Alignment.center,
                          child: const Icon(Icons.notifications_active_outlined, size: 18, color: _kGreen)),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Early bag alerts', style: GoogleFonts.plusJakartaSans(
                            fontSize: 14, fontWeight: FontWeight.w600, color: _kTextDark)),
                          Text('You\'re a regular — get notified the moment new bags drop',
                            style: GoogleFonts.plusJakartaSans(fontSize: 11, color: _kTextSecondary)),
                        ])),
                        Switch(
                          value: wantsEarlyAlerts,
                          activeColor: _kGreen,
                          onChanged: (v) => FirebaseFirestore.instance.collection('users').doc(uid)
                              .set({'wantsEarlyAlerts': v}, SetOptions(merge: true)),
                        ),
                      ]),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Admin test credit (only visible to admin)
            if (uid == 'on3Z1hcfF6VqT2SczjAVWq2KXhr1' ||
                uid == 'UcY1huWuLFVHSmNLTE4rAwz4CP02')
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GestureDetector(
                  onTap: () => _addTestCredit(context, uid),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      border: Border.all(color: const Color(0xFFFFB74D)),
                      borderRadius: BorderRadius.circular(12)),
                    alignment: Alignment.center,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.science_rounded,
                        color: Color(0xFFE65100), size: 18),
                      const SizedBox(width: 8),
                      Text('Add Rs.500 Test Credit',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14, fontWeight: FontWeight.w700,
                          color: const Color(0xFFE65100))),
                    ])))),

            const SizedBox(height: 16),

            // Sign out
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: _signingOut ? null : () async {
                  setState(() => _signingOut = true);
                  // CartService is a global singleton, not scoped to a
                  // user session - without clearing it here, a different
                  // person logging into the same device would see the
                  // previous user's cart items still sitting there.
                  CartService().clear();
                  await authManager.signOut();
                  if (mounted) {
                    context.goNamed(OnboardingLoginWidget.routeName);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.red.shade100),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.06),
                        blurRadius: 10, offset: const Offset(0, 3)),
                    ]),
                  alignment: Alignment.center,
                  child: _signingOut
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.red)))
                    : Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.logout_rounded,
                          color: Colors.red, size: 18),
                        const SizedBox(width: 8),
                        Text('Sign Out', style: GoogleFonts.plusJakartaSans(
                          fontSize: 14, fontWeight: FontWeight.w700,
                          color: Colors.red)),
                      ])))),

            const SizedBox(height: 12),

            // Delete account (App Store guideline 5.1.1(v): deletion must be possible in the app)
            Center(
              child: TextButton(
                onPressed: () => _confirmDeleteAccount(context, uid),
                child: Text('Delete my account',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: _kTextSecondary,
                    decoration: TextDecoration.underline)),
              ),
            ),

            const SizedBox(height: 24),
            Center(child: Text('surpl v1.0  Jagtial, Telangana',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: _kTextSecondary.withValues(alpha: 0.5)))),
            const SizedBox(height: 20),
          ]))));
  }
}

// FAQ Tile
class _FaqTile extends StatefulWidget {
  final String q, a;
  const _FaqTile({required this.q, required this.a});
  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _open = false;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _kBgLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder)),
      child: Column(children: [
        GestureDetector(
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Expanded(child: Text(widget.q,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: _kTextDark))),
              Icon(_open ? Icons.expand_less : Icons.expand_more,
                color: _kGreen, size: 20),
            ]))),
        if (_open) Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: Text(widget.a, style: GoogleFonts.plusJakartaSans(
            fontSize: 13, color: _kTextSecondary, height: 1.5))),
      ]));
  }
}

// Wallet Sheet
class _WalletSheet extends StatelessWidget {
  final String uid;
  const _WalletSheet({required this.uid});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users').doc(uid).snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() as Map<String, dynamic>?;
          final balance =
              (data?['walletBalance'] as num?)?.toDouble() ?? 0.0;
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('wallet_transactions')
                .where('userId', isEqualTo: uid)
                .limit(20)
                .snapshots(),
            builder: (context, txSnap) {
              final txs = txSnap.data?.docs ?? [];
              return Column(children: [
                const SizedBox(height: 8),
                Container(width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _kGreen,
                    borderRadius: BorderRadius.circular(16)),
                  child: Row(children: [
                    const Icon(Icons.account_balance_wallet_rounded,
                      color: _kAmber, size: 28),
                    const SizedBox(width: 14),
                    Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      Text('Surpl Wallet',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.7))),
                      Text('Rs.${balance.toStringAsFixed(2)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 28, fontWeight: FontWeight.w800,
                          color: Colors.white)),
                    ]),
                    const Spacer(),
                    Column(crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _kAmber,
                          borderRadius: BorderRadius.circular(8)),
                        child: Text('Active',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10, fontWeight: FontWeight.w700,
                            color: _kGreen))),
                      const SizedBox(height: 4),
                      Text('Never expires',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          color: Colors.white.withValues(alpha: 0.5))),
                    ]),
                  ])),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    Text('Transactions',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14, fontWeight: FontWeight.w700,
                        color: _kTextDark)),
                  ])),
                const SizedBox(height: 8),
                Expanded(child: txs.isEmpty
                  ? Center(child: Text('No transactions yet',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13, color: _kTextSecondary)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: txs.length,
                      itemBuilder: (_, i) {
                        final d = txs[i].data() as Map<String, dynamic>;
                        final type = d['type'] as String? ?? 'credit';
                        final amount =
                            (d['amount'] as num?)?.toDouble() ?? 0;
                        final note = d['note'] as String? ?? '';
                        final isCredit = type == 'credit';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: _kBgLight,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _kBorder)),
                          child: Row(children: [
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: isCredit
                                    ? _kMintBg
                                    : Colors.red.shade50,
                                shape: BoxShape.circle),
                              child: Icon(
                                isCredit
                                    ? Icons.add_rounded
                                    : Icons.remove_rounded,
                                color: isCredit ? _kGreen : Colors.red,
                                size: 20)),
                            const SizedBox(width: 10),
                            Expanded(child: Text(
                              note.isEmpty
                                  ? (isCredit ? 'Credit' : 'Debit')
                                  : note,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13, fontWeight: FontWeight.w600,
                                color: _kTextDark))),
                            Text(
                              '${isCredit ? '+' : '-'}Rs.${amount.toStringAsFixed(0)}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14, fontWeight: FontWeight.w700,
                                color: isCredit ? _kGreen : Colors.red)),
                          ]));
                      })),
              ]);
            });
        }));
  }
}

// Vendor Registration Sheet
class _VendorRegSheet extends StatefulWidget {
  final String uid;
  const _VendorRegSheet({required this.uid});
  @override
  State<_VendorRegSheet> createState() => _VendorRegSheetState();
}

class _VendorRegSheetState extends State<_VendorRegSheet> {
  bool _paying = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(child: Container(width: 40, height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 20),
        Center(child: Container(width: 64, height: 64,
          decoration: BoxDecoration(
            color: _kMintBg, shape: BoxShape.circle),
          child: const Icon(Icons.storefront_rounded,
            color: _kGreen, size: 32))),
        const SizedBox(height: 16),
        Center(child: Text('Become a Surpl Vendor',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20, fontWeight: FontWeight.w800,
            color: _kTextDark))),
        Center(child: Text('Start selling surplus food today',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13, color: _kTextSecondary))),
        const SizedBox(height: 24),
        _benefitRow(Icons.currency_rupee_rounded,
          'Free to join',
          'No registration fee — 0% commission for your first 30 days'),
        _benefitRow(Icons.people_rounded,
          'Reach more customers',
          'Get listed on Surpl for free after verification'),
        _benefitRow(Icons.eco_rounded,
          'Reduce food waste',
          'Turn surplus into revenue, not waste'),
        _benefitRow(Icons.payments_rounded,
          'Weekly payouts',
          'Earnings paid to your bank every Monday'),
        const Spacer(),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _kMintBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kBorder)),
          child: Row(children: [
            const Icon(Icons.info_outline_rounded, color: _kGreen, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(
              'No registration fee — Surpl charges 10% commission on completed orders only.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12, color: _kGreen, height: 1.4))),
          ])),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _paying ? null : () async {
            setState(() => _paying = true);
            Navigator.pop(context);
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
                title: const Text('Registration Submitted'),
                content: const Text(
                  'Your vendor application is under review. '
                  'You will be verified within 24 hours. '
                  'Free to join — no registration fee.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK')),
                ]));
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: _paying
                  ? _kGreen.withValues(alpha: 0.6)
                  : _kGreen,
              borderRadius: BorderRadius.circular(14)),
            alignment: Alignment.center,
            child: _paying
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
              : Text('Register as Vendor',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15, fontWeight: FontWeight.w700,
                    color: Colors.white)))),
      ]));
  }

  Widget _benefitRow(IconData icon, String title, String sub) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(children: [
        Container(width: 40, height: 40,
          decoration: BoxDecoration(
            color: _kMintBg, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: _kGreen, size: 20)),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Text(title, style: GoogleFonts.plusJakartaSans(
            fontSize: 13, fontWeight: FontWeight.w700, color: _kTextDark)),
          Text(sub, style: GoogleFonts.plusJakartaSans(
            fontSize: 11, color: _kTextSecondary)),
        ])),
      ]));
  }
}