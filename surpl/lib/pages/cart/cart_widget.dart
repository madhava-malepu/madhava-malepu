import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '/services/cart_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'cart_model.dart';
export 'cart_model.dart';

const _kGreen = Color(0xFF1A4731);
const _kGreenDark = Color(0xFF0D2A1B);
const _kAmber = Color(0xFFF5A623);
const _kBgLight = Color(0xFFF4F7F4);
const _kBorder = Color(0xFFD4E8D4);
const _kTextDark = Color(0xFF0D1F12);
const _kTextSecondary = Color(0xFF4D6B57);
const _kMintBg = Color(0xFFE6F4ED);

class CartWidget extends StatefulWidget {
  const CartWidget({super.key});
  static String routeName = 'Cart';
  static String routePath = '/cart';
  @override
  State<CartWidget> createState() => _CartWidgetState();
}

class _CartWidgetState extends State<CartWidget> {
  late CartModel _model;
  final _cart = CartService();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => CartModel());
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Clear cart?', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
        content: Text('This will remove all bags from your cart.',
            style: GoogleFonts.plusJakartaSans(color: _kTextSecondary)),
        actions: [
          TextButton(onPressed: () => context.pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => context.pop(true),
            child: Text('Clear', style: GoogleFonts.plusJakartaSans(color: Colors.red.shade600, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed == true) _cart.clear();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _cart,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: _kBgLight,
          body: _cart.isEmpty ? _emptyState(context) : _cartBody(context),
        );
      },
    );
  }

  Widget _header({required Widget trailing}) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_kGreenDark, _kGreen],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 16, 20),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => context.pop(),
              ),
              Expanded(
                child: Text('Your Cart',
                    style: GoogleFonts.plusJakartaSans(
                        color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20,
                        letterSpacing: -0.3)),
              ),
              trailing,
            ]),
          ),
        ),
      );

  Widget _emptyState(BuildContext context) => Column(children: [
        _header(trailing: const SizedBox(width: 48)),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_kMintBg, _kMintBg.withValues(alpha: 0.5)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.shopping_bag_outlined, color: _kGreen, size: 44),
                ),
                const SizedBox(height: 20),
                Text('Your cart is empty',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 18, fontWeight: FontWeight.w800, color: _kTextDark)),
                const SizedBox(height: 6),
                Text('Add a surprise bag or a fresh snack to get started',
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, color: _kTextSecondary)),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () => context.goNamed(HomeFeedWidget.routeName),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [_kGreenDark, _kGreen]),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: _kGreen.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    child: Text('Browse bags',
                        style: GoogleFonts.plusJakartaSans(
                            color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ]);

  Widget _cartBody(BuildContext context) {
    final items = _cart.items;
    final vendorName = items.isNotEmpty ? items.first.merchantName : '';
    const platformFee = 5.0; // Once per checkout, for every listing type.
    final subtotal = _cart.subtotal;
    final estimatedTotal = subtotal + platformFee;
    // Price is the vendor's real value directly - no GST markup exists
    // at the source anymore, so no division is needed here either.
    final totalSavings = items.fold<double>(0, (sum, i) =>
        sum + ((i.originalPrice - i.price).clamp(0, double.infinity) * i.quantity));

    return Column(
      children: [
        _header(
          trailing: GestureDetector(
            onTap: _confirmClear,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
              child: Text('Clear', style: GoogleFonts.plusJakartaSans(
                  color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            children: [
              // Vendor header + savings badge
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: _kBorder),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))]),
                child: Column(children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(color: _kMintBg, borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.storefront_rounded, color: _kGreen, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(vendorName,
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 15, fontWeight: FontWeight.w800, color: _kTextDark)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: _kBgLight, borderRadius: BorderRadius.circular(20)),
                      child: Text('${_cart.totalQuantity} item${_cart.totalQuantity == 1 ? '' : 's'}',
                          style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w700, color: _kTextSecondary)),
                    ),
                  ]),
                  if (totalSavings > 0) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [_kAmber.withValues(alpha: 0.15), _kAmber.withValues(alpha: 0.05)]),
                          borderRadius: BorderRadius.circular(10)),
                      child: Row(children: [
                        const Text('🎉', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text('You\'re saving ₹${totalSavings.toStringAsFixed(2)} on this order!',
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF8A5A00))),
                        ),
                      ]),
                    ),
                  ],
                ]),
              ),
              const SizedBox(height: 14),

              ...items.map((item) => _CartLineItem(item: item)),

              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _kAmber.withValues(alpha: 0.3))),
                child: Row(children: [
                  const Icon(Icons.info_outline_rounded, color: _kAmber, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                        'All items in one cart are picked up together from $vendorName with a single pickup code.',
                        style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF7B4F00))),
                  ),
                ]),
              ),
            ],
          ),
        ),

        // Bottom summary + CTA
        Container(
          padding: EdgeInsets.fromLTRB(18, 18, 18, 16 + MediaQuery.of(context).padding.bottom),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.09), blurRadius: 24, offset: const Offset(0, -8)),
              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, -2)),
            ],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Subtotal', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: _kTextSecondary)),
              Text('₹${subtotal.toStringAsFixed(2)}',
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: _kTextDark)),
            ]),
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Platform fee', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: _kTextSecondary.withValues(alpha: 0.8))),
              Text('₹5', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: _kTextSecondary)),
            ]),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Estimated total', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: _kTextDark, letterSpacing: -0.2)),
              Text('₹${estimatedTotal.toStringAsFixed(2)}',
                  style: GoogleFonts.plusJakartaSans(fontSize: 19, fontWeight: FontWeight.w900, color: _kGreen)),
            ]),
            const SizedBox(height: 6),
            Text('Any discounts are applied at checkout',
                style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: _kTextSecondary.withValues(alpha: 0.7))),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () => context.pushNamed(CheckoutWidget.routeName),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 17),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_kGreenDark, _kGreen]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: _kGreen.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))],
                ),
                alignment: Alignment.center,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('Proceed to Checkout',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 15.5, fontWeight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                ]),
              ),
            ),
          ]),
        ),
      ],
    );
  }
}

