import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '/services/location_service.dart';
import '/services/cart_service.dart';
import '/services/time_helpers.dart';

class BagDetailWidget extends StatefulWidget {
  const BagDetailWidget({Key? key, required this.bagId}) : super(key: key);
  final String bagId;
  static String get routeName => 'BagDetail';
  static String get routePath => '/bagDetail';
  @override
  State<BagDetailWidget> createState() => _BagDetailWidgetState();
}

class _BagDetailWidgetState extends State<BagDetailWidget> {
  static const _green = Color(0xFF1A4731);
  static const _amber = Color(0xFFF5A623);
  static const _lightGreen = Color(0xFFE8F5EE);

  bool _isSaved = false;
  Position? _customerPosition;
  String? _distanceText;
  bool _loadingLocation = true;
  int _qty = 1;
  final _cart = CartService();

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  DocumentReference? get _userRef => _uid != null
      ? FirebaseFirestore.instance.collection('users').doc(_uid) : null;

  @override
  void initState() {
    super.initState();
    _checkSaved();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    final pos = await LocationService.getCurrentLocation();
    if (mounted) setState(() {
      _customerPosition = pos;
      _loadingLocation = false;
    });
  }

  Future<void> _checkSaved() async {
    final ref = _userRef;
    if (ref == null) return;
    try {
      final doc = await UsersRecord.getDocument(ref).first;
      if (mounted) setState(() =>
          _isSaved = doc.savedBags.contains(widget.bagId));
    } catch (_) {}
  }

  Future<void> _toggleSave() async {
    final ref = _userRef;
    if (ref == null) return;
    final newState = !_isSaved;
    setState(() => _isSaved = newState);
    await ref.update({
      'savedBags': newState
          ? FieldValue.arrayUnion([widget.bagId])
          : FieldValue.arrayRemove([widget.bagId]),
    });
  }

  void _openNavigation(Map<String, dynamic> bagData) {
    // Use shopLat/shopLng — captured once at vendor registration and
    // auto-applied to every listing, same as shopArea/fssaiNumber.
    // Previously this read vendorLat/vendorLng, captured separately for
    // EACH individual listing — if a vendor wasn't physically at their
    // shop when creating a specific listing (or simply forgot to press
    // the capture button), that one bag would point somewhere different
    // from the vendor's other bags. This was the actual cause of
    // "location shows different from vendor location."
    final coords = LocationService.vendorCoordinates(bagData);
    final lat = coords?.$1;
    final lng = coords?.$2;
    final name = bagData['merchantName'] as String? ??
        bagData['merchantId'] as String? ?? 'Vendor';
    final city = bagData['city'] as String? ?? '';
    final address = bagData['vendorAddress'] as String? ?? '$city, Telangana';

    if (lat != null && lng != null) {
      LocationService.navigateToVendor(
          vendorLat: lat, vendorLng: lng, vendorName: name);
    } else {
      LocationService.navigateToAddress('$name, $address, $city');
    }
  }

