import '/flutter_flow/flutter_flow_util.dart';
import '/services/streak_service.dart';
import '/index.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:url_launcher/url_launcher.dart';
import '/services/impact_service.dart';
import 'order_confirmation_model.dart';
export 'order_confirmation_model.dart';

const _kGreen = Color(0xFF1A4731);
const _kAmber = Color(0xFFF5A623);
const _kBgLight = Color(0xFFF4F7F4);
const _kBorder = Color(0xFFD4E8D4);
const _kTextDark = Color(0xFF0D1F12);
const _kTextSecondary = Color(0xFF4D6B57);
const _kMintBg = Color(0xFFE6F4ED);

class OrderConfirmationWidget extends StatefulWidget {
  const OrderConfirmationWidget({super.key, String? orderId})
      : orderId = orderId ?? '';
  final String orderId;
  static String routeName = 'OrderConfirmation';
  static String routePath = '/orderConfirmation';
  @override
  State<OrderConfirmationWidget> createState() =>
      _OrderConfirmationWidgetState();
}

class _OrderConfirmationWidgetState extends State<OrderConfirmationWidget>
    with TickerProviderStateMixin {
  late OrderConfirmationModel _model;
  late AnimationController _checkCtrl;
  late AnimationController _contentCtrl;
  late Animation<double> _checkScale;
  late Animation<double> _contentSlide;
  bool _codeCopied = false;
  bool _splitShared = false;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => OrderConfirmationModel());
    // Check streak reward after successful order
    if (widget.orderId.isNotEmpty) {
      StreakService.checkAndAwardStreak(
        FirebaseAuth.instance.currentUser?.uid ?? '');
    }
    _checkCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _contentCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _checkScale = CurvedAnimation(parent: _checkCtrl, curve: Curves.elasticOut);
    _contentSlide = CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOutCubic);

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _checkCtrl.forward();
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _contentCtrl.forward();
    });
  }

  @override
  void dispose() {
    _model.dispose();
    _checkCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  void _copyCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    setState(() => _codeCopied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _codeCopied = false);
    });
  }

  // ── Split with friend ──────────────────────────────────────────
  Future<void> _splitWithFriend({
    required double amount,
    required String bagTitle,
    required String pickupCode,
    required String vendorName,
    required String pickupTime,
  }) async {
    final half = (amount / 2).ceil(); // round up so total is covered
    final message = Uri.encodeComponent(
      '🎁 Hey! I ordered a *Surpl* surprise bag and want to split the cost with you!\n\n'
      '🛍 Bag: $bagTitle\n'
      '🏪 From: $vendorName\n'
      '⏰ Pickup: $pickupTime\n'
      '💰 My half: ₹$half\n\n'
      '📱 Pickup code (we\'ll go together): *$pickupCode*\n\n'
      'Send me ₹$half on UPI and let\'s go collect it! 😄\n'
      'Download Surpl: https://play.google.com/store/apps/details?id=com.surpl.app'
    );

    final whatsappUrl = Uri.parse('https://wa.me/?text=$message');

    try {
      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      setState(() => _splitShared = true);
    } catch (_) {
      // Fallback — copy message to clipboard
      await Clipboard.setData(ClipboardData(text: Uri.decodeComponent(message)));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Split message copied — paste it to your friend!'),
            backgroundColor: _kGreen,
          ));
      }
    }
  }

  Widget _infoRow(String label, String value, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(flex: 2, child: Text(label, style: GoogleFonts.plusJakartaSans(
        fontSize: 13, color: _kTextSecondary))),
      const SizedBox(width: 12),
      Expanded(flex: 3, child: Text(value,
        textAlign: TextAlign.right,
        softWrap: true,
        overflow: TextOverflow.ellipsis,
        maxLines: 2,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          color: bold ? _kGreen : _kTextDark))),
    ]));

  Widget _impactStat(String emoji, String value, String label) => Column(
    children: [
      Text(emoji, style: const TextStyle(fontSize: 18)),
      const SizedBox(height: 2),
      Text(value, style: GoogleFonts.plusJakartaSans(
          fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF1A8A3E))),
      Text(label, style: GoogleFonts.plusJakartaSans(
          fontSize: 9.5, color: const Color(0xFF1A8A3E).withValues(alpha: 0.8))),
    ]);

  @override
  Widget build(BuildContext context) {
    if (widget.orderId.isEmpty) {
      return Scaffold(backgroundColor: _kBgLight,
        body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.error_outline, color: _kTextSecondary, size: 48),
          const SizedBox(height: 16),
          Text('Order not found', style: GoogleFonts.plusJakartaSans(
            fontSize: 16, color: _kTextSecondary)),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => context.goNamed(HomeFeedWidget.routeName),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(color: _kGreen, borderRadius: BorderRadius.circular(12)),
              child: Text('Go Home', style: GoogleFonts.plusJakartaSans(
                color: Colors.white, fontWeight: FontWeight.w700)))),
        ])));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('orders')
          .doc(widget.orderId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Scaffold(backgroundColor: _kBgLight,
          body: Center(child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(_kGreen))));

        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final status = data?['status'] as String? ?? 'pending';
        final amount = (data?['amountPaid'] as num?)?.toDouble() ?? 0.0;
        final ts = data?['timestamp'] as int? ?? 0;
        final paymentMethod = data?['paymentMethod'] as String? ?? 'razorpay';
        final bagId = data?['bagId'] as String? ?? '';
        final isConfirmed = status == 'confirmed' || status == 'completed';
        final pickupCode = isConfirmed ? (data?['pickupCode'] as String? ?? '') : '';
        final orderQuantity = (data?['quantity'] as num?)?.toInt() ?? 1;
        final orderOriginalPrice = (data?['originalPrice'] as num?)?.toDouble() ?? 0.0;
        final impact = ImpactService.forOrder(
          bagCount: orderQuantity,
          originalPrice: orderOriginalPrice,
          amountPaid: amount);
        final dateStr = ts > 0
            // timestamp is stored in SECONDS, not milliseconds
            ? dateTimeFormat('MMM d, h:mm a', DateTime.fromMillisecondsSinceEpoch(ts * 1000))
            : '';

        return Scaffold(
          backgroundColor: _kBgLight,
          body: Column(children: [
            // Animated header
            Container(
              decoration: BoxDecoration(
                color: isConfirmed ? _kGreen : const Color(0xFFE65100),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28)),
                boxShadow: [BoxShadow(
                  color: (isConfirmed ? _kGreen : const Color(0xFFE65100)).withValues(alpha: 0.25),
                  blurRadius: 20, offset: const Offset(0, 8))]),
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 20,
                bottom: 32, left: 16, right: 16),
              child: Column(children: [
                ScaleTransition(
                  scale: _checkScale,
                  child: Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      color: isConfirmed ? _kAmber : Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 16, offset: const Offset(0, 4))]),
                    alignment: Alignment.center,
                    child: Icon(
                      isConfirmed ? Icons.check_rounded : Icons.hourglass_empty_rounded,
                      color: isConfirmed ? _kGreen : const Color(0xFFE65100),
                      size: 40)),
                ),
                const SizedBox(height: 16),
                Text(
                  isConfirmed ? '🎉 Order Confirmed!' : '⏳ Payment Pending',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white,
                    letterSpacing: -0.3)),
                const SizedBox(height: 6),
                Text(
                  isConfirmed
                    ? 'Your surprise bag is waiting!'
                    : 'Completing your payment...',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14, color: Colors.white.withValues(alpha: 0.7),
                    fontStyle: FontStyle.italic)),
              ]),
            ),

            if (isConfirmed) Container(
              margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF7EE),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF1A8A3E).withValues(alpha: 0.25))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Your impact from this order',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 13, fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A8A3E))),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _impactStat('🍽️',
                      '~${impact.foodSavedKg.toStringAsFixed(1)}kg',
                      'food rescued')),
                  Expanded(child: _impactStat('🌍',
                      '~${impact.co2SavedKg.toStringAsFixed(1)}kg',
                      'CO₂e avoided')),
                  Expanded(child: _impactStat('💰',
                      '₹${impact.moneySaved.toStringAsFixed(0)}',
                      'you saved')),
                ]),
                const SizedBox(height: 6),
                Text('Estimated, based on average bag weight - not an exact measurement.',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 9.5, color: const Color(0xFF1A8A3E).withValues(alpha: 0.7),
                        fontStyle: FontStyle.italic)),
              ])),

            Expanded(child: AnimatedBuilder(
              animation: _contentSlide,
              builder: (context, child) => Transform.translate(
                offset: Offset(0, 30 * (1 - _contentSlide.value)),
                child: Opacity(opacity: _contentSlide.value, child: child)),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

                  // Pickup code — tap to copy
                  if (isConfirmed && pickupCode.isNotEmpty) ...[
                    GestureDetector(
                      onTap: () => _copyCode(pickupCode),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: _kBorder, width: 1.5),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: _kGreen.withValues(alpha: 0.10),
                              blurRadius: 20, offset: const Offset(0, 6)),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 6, offset: const Offset(0, 2)),
                          ]),
                        padding: const EdgeInsets.all(22),
                        child: Column(children: [
                          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Text('PICKUP CODE', style: GoogleFonts.plusJakartaSans(
                              fontSize: 11, fontWeight: FontWeight.w700,
                              letterSpacing: 1.5, color: _kTextSecondary)),
                            const SizedBox(width: 8),
                            Icon(
                              _codeCopied ? Icons.check_circle : Icons.copy_rounded,
                              size: 14,
                              color: _codeCopied ? Colors.green : _kTextSecondary),
                          ]),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                            decoration: BoxDecoration(
                              color: _kMintBg,
                              border: Border.all(color: _kBorder, width: 2),
                              borderRadius: BorderRadius.circular(14)),
                            child: Text(pickupCode,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 38, fontWeight: FontWeight.w900,
                                letterSpacing: 12, color: _kGreen))),
                          const SizedBox(height: 10),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Text(
                              _codeCopied ? '✅ Copied to clipboard!' : 'Tap to copy • Show to vendor',
                              key: ValueKey(_codeCopied),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: _codeCopied ? Colors.green.shade700 : _kTextSecondary,
                                fontWeight: _codeCopied ? FontWeight.w600 : FontWeight.w400))),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── SPLIT WITH FRIEND BUTTON ─────────────────
                    FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('bags').doc(bagId).get(),
                      builder: (_, bagSnap) {
                        final bagData = bagSnap.data?.data() as Map<String, dynamic>?;
                        // merchantName/bagTitle read from the ORDER
                        // document (data), not this separate bags/{bagId}
                        // fetch - bags get cleaned up after their pickup
                        // window ends (expireEndedListings), so a
                        // customer opening this confirmation later would
                        // get a null bag lookup and fall back to the same
                        // generic "Local Vendor" label found and fixed
                        // elsewhere this session. The order itself always
                        // has the real name, permanently, regardless of
                        // what happens to the bag afterward.
                        final bagTitle = data?['bagTitle'] as String? ?? bagData?['title'] as String? ?? 'Surprise Bag';
                        final pickupStart = bagData?['pickupStart'] as String? ?? '';
                        final pickupEnd = bagData?['pickupEnd'] as String? ?? '';
                        final pickupTime = pickupStart.isNotEmpty
                            ? '$pickupStart – $pickupEnd' : 'See pickup time in app';
                        final merchantName = data?['merchantName'] as String? ?? bagData?['merchantName'] as String? ?? 'Local Vendor';

                        return GestureDetector(
                          onTap: () => _splitWithFriend(
                            amount: amount,
                            bagTitle: bagTitle,
                            pickupCode: pickupCode,
                            vendorName: merchantName,
                            pickupTime: pickupTime,
                          ),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                            decoration: BoxDecoration(
                              color: _splitShared
                                  ? const Color(0xFF25D366)  // WhatsApp green
                                  : const Color(0xFFFFF8E1),
                              border: Border.all(
                                color: _splitShared
                                    ? const Color(0xFF25D366)
                                    : const Color(0xFFF5A623),
                                width: 1.5),
                              borderRadius: BorderRadius.circular(14)),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                              // WhatsApp icon
                              Container(
                                width: 32, height: 32,
                                decoration: BoxDecoration(
                                  color: _splitShared
                                      ? Colors.white.withValues(alpha: 0.2)
                                      : const Color(0xFF25D366),
                                  shape: BoxShape.circle),
                                child: const Center(
                                  child: Text('💬', style: TextStyle(fontSize: 16)))),
                              const SizedBox(width: 12),
                              Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _splitShared
                                        ? 'Shared on WhatsApp! 🎉'
                                        : 'Split with a friend',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: _splitShared ? Colors.white : _kTextDark)),
                                  Text(
                                    _splitShared
                                        ? 'Your friend can pay you back via UPI'
                                        : 'Share via WhatsApp • Each pays ₹${(amount / 2).ceil()}',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      color: _splitShared
                                          ? Colors.white.withValues(alpha: 0.85)
                                          : _kTextSecondary)),
                                ])),
                              const SizedBox(width: 8),
                              Icon(
                                _splitShared
                                    ? Icons.check_circle_rounded
                                    : Icons.arrow_forward_ios_rounded,
                                color: _splitShared ? Colors.white : _kAmber,
                                size: _splitShared ? 20 : 14),
                            ])),
                        );
                      }),
                    const SizedBox(height: 14),
                  ],

                  // Vendor location map
                  if (isConfirmed && bagId.isNotEmpty) ...[
                    FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('bags').doc(bagId).get(),
                      builder: (_, bagSnap) {
                        final bagD = bagSnap.data?.data() as Map<String, dynamic>?;
                        final merchantId = bagD?['merchantId'] as String? ?? '';
                        if (merchantId.isEmpty) return const SizedBox.shrink();
                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('users').doc(merchantId).get(),
                          builder: (_, vendorSnap) {
                            if (!vendorSnap.hasData) return const SizedBox.shrink();
                            final vd = vendorSnap.data?.data() as Map<String, dynamic>?;
                            final lat = (vd?['shopLat'] as num?)?.toDouble();
                            final lng = (vd?['shopLng'] as num?)?.toDouble();
                            final shopName = vd?['shopName'] as String? ?? 'Vendor';
                            final shopAddress = vd?['shopAddress'] as String? ?? '';
                            final vendorCity = vd?['city'] as String? ?? 'Jagtial';
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: VendorLocationCard(
                                lat: lat, lng: lng,
                                shopName: shopName, address: shopAddress,
                                city: vendorCity));
                          });
                      }),
                  ],

                  // Order details
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: _kBorder),
                      borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Icon(Icons.receipt_long_rounded, color: _kGreen, size: 18),
                        const SizedBox(width: 8),
                        Text('ORDER DETAILS', style: GoogleFonts.plusJakartaSans(
                          fontSize: 11, fontWeight: FontWeight.w700,
                          letterSpacing: 0.5, color: _kTextSecondary)),
                      ]),
                      const SizedBox(height: 14),
                      FutureBuilder<QuerySnapshot>(
                        future: FirebaseFirestore.instance.collection('orders')
                            .where('orderGroupId', isEqualTo: widget.orderId).get(),
                        builder: (_, groupSnap) {
                          final groupDocs = groupSnap.data?.docs ?? [];
                          if (groupDocs.isEmpty) {
                            // Fallback: single order, group query still loading/unavailable.
                            if (bagId.isEmpty) return const SizedBox.shrink();
                            return FutureBuilder<DocumentSnapshot>(
                              future: FirebaseFirestore.instance.collection('bags').doc(bagId).get(),
                              builder: (_, snap) {
                                final bagData = snap.data?.data() as Map<String, dynamic>?;
                                final title = bagData?['title'] as String? ?? 'Surprise Bag';
                                return _infoRow('Bag', title);
                              });
                          }
                          double groupTotal = 0;
                          final rows = <Widget>[];
                          for (final d in groupDocs) {
                            final gd = d.data() as Map<String, dynamic>;
                            groupTotal += (gd['amountPaid'] as num?)?.toDouble() ?? 0;
                            final title = gd['bagTitle'] as String? ?? 'Surprise Bag';
                            final qty = (gd['quantity'] as num?)?.toInt() ?? 1;
                            rows.add(_infoRow('Bag', qty > 1 ? '$title × $qty' : title));
                          }
                          rows.add(const SizedBox(height: 8));
                          rows.add(_infoRow('Order ID', '#${widget.orderId.substring(0, widget.orderId.length >= 8 ? 8 : widget.orderId.length).toUpperCase()}'));
                          rows.add(const SizedBox(height: 8));
                          rows.add(_infoRow('Amount Paid', '₹${groupTotal.toStringAsFixed(0)}', bold: true));
                          rows.add(const SizedBox(height: 8));
                          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
                        }),
                      _infoRow('Payment', paymentMethod == 'wallet' ? '💰 Surpl Wallet' : '💳 Razorpay'),
                      const SizedBox(height: 8),
                      _infoRow('Status', isConfirmed ? '✅ Confirmed' : '⏳ Pending'),
                      if (dateStr.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _infoRow('Ordered', dateStr),
                      ],
                    ])),
                  const SizedBox(height: 14),

                  // Steps
                  if (isConfirmed) Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1A4731), Color(0xFF2D6B4F)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.all(18),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('WHAT TO DO NEXT', style: GoogleFonts.plusJakartaSans(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        letterSpacing: 0.8, color: Colors.white.withValues(alpha: 0.6))),
                      const SizedBox(height: 14),
                      _step('🚶', 'Head to the vendor during pickup time'),
                      const SizedBox(height: 10),
                      _step('📱', 'Show your 6-digit code above'),
                      const SizedBox(height: 10),
                      _step('🎁', 'Collect your bag and enjoy the surprise!'),
                      const SizedBox(height: 10),
                      _step('🌱', 'You just helped reduce food waste — thank you!'),
                    ])),

                  const SizedBox(height: 24),

                  // Actions
                  GestureDetector(
                    onTap: () => context.goNamed(MyOrdersWidget.routeName),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: _kGreen, borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(
                          color: _kGreen.withValues(alpha: 0.3),
                          blurRadius: 12, offset: const Offset(0, 4))]),
                      alignment: Alignment.center,
                      child: Text('View My Orders', style: GoogleFonts.plusJakartaSans(
                        fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)))),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => context.goNamed(HomeFeedWidget.routeName),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: _kBorder),
                        borderRadius: BorderRadius.circular(14)),
                      alignment: Alignment.center,
                      child: Text('Browse More Bags', style: GoogleFonts.plusJakartaSans(
                        fontSize: 15, fontWeight: FontWeight.w700, color: _kGreen)))),
                  const SizedBox(height: 24),
                ])),
            )),
          ]),
        );
      },
    );
  }

  Widget _step(String emoji, String text) => Row(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(emoji, style: const TextStyle(fontSize: 18)),
    const SizedBox(width: 12),
    Expanded(child: Text(text, style: GoogleFonts.plusJakartaSans(
      fontSize: 14, color: Colors.white.withValues(alpha: 0.9), height: 1.4))),
  ]);
}