/// A single cart row. Wraps its own StreamBuilder on the live bag doc so
/// stock changes made by other customers are reflected immediately —
/// if someone else buys the remaining stock while this bag sits in the
/// cart, the stepper's max is clamped down live and a warning is shown.
class _CartLineItem extends StatelessWidget {
  final CartItem item;
  const _CartLineItem({required this.item});

  @override
  Widget build(BuildContext context) {
    final cart = CartService();
    final isFreshFood = item.listingType == 'freshFood';
    final isHappyHour = item.listingType == 'happyHour';
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('bags').doc(item.bagId).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final liveAvailable = (data?['availableQuantity'] as num?)?.toInt() ?? item.availableQuantity;
        final soldOut = liveAvailable <= 0;

        if (liveAvailable != item.availableQuantity) {
          item.availableQuantity = liveAvailable;
          if (item.quantity > liveAvailable && liveAvailable > 0) {
            WidgetsBinding.instance.addPostFrameCallback((_) =>
                cart.updateQuantity(item.bagId, liveAvailable));
          }
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: soldOut ? Colors.red.shade200 : _kBorder),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 1))]),
          child: Row(children: [
            Stack(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: item.image.isNotEmpty
                    ? CachedNetworkImage(imageUrl: item.image, width: 60, height: 60, fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _thumbPlaceholder(isFreshFood))
                    : _thumbPlaceholder(isFreshFood),
              ),
              if (isFreshFood || isHappyHour)
                Positioned(
                  bottom: -2, right: -2,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(color: _kAmber, shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5)),
                    child: Text(isFreshFood ? '🥟' : '⚡', style: const TextStyle(fontSize: 9)),
                  ),
                ),
            ]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5, fontWeight: FontWeight.w700, color: _kTextDark)),
                const SizedBox(height: 3),
                Row(children: [
                  Text('₹${item.price.toStringAsFixed(2)}',
                      style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800, color: _kGreen)),
                  if (item.originalPrice > item.price) ...[
                    const SizedBox(width: 6),
                    Text('₹${item.originalPrice.toStringAsFixed(2)}',
                        style: GoogleFonts.plusJakartaSans(fontSize: 11, color: _kTextSecondary,
                            decoration: TextDecoration.lineThrough)),
                  ],
                  Text(' each', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: _kTextSecondary)),
                ]),
                if (soldOut) ...[
                  const SizedBox(height: 4),
                  Text('Sold out — remove from cart',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 11, fontWeight: FontWeight.w600, color: Colors.red.shade600)),
                ] else if (item.quantity >= liveAvailable) ...[
                  const SizedBox(height: 4),
                  Text('Only $liveAvailable left',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, color: _kAmber, fontWeight: FontWeight.w600)),
                ],
              ]),
            ),
            const SizedBox(width: 8),
            soldOut
                ? GestureDetector(
                    onTap: () => cart.removeItem(item.bagId),
                    child: Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
                      child: Icon(Icons.delete_outline, color: Colors.red.shade600, size: 18),
                    ),
                  )
                : _stepper(cart, liveAvailable),
          ]),
        );
      },
    );
  }

  Widget _thumbPlaceholder(bool isFreshFood) => Container(
      width: 60, height: 60, color: _kMintBg,
      child: Icon(isFreshFood ? Icons.restaurant_rounded : Icons.shopping_bag, color: _kGreen, size: 24));

  Widget _stepper(CartService cart, int liveAvailable) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(color: _kMintBg, borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _stepBtn(Icons.remove, () => cart.updateQuantity(item.bagId, item.quantity - 1)),
          Container(
            constraints: const BoxConstraints(minWidth: 26),
            alignment: Alignment.center,
            child: Text('${item.quantity}',
                style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800, color: _kTextDark)),
          ),
          _stepBtn(Icons.add, item.quantity >= liveAvailable ? null : () => cart.updateQuantity(item.bagId, item.quantity + 1)),
        ]),
      );

  Widget _stepBtn(IconData icon, VoidCallback? onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(7),
          child: Icon(icon, size: 15, color: onTap == null ? _kTextSecondary.withValues(alpha: 0.35) : _kGreen),
        ),
      );
}