  String? _getDistance(Map<String, dynamic> bagData) {
    if (!LocationService.freshPosition(_customerPosition)) return null;
    final coords = LocationService.vendorCoordinates(bagData);
    final lat = coords?.$1;
    final lng = coords?.$2;
    if (lat == null || lng == null) return null;
    final km = LocationService.distanceKm(
        _customerPosition!.latitude, _customerPosition!.longitude, lat, lng);
    return LocationService.formatDistance(km);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bags').doc(widget.bagId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
              backgroundColor: Color(0xFFF5F8F5),
              body: Center(child: CircularProgressIndicator(
                  color: Color(0xFF1A4731))));
        }

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        if (data == null) {
          return const Scaffold(
              backgroundColor: Color(0xFFF5F8F5),
              body: Center(child: Text('Bag not found')));
        }

        final title = data['title'] as String? ?? 'Surprise Bag';
        final listingType = data['listingType'] as String? ?? 'surplus';
        final isFreshFood = listingType == 'freshFood';
        final isHappyHour = listingType == 'happyHour';
        final image = data['image'] as String? ?? '';
        final price = (data['price'] as num?)?.toDouble() ?? 0;
        final originalPrice = (data['originalPrice'] as num?)?.toDouble() ?? 0;
        final category = data['category'] as String? ?? '';
        final description = data['description'] as String? ?? '';
        final pickupStart = data['pickupStart'] as String? ?? '';
        final pickupEnd = data['pickupEnd'] as String? ?? '';
        final availableQty = (data['availableQuantity'] as num?)?.toInt() ?? 0;
        final merchantName = data['merchantName'] as String? ?? 'Local Vendor';
        final bagCity = data['city'] as String? ?? 'Jagtial';
        final vendorAddress = data['vendorAddress'] as String? ?? bagCity;
        final fssaiNumber = data['fssaiNumber'] as String? ?? '';
        final vendorStory = data['vendorStory'] as String? ?? '';
        final merchantId = data['merchantId'] as String? ?? '';

        // The stored price includes a silent 5% GST markup (Section 9(5),
        // CGST Act - see checkout_widget.dart) that the vendor never sees
        // and never intended as part of their discount. Dividing it back
        // out here means the displayed "% off" reflects the vendor's
        // real, intended discount, not one slightly understated by an
        // invisible tax markup that has nothing to do with their pricing.
        // Price is the vendor's real, unmarked-up value directly - no
        // GST markup exists at the source anymore (GST is absorbed
        // from Surpl's commission internally, never shown here).
        final vendorRealPrice = price;
        final savings = originalPrice > vendorRealPrice
            ? ((originalPrice - vendorRealPrice) / originalPrice * 100).round() : 0;
        final isSoldOut = availableQty <= 0;
        final distanceText = _getDistance(data);
        final total = price + 5; // Once-per-checkout platform fee.


        return Scaffold(
          backgroundColor: const Color(0xFFF5F8F5),
          body: Stack(children: [
            CustomScrollView(slivers: [
              // Image header
              SliverAppBar(
                expandedHeight: 280,
                pinned: true,
                backgroundColor: _green,
                leading: Padding(
                  padding: const EdgeInsets.all(8),
                  child: GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          shape: BoxShape.circle),
                      child: const Icon(Icons.arrow_back,
                          color: Colors.white, size: 22)))),
                actions: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: GestureDetector(
                      onTap: _toggleSave,
                      child: Container(
                        decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            shape: BoxShape.circle),
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                            _isSaved ? Icons.favorite : Icons.favorite_border,
                            color: _isSaved ? _amber : Colors.white,
                            size: 22)))),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: GestureDetector(
                      onTap: () => context.pushNamed(CartWidget.routeName),
                      child: AnimatedBuilder(
                        animation: _cart,
                        builder: (context, _) => Container(
                          decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.35),
                              shape: BoxShape.circle),
                          padding: const EdgeInsets.all(8),
                          child: Stack(clipBehavior: Clip.none, children: [
                            const Icon(Icons.shopping_bag_outlined,
                                color: Colors.white, size: 22),
                            if (_cart.totalQuantity > 0)
                              Positioned(right: -6, top: -6,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                      color: _amber, shape: BoxShape.circle),
                                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                  child: Text('${_cart.totalQuantity}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: _green,
                                          fontSize: 9, fontWeight: FontWeight.w900)))),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(fit: StackFit.expand, children: [
                    image.isNotEmpty
                        ? CachedNetworkImage(imageUrl: image, fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                Container(color: _lightGreen,
                                    child: const Icon(Icons.shopping_bag,
                                        color: _green, size: 80)))
                        : Container(color: _lightGreen,
                            child: const Icon(Icons.shopping_bag,
                                color: _green, size: 80)),
                    // Gradient
                    Positioned(bottom: 0, left: 0, right: 0, height: 80,
                      child: Container(decoration: BoxDecoration(
                          gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [Colors.black.withValues(alpha: 0.5),
                                Colors.transparent])))),
                    // Savings badge
                    if (savings > 0) Positioned(top: 60, right: 16,
                      child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                              color: _amber,
                              borderRadius: BorderRadius.circular(20)),
                          child: Text('Save $savings%',
                              style: const TextStyle(color: Colors.white,
                                  fontWeight: FontWeight.w800, fontSize: 13)))),
                    // Distance badge
                    if (distanceText != null) Positioned(top: 60, left: 16,
                      child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(20)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.location_on,
                                color: Colors.white, size: 13),
                            const SizedBox(width: 4),
                            Text(distanceText,
                                style: const TextStyle(color: Colors.white,
                                    fontWeight: FontWeight.w600, fontSize: 12)),
                          ]))),
                    // Sold out overlay
                    if (isSoldOut) Container(
                        color: Colors.black.withValues(alpha: 0.55),
                        child: const Center(child: Text('SOLD OUT',
                            style: TextStyle(color: Colors.white, fontSize: 28,
                                fontWeight: FontWeight.w900, letterSpacing: 4)))),
                  ])),
              ),

              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  // Title + category
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: Text(title,
                        style: const TextStyle(fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87, height: 1.2,
                            letterSpacing: -0.3))),
                    const SizedBox(width: 8),
                    if (category.isNotEmpty) Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: _lightGreen,
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(category,
                          style: const TextStyle(color: _green,
                              fontSize: 12, fontWeight: FontWeight.w600))),
                  ]),
                  const SizedBox(height: 8),

                  // Vendor name
                  Row(children: [
                    const Icon(Icons.storefront, color: _green, size: 15),
                    const SizedBox(width: 6),
                    Text(merchantName,
                        style: const TextStyle(color: _green,
                            fontWeight: FontWeight.w600, fontSize: 14)),
                  ]),
                  const SizedBox(height: 16),

                  // Price card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.07),
                              blurRadius: 16, offset: const Offset(0, 4)),
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 4, offset: const Offset(0, 1)),
                        ]),
                    child: Row(children: [
                      Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('₹${price.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 30,
                                fontWeight: FontWeight.w900, color: _green)),
                        Row(children: [
                          if (originalPrice > price) Text(
                              '₹${originalPrice.toStringAsFixed(2)}',
                              style: TextStyle(fontSize: 14,
                                  color: Colors.grey.shade500,
                                  decoration: TextDecoration.lineThrough)),
                          if (savings > 0) ...[
                            const SizedBox(width: 6),
                            Text('Save ₹${(originalPrice - price).toStringAsFixed(2)}',
                                style: const TextStyle(color: _amber,
                                    fontWeight: FontWeight.w600, fontSize: 13)),
                          ],
                        ]),
                        const SizedBox(height: 4),
                        Text('+ ₹5 platform fee = ₹${total.toStringAsFixed(2)} total',
                            style: TextStyle(fontSize: 11,
                                color: Colors.grey.shade500)),
                      ])),
                      Column(children: [
                        Text('$availableQty',
                            style: TextStyle(fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: isSoldOut ? Colors.red : _green)),
                        Text('left', style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 12)),
                      ]),
                    ])),
                  const SizedBox(height: 12),

                  // Quantity stepper
                  if (!isSoldOut) Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8, offset: const Offset(0, 2))]),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                      const Text('Quantity', style: TextStyle(fontSize: 14,
                          fontWeight: FontWeight.w600, color: Colors.black87)),
                      Row(children: [
                        GestureDetector(
                          onTap: _qty > 1 ? () => setState(() => _qty--) : null,
                          child: Container(width: 32, height: 32,
                              decoration: BoxDecoration(color: _lightGreen,
                                  borderRadius: BorderRadius.circular(8)),
                              child: Icon(Icons.remove, size: 16,
                                  color: _qty > 1 ? _green : Colors.grey.shade400))),
                        SizedBox(width: 36, child: Text('$_qty',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16,
                                fontWeight: FontWeight.w800, color: Colors.black87))),
                        GestureDetector(
                          onTap: _qty < availableQty ? () => setState(() => _qty++) : null,
                          child: Container(width: 32, height: 32,
                              decoration: BoxDecoration(color: _lightGreen,
                                  borderRadius: BorderRadius.circular(8)),
                              child: Icon(Icons.add, size: 16,
                                  color: _qty < availableQty ? _green : Colors.grey.shade400))),
                      ]),
                    ])),
                  if (!isSoldOut) const SizedBox(height: 12),

                  // Pickup time
                  _infoCard(icon: Icons.schedule,
                      title: 'Pickup Window',
                      value: '$pickupStart – $pickupEnd'),
                  Builder(builder: (context) {
                    final ts = data['createdAt'];
                    final createdAt = ts is Timestamp ? ts.toDate() : null;
                    final label = TimeHelpers.listedAgo(createdAt);
                    if (label.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 6, left: 4),
                      child: Text(label, style: TextStyle(
                          color: Colors.grey.shade400, fontSize: 11)));
                  }),
                  const SizedBox(height: 10),

                  // Location card with navigation button
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 6)]),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: _lightGreen,
                            borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.location_on,
                            color: _green, size: 18)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(merchantName,
                            style: const TextStyle(color: Colors.black87,
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        Text(vendorAddress,
                            style: TextStyle(color: Colors.grey.shade500,
                                fontSize: 12)),
                        if (fssaiNumber.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEAF7EE),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF1A8A3E).withValues(alpha: 0.3), width: 1)),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.verified_rounded, size: 12, color: Color(0xFF1A8A3E)),
                                const SizedBox(width: 3),
                                Text('FSSAI Verified',
                                    style: const TextStyle(color: Color(0xFF1A8A3E),
                                        fontSize: 10.5, fontWeight: FontWeight.w700)),
                              ]))),
                        if (distanceText != null) Text(distanceText,
                            style: const TextStyle(color: _green,
                                fontSize: 12, fontWeight: FontWeight.w600)),
                      ])),
                      // Navigate button
                      GestureDetector(
                        onTap: () => _openNavigation(data),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                              color: _green,
                              borderRadius: BorderRadius.circular(10)),
                          child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                            Icon(Icons.directions, color: Colors.white, size: 16),
                            SizedBox(width: 4),
                            Text('Navigate',
                                style: TextStyle(color: Colors.white,
                                    fontSize: 12, fontWeight: FontWeight.w700)),
                          ])),
                      ),
                    ])),
                  const SizedBox(height: 10),

                  if (vendorStory.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200)),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('📖', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 10),
                        Expanded(child: Text(vendorStory,
                            style: TextStyle(color: Colors.grey.shade700,
                                fontSize: 13, height: 1.4, fontStyle: FontStyle.italic))),
                      ]),
                    ),
                    const SizedBox(height: 10),
                  ],

                  if (merchantId.isNotEmpty) ...[
                    _NotifyMeButton(merchantId: merchantId, merchantName: merchantName),
                    const SizedBox(height: 10),
                  ],

                  // Surprise note (surplus) or fresh-made note (Local Kitchens)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _amber.withValues(alpha: 0.3))),
                    child: Row(children: [
                      Text(isFreshFood ? '🍲' : (isHappyHour ? '⚡' : '🎁'), style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 12),
                      Expanded(child: Text(
                          isFreshFood
                              ? 'Made fresh to order at full price — this isn\'t surplus. Occasional delays are possible since it\'s cooked when you order.'
                              : isHappyHour
                                  ? 'A short-time discounted deal — same great food, temporary lower price. Grab it before time runs out!'
                                  : 'This is a surprise bag! Exact contents vary but the value is always higher than what you pay.',
                          style: const TextStyle(color: Color(0xFF7B4F00),
                              fontSize: 13, height: 1.4))),
                    ])),
                  const SizedBox(height: 16),

                  // Description
                  if (description.isNotEmpty) ...[
                    const Text('About this bag',
                        style: TextStyle(fontSize: 16,
                            fontWeight: FontWeight.w700, color: Colors.black87)),
                    const SizedBox(height: 8),
                    Text(description, style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 14, height: 1.6)),
                    const SizedBox(height: 16),
                  ],

                  // How it works
                  const Text('How it works',
                      style: TextStyle(fontSize: 16,
                          fontWeight: FontWeight.w700, color: Colors.black87)),
                  const SizedBox(height: 12),
                  _step('1', 'Add to cart & pay online now'),
                  _step('2', 'Tap Navigate to get directions to the shop'),
                  _step('3', 'Show your 6-digit pickup code at the counter'),
                  _step('4', isFreshFood
                      ? 'Collect your freshly made order — enjoy! 🍲'
                      : isHappyHour
                          ? 'Collect your order at the discounted price — enjoy! ⚡'
                          : 'Enjoy the surprise — you\'ve reduced food waste! 🌱'),
                  const SizedBox(height: 100),
                ]))),
            ]),

            // Bottom CTA
            Positioned(bottom: 0, left: 0, right: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(16, 12, 16,
                    16 + MediaQuery.of(context).padding.bottom),
                decoration: BoxDecoration(color: Colors.white,
                    boxShadow: [BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 16, offset: const Offset(0, -4))]),
                child: Row(children: [
                  // Navigate button (secondary)
                  GestureDetector(
                    onTap: () => _openNavigation(data),
                    child: Container(
                      width: 54, height: 54,
                      decoration: BoxDecoration(
                          color: _lightGreen,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _green.withValues(alpha: 0.3))),
                      child: const Icon(Icons.directions, color: _green, size: 24)),
                  ),
                  const SizedBox(width: 12),
                  // Buy now button (primary) — adds to cart, then goes
                  // straight to checkout instead of requiring a separate
                  // "view cart" + "proceed to checkout" tap each.
                  Expanded(child: GestureDetector(
                    onTap: isSoldOut ? null : () {
                      _cart.addItem(CartItem(
                        bagId: widget.bagId,
                        merchantId: data['merchantId'] ?? '',
                        merchantName: merchantName,
                        title: title,
                        image: image,
                        price: price,
                        originalPrice: originalPrice,
                        pickupStart: pickupStart,
                        pickupEnd: pickupEnd,
                        quantity: _qty,
                        availableQuantity: availableQty,
                        listingType: data['listingType'] as String? ?? 'surplus',
                      ));
                      context.pushNamed(CheckoutWidget.routeName);
                    },
                    child: Container(
                      height: 54,
                      decoration: BoxDecoration(
                          color: isSoldOut ? Colors.grey.shade400 : _amber,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: isSoldOut ? [] : [BoxShadow(
                              color: _amber.withValues(alpha: 0.4),
                              blurRadius: 12, offset: const Offset(0, 4))]),
                      child: Center(child: Text(
                          isSoldOut ? 'Sold Out'
                              : 'Book Now — ₹${(price * _qty).toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.white,
                              fontSize: 16, fontWeight: FontWeight.w800,
                              letterSpacing: -0.2)))),
                  )),
                ])),
            ),
          ]),
        );
      },
    );
  }

  Widget _infoCard({required IconData icon,
    required String title, required String value}) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)]),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: _lightGreen,
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: _green, size: 18)),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(color: Colors.grey.shade500,
                fontSize: 11, fontWeight: FontWeight.w500)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(color: Colors.black87,
                fontSize: 14, fontWeight: FontWeight.w600)),
          ]),
        ]));

  Widget _step(String num, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 24, height: 24,
          decoration: const BoxDecoration(color: _green, shape: BoxShape.circle),
          child: Center(child: Text(num,
              style: const TextStyle(color: Colors.white,
                  fontSize: 12, fontWeight: FontWeight.w700)))),
      const SizedBox(width: 10),
      Expanded(child: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(text, style: TextStyle(
              color: Colors.grey.shade700, fontSize: 14, height: 1.4)))),
    ]));
}