// ── Vendor Location Card ──────────────────────────────────────────
class VendorLocationCard extends StatelessWidget {
  final double? lat;
  final double? lng;
  final String shopName;
  final String address;
  final String city;
  const VendorLocationCard({
    super.key,
    required this.lat,
    required this.lng,
    required this.shopName,
    required this.address,
    required this.city,
  });

  Future<void> _openDirections() async {
    final Uri uri;
    if (lat != null && lng != null) {
      uri = Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');
    } else if (address.isNotEmpty) {
      final encoded = Uri.encodeComponent('$shopName $address $city Telangana');
      uri = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=$encoded');
    } else {
      return;
    }
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // If even this fails, there's genuinely no handler — nothing else we can do.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _kBorder),
        borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(children: [
            const Icon(Icons.storefront_rounded, color: _kGreen, size: 18),
            const SizedBox(width: 8),
            Text('PICKUP LOCATION', style: GoogleFonts.plusJakartaSans(
              fontSize: 11, fontWeight: FontWeight.w700,
              letterSpacing: 0.5, color: _kTextSecondary)),
          ]),
        ),
        if (lat != null && lng != null)
          SizedBox(
            height: 180,
            width: double.infinity,
            child: gmaps.GoogleMap(
              initialCameraPosition: gmaps.CameraPosition(
                target: gmaps.LatLng(lat!, lng!),
                zoom: 16),
              markers: {
                gmaps.Marker(
                  markerId: const gmaps.MarkerId('vendor'),
                  position: gmaps.LatLng(lat!, lng!),
                  infoWindow: gmaps.InfoWindow(title: shopName)),
              },
              zoomControlsEnabled: false,
              scrollGesturesEnabled: false,
              zoomGesturesEnabled: false,
              rotateGesturesEnabled: false,
              tiltGesturesEnabled: false,
              myLocationButtonEnabled: false))
        else
          Container(
            height: 80,
            alignment: Alignment.center,
            color: _kMintBg,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.location_on_rounded, color: _kGreen, size: 20),
              const SizedBox(width: 8),
              Text('Tap Get Directions to navigate',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13, color: _kGreen, fontWeight: FontWeight.w600)),
            ])),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(shopName, style: GoogleFonts.plusJakartaSans(
              fontSize: 15, fontWeight: FontWeight.w700, color: _kTextDark)),
            if (address.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(address, style: GoogleFonts.plusJakartaSans(
                fontSize: 12, color: _kTextSecondary)),
            ],
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _openDirections,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _kGreen,
                  borderRadius: BorderRadius.circular(10)),
                alignment: Alignment.center,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.directions_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text('Get Directions', style: GoogleFonts.plusJakartaSans(
                    fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                ]))),
          ])),
      ]));
  }
}