// Lets a customer subscribe to a specific vendor - stored as an array on
// their own user document, so a Cloud Function can notify everyone
// subscribed to a vendor the moment that vendor lists a new bag. This is
// a per-vendor loyalty signal, distinct from the general "bags near you"
// proximity notifications - a customer's favorite shop, not just anything
// nearby.
class _NotifyMeButton extends StatefulWidget {
  final String merchantId;
  final String merchantName;
  const _NotifyMeButton({required this.merchantId, required this.merchantName});

  @override
  State<_NotifyMeButton> createState() => _NotifyMeButtonState();
}

class _NotifyMeButtonState extends State<_NotifyMeButton> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final subscribed = ((data?['subscribedVendors'] as List?) ?? [])
            .contains(widget.merchantId);

        return GestureDetector(
          onTap: _loading ? null : () async {
            setState(() => _loading = true);
            final ref = FirebaseFirestore.instance.collection('users').doc(uid);
            try {
              await ref.set({
                'subscribedVendors': subscribed
                    ? FieldValue.arrayRemove([widget.merchantId])
                    : FieldValue.arrayUnion([widget.merchantId]),
              }, SetOptions(merge: true));
            } finally {
              if (mounted) setState(() => _loading = false);
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: subscribed ? const Color(0xFFEAF7EE) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: subscribed ? const Color(0xFF1A8A3E) : Colors.grey.shade300)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(subscribed ? '🔔' : '🔕', style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(
                  subscribed
                      ? 'Notified when ${widget.merchantName} lists again'
                      : 'Notify me when ${widget.merchantName} lists again',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: subscribed ? const Color(0xFF1A8A3E) : Colors.grey.shade700)),
            ]),
          ),
        );
      },
    );
  }
}
