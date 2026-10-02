import '/auth/firebase_auth/auth_util.dart';
import '/services/notification_service.dart';
import '/services/ecosystem_service.dart';
import '/services/cart_service.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'checkout_model.dart';
export 'checkout_model.dart';

const _kGreen = Color(0xFF1A4731);
const _kAmber = Color(0xFFF5A623);
const _kBgLight = Color(0xFFF4F7F4);
const _kBorder = Color(0xFFD4E8D4);
const _kTextDark = Color(0xFF0D1F12);
const _kTextSecondary = Color(0xFF4D6B57);
const _kMintBg = Color(0xFFE6F4ED);

const double _kPlatformFee = 5.0; // flat, per checkout (not per bag)
class CheckoutWidget extends StatefulWidget {
  // bagId kept for back-compat deep links (adds that single bag to cart then checks out).
  const CheckoutWidget({super.key, this.bagId});
  final String? bagId;
  static String routeName = 'Checkout';
  static String routePath = '/checkout';
  @override
  State<CheckoutWidget> createState() => _CheckoutWidgetState();
}

/// Thrown from the reservation transaction when a bag no longer has enough
/// stock — surfaced to the user so they can adjust their cart.
class _InsufficientStockException implements Exception {
  final String bagTitle;
  final int available;
  _InsufficientStockException(this.bagTitle, this.available);
}

class _CheckoutWidgetState extends State<CheckoutWidget> {
  late CheckoutModel _model;
  final _cart = CartService();
  String _selectedPayment = 'razorpay';
  bool _paying = false;
  String? _errorMessage;
  double _walletBalance = 0;
  double _referralDiscountPct = 0;
  // FIX: customers are created with an empty name by default and only
  // ever get one filled in if they manually visit Edit Profile - which
  // is rare. That's why vendors and admin were almost always seeing
  // "Customer" instead of a real name. Checkout is the natural point to
  // capture it, since the customer is already engaged here - pre-filled
  // if already known, and saved back to their profile so future orders
  // have it too.
  final _nameController = TextEditingController();

  late Razorpay _razorpay;
  // Reserved order docs created before Razorpay opens; rolled back on failure.
  List<String>? _pendingOrderIds;
  String? _pendingOrderGroupId;
  String? _razorpayOrderId;
  int? _authorizedAmountPaise;
  String? _checkoutRequestId;
  String? _checkoutFingerprint;
  bool _checkoutAlreadyConfirmed = false;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => CheckoutModel());
    _setupRazorpay();
    _loadWallet();
    // Back-compat: deep link with a single bagId adds it to the cart once.
    // This MUST run from initState (guaranteed to run exactly once), not
    // from build() — build() can run multiple times in quick succession
    // before the first scheduled add completes, and each run would see
    // "not in cart yet" and schedule its own add, silently doubling the
    // quantity added.
    if (widget.bagId != null && widget.bagId!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (_cart[widget.bagId!] != null) return; // already there, don't re-add
        final doc = await FirebaseFirestore.instance.collection('bags').doc(widget.bagId).get();
        final d = doc.data();
        if (d == null || !mounted) return;
        final merchantId = d['merchantId'] ?? '';
        final merchantName = d['merchantName'] ?? 'Local Vendor';
        // FIX: this deep-link path had the exact same gap as
        // bag_detail's Buy Now button - a customer opening a deep link
        // for a different vendor's bag while items from another vendor
        // were already in the cart would silently end up with a
        // multi-vendor cart, right on the checkout screen itself. Same
        // confirm-or-cancel dialog, same underlying cart rule.
        if (_cart.hasConflictWith(merchantId)) {
          final existingName = _cart.items.isNotEmpty
              ? _cart.items.first.merchantName
              : 'another vendor';
          final proceed = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Start a new order?'),
              content: Text(
                  'Your cart has items from $existingName. Since Surpl pickup '
                  'is from one shop at a time, adding this item will clear '
                  'your current cart and start a new order from $merchantName.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Clear Cart & Add')),
              ],
            ),
          );
          if (proceed != true || !mounted) return;
          _cart.clear();
        }
        _cart.addItem(CartItem(
          bagId: widget.bagId!,
          merchantId: merchantId,
          merchantName: merchantName,
          title: d['title'] ?? 'Surprise Bag',
          image: d['image'] ?? '',
          price: (d['price'] as num?)?.toDouble() ?? 0,
          originalPrice: (d['originalPrice'] as num?)?.toDouble() ?? 0,
          pickupStart: d['pickupStart'] ?? '',
          pickupEnd: d['pickupEnd'] ?? '',
          quantity: 1,
          availableQuantity: (d['availableQuantity'] as num?)?.toInt() ?? 1,
          listingType: d['listingType'] as String? ?? 'surplus',
        ));
        setState(() {});
      });
    }
  }

  void _setupRazorpay() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    _model.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadWallet() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users').doc(currentUserUid).get();
      final bal = (doc.data()?['walletBalance'] as num?)?.toDouble() ?? 0;
      final disc = (doc.data()?['firstOrderDiscountPct'] as num?)?.toDouble() ?? 0;
      // Prefer the name already saved on their profile; fall back to
      // whatever Firebase Auth itself has (populated for Google/Apple
      // sign-in, but not phone/OTP, which is why this is usually empty).
      final existingName = (doc.data()?['name'] as String?)?.trim();
      if (mounted) setState(() {
        _walletBalance = bal;
        _referralDiscountPct = disc;
        if (existingName != null && existingName.isNotEmpty) {
          _nameController.text = existingName;
        } else if (currentUserDisplayName.isNotEmpty) {
          _nameController.text = currentUserDisplayName;
        }
      });
    } catch (_) {}
  }


  double get _subtotal => _cart.subtotal;
  double get _referralDiscount =>
      _referralDiscountPct > 0 ? ((_subtotal * 100).round() * _referralDiscountPct / 100).round() / 100 : 0.0;
  double get _total =>
      (_subtotal + _kPlatformFee - _referralDiscount).clamp(1.0, double.infinity);

  String _formatPhoneForRazorpay(String phone) {
    String digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('91') && digits.length == 12) digits = digits.substring(2);
    if (digits.startsWith('0') && digits.length == 11) digits = digits.substring(1);
    return digits.length == 10 ? digits : '';
  }

  /// Atomically checks stock for every cart item and creates one 'pending'
  /// (or 'confirmed', for wallet) order doc per item, decrementing
  /// availableQuantity in the same transaction. All items share one
  /// orderGroupId; items are grouped by vendor with one pickupCode per
  /// vendor so pickup at each shop uses a single code.
  Future<List<String>> _reserveStockAndCreateOrders({
    required List<CartItem> items,
    required bool isWallet,
    required double total,
    required double referralDiscount,
  }) async {
    final fingerprint = items.map((i) => '${i.bagId}:${i.quantity}').join('|') + ':$isWallet';
    if (_checkoutFingerprint != fingerprint) {
      _checkoutRequestId = FirebaseFirestore.instance.collection('orders').doc().id;
      _checkoutFingerprint = fingerprint;
    }
    final result = await FirebaseFunctions.instanceFor(region: 'asia-south1')
        .httpsCallable('createCheckout').call({
      'requestId': _checkoutRequestId,
      'items': items.map((i) => {'bagId': i.bagId, 'quantity': i.quantity}).toList(),
      'paymentMethod': isWallet ? 'wallet' : 'razorpay',
      'customerName': _nameController.text.trim(),
      'maxAmountPaise': (total * 100).round(),
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    _pendingOrderGroupId = data['orderGroupId'] as String;
    _checkoutAlreadyConfirmed = data['status'] == 'confirmed';
    _razorpayOrderId = data['razorpayOrderId'] as String?;
    _authorizedAmountPaise = (data['amountPaise'] as num).toInt();
    return List<String>.from(data['orderIds'] as List);
  }

  void _onSuccess(PaymentSuccessResponse response) async {
    final orderIds = _pendingOrderIds;
    if (orderIds == null) return;
    try {
      // SECURITY FIX: previously wrote status:'confirmed' directly to
      // Firestore here, trusting the client-side Razorpay success
      // callback alone. That's exactly the gap that let an order be
      // marked confirmed with no real payment verification at all -
      // confirmed as the likely reason real orders were missing from
      // the live Razorpay dashboard. Now calling a Cloud Function that
      // genuinely checks this payment ID against Razorpay's own servers
      // before writing anything, server-side, via the Admin SDK.
      final functions = FirebaseFunctions.instanceFor(region: 'asia-south1');
      final callable = functions.httpsCallable('verifyPaymentAndConfirmOrder');
      await callable.call({
        'orderIds': orderIds,
        'razorpayPaymentId': response.paymentId ?? '',
      });
      try { await EcosystemService.recordConfirmedOrders(orderIds); } catch (_) {}

      try {
        final merchantIds = _cart.merchantIds;
        final total = _total;
        // pickupCodeByMerchant is scoped to _reserveStockAndCreateOrders
        // and isn't accessible here in _onSuccess — fetch the codes back
        // from the orders that were just created instead, same safe
        // pattern already used for the wallet payment path below.
        final codeByMerchant = <String, String>{};
        for (final oid in orderIds) {
          final doc = await FirebaseFirestore.instance.collection('orders').doc(oid).get();
          final d = doc.data();
          if (d != null) {
            final mid = d['merchantId'] as String?;
            final code = d['pickupCode'] as String?;
            if (mid != null && code != null) codeByMerchant[mid] = code;
          }
        }
        for (final m in merchantIds) {
          final bagTitles = _cart.items.where((i) => i.merchantId == m).map((i) => i.title).join(', ');
          await NotificationService.notifyVendorNewOrder(
            vendorUid: m,
            bagTitle: bagTitles,
            amount: total,
            orderId: orderIds.first,
            pickupCode: codeByMerchant[m] ?? '',
          );
        }
      } catch (_) {}

      // FIX: referral reward and loyalty count are best-effort side
      // effects, not core to the order - by this point the payment has
      // ALREADY been verified server-side and the order is genuinely
      // confirmed with a real pickup code sitting on it. Previously
      // these were awaited unprotected, so if either threw for ANY
      // reason (a missing referrer, a transient Firestore error, etc.)
      // the catch block below fired and showed the customer a
      // misleading "order save failed" message - and they were never
      // navigated to see their already-confirmed order or its pickup
      // code at all. Wrapping them means their failure can never block
      // the one thing that actually matters here.
      try {
        await _handleReferralReward();
      } catch (e) {
        // ignore - best-effort only.
      }
      try {
        await _incrementLoyaltyCount();
      } catch (e) {
        // ignore - best-effort only.
      }
      final groupId = _pendingOrderGroupId ?? orderIds.first;
      _cart.clear();
      _pendingOrderIds = null;
      _pendingOrderGroupId = null;
      if (mounted) {
        context.goNamed(OrderConfirmationWidget.routeName,
            queryParameters: {'orderId': serializeParam(groupId, ParamType.String)}.withoutNulls);
      }
    } catch (e) {
      if (mounted) setState(() {
        _paying = false;
        _errorMessage = 'Payment done but order save failed. Contact support at hello@surpl.in';
      });
    }
  }

  Future<void> _incrementLoyaltyCount() async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(currentUserUid)
          .set({'completedOrderCount': FieldValue.increment(1)}, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> _handleReferralReward() async {
    // Discount consumption and referral credit are server-authoritative.
  }

  // FIX (critical, real financial harm): both handlers below previously
  // called _rollbackReservation immediately - deleting the order with
  // zero server-side verification, purely trusting Razorpay's
  // client-side error/dismiss callback. That callback is well-documented
  // to fire even when a payment genuinely succeeded on Razorpay's
  // servers (common with UPI apps losing focus mid-payment). Once
  // deleted, there was no order left for the safety-net cleanup to ever
  // find and confirm - a customer's real payment could vanish with no
  // recovery path. This now checks the actual, server-verified status
  // first, and only touches the order based on what Razorpay's own
  // records genuinely show.
  Future<void> _handlePaymentNotConfirmed(String fallbackErrorMsg) async {
    final groupId = _pendingOrderGroupId;
    final orderIds = _pendingOrderIds;

    if (groupId == null || orderIds == null) {
      if (mounted) setState(() { _paying = false; _errorMessage = fallbackErrorMsg; });
      return;
    }

    try {
      final functions = FirebaseFunctions.instanceFor(region: 'asia-south1');
      final callable = functions.httpsCallable('checkOrderGroupPaymentStatus');
      final result = await callable.call({'orderGroupId': groupId});
      final status = (result.data as Map)['status'] as String?;

      if (status == 'confirmed') {
        _cart.clear();
        _pendingOrderIds = null;
        _pendingOrderGroupId = null;
        // The payment actually succeeded despite Razorpay's SDK
        // reporting an error - route to success, not a false failure.
        if (mounted) {
          setState(() { _paying = false; });
          context.goNamed(OrderConfirmationWidget.routeName,
              queryParameters: {'orderId': serializeParam(groupId, ParamType.String)}.withoutNulls);
        }
        return;
      }

      if (status == 'pending') {
        // Genuinely uncertain still - Razorpay hasn't resolved this yet
        // and no evidence of failure exists. Never delete or cancel on
        // uncertainty; the scheduled safety net keeps checking. Tell the
        // customer honestly rather than showing a scary false failure.
        if (mounted) setState(() {
          _paying = false;
          _errorMessage = "We're verifying your payment - if it went through, "
              "your order will appear in My Orders within a few minutes. "
              "Please don't pay again.";
        });
        return;
      }

      // status == 'cancelled': the server function has already updated
      // the order and restored the bag's stock itself - doing so again
      // here would double-increment availableQuantity.
      // status == 'not_found': the order is already gone but its stock
      // reservation may never have been released - release it now.
      if (status == 'not_found') {
        // Missing verification is not proof that inventory can be released.
      }
      if (mounted) setState(() { _paying = false; _errorMessage = fallbackErrorMsg; });
    } catch (e) {
      // Couldn't even reach our own server to check - safest default is
      // to leave the order exactly as-is (pending) rather than guess.
      // The scheduled safety net will resolve it once connectivity is
      // back, same as if this check had never run.
      if (mounted) setState(() {
        _paying = false;
        _errorMessage = "Couldn't verify your payment status. If it went "
            "through, check My Orders in a few minutes before trying again.";
      });
    }
  }

  void _onError(PaymentFailureResponse response) async {
    String errorMsg = 'Payment failed. Please try again.';
    final code = response.code ?? 0;
    if (code == Razorpay.NETWORK_ERROR) {
      errorMsg = 'No internet connection. Please check your network and try again.';
    } else if (code == Razorpay.INVALID_OPTIONS) {
      errorMsg = 'Payment setup error: ${response.message ?? 'invalid options'}. Please contact support.';
    } else if (response.message?.contains('cancelled') == true ||
               response.message?.contains('dismissed') == true) {
      errorMsg = 'Payment cancelled.';
    } else {
      errorMsg = 'Payment failed (code $code): ${response.message ?? 'unknown error'}';
    }
    await _handlePaymentNotConfirmed(errorMsg);
  }

  void _onExternalWallet(ExternalWalletResponse response) async {
    await _handlePaymentNotConfirmed('External wallet not supported. Please use UPI or card.');
  }

  Future<void> _pay() async {
    if (_paying || _cart.isEmpty) return;
    // CRITICAL FIX: this was the actual root cause of the permission-denied
    // checkout failures — not the Firestore rules, which were repeatedly
    // fixed and reverified correct. currentUserUid (used everywhere below
    // to write 'customerId') silently returns '' when nobody is signed
    // in, instead of throwing or returning null. Nothing here ever
    // checked that. If a customer somehow reached this screen without a
    // completed Firebase Auth session (dropped OTP, a stale deep link,
    // browser back/forward on the web build — nav.dart's requireAuth
    // flag exists but is never set to true on any route), the order
    // write would set customerId: '' and ALWAYS fail security rules,
    // since '' can never equal request.auth.uid. This is the exact same
    // guard pattern already proven correct elsewhere in this codebase —
    // favourites_widget.dart and saved_bags_widget.dart both check
    // FirebaseAuth.instance.currentUser?.uid == null before proceeding.
    // Checkout just never adopted it.
    if (FirebaseAuth.instance.currentUser?.uid == null) {
      setState(() => _errorMessage =
          'Please sign in to place your order — you\'ll need to log in first.');
      if (mounted) {
        context.goNamed(OnboardingLoginWidget.routeName);
      }
      return;
    }
    if (_nameController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter your name so the vendor knows who to expect.');
      return;
    }
    setState(() { _paying = true; _errorMessage = null; });

    final items = List<CartItem>.from(_cart.items);
    final total = _total;
    final referralDiscount = _referralDiscount;
    final isWallet = _selectedPayment == 'wallet';

    // Enforce pickup time windows — orders can only be placed while the
    // bag's pickup window is actually open, not before it starts or after
    // it ends. Fetched fresh from Firestore since CartItem only carries
    // display strings, not the actual timestamps.
    final nowMillis = DateTime.now().millisecondsSinceEpoch;
    // FIX: these were fetched one at a time in a sequential loop, each
    // await waiting on the previous - for a multi-item cart on a slow
    // connection, that's real, avoidable delay stacking up before
    // Razorpay's payment screen even opens. Fetching them all at once
    // cuts this to a single round-trip's worth of wait time regardless
    // of cart size, with identical checks and error messages.
    final bagDocs = await Future.wait(
      items.map((item) async {
        try {
          return await FirebaseFirestore.instance.collection('bags').doc(item.bagId).get();
        } catch (_) {
          return null;
        }
      }),
    );
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final doc = bagDocs[i];
      if (doc == null) continue;
      try {
        final d = doc.data();
        if (d == null) continue;
        final startMillis = (d['pickupStartMillis'] as num?)?.toInt() ?? 0;
        final endMillis = (d['pickupEndMillis'] as num?)?.toInt() ?? 0;
        if (endMillis > 0 && nowMillis > endMillis) {
          setState(() {
            _paying = false;
            _errorMessage = '"${item.title}" pickup window has already ended — please remove it from your cart.';
          });
          return;
        }
        if (startMillis > 0 && nowMillis < startMillis) {
          final startTime = DateTime.fromMillisecondsSinceEpoch(startMillis);
          final h = startTime.hour > 12 ? startTime.hour - 12 : (startTime.hour == 0 ? 12 : startTime.hour);
          final m = startTime.minute.toString().padLeft(2, '0');
          final period = startTime.hour >= 12 ? 'PM' : 'AM';
          setState(() {
            _paying = false;
            _errorMessage = '"${item.title}" pickup doesn\'t open until $h:$m $period — you can\'t order yet.';
          });
          return;
        }
      } catch (_) {
        // If the check itself fails, don't block checkout over it —
        // fail open here, stock/other checks still apply downstream.
      }
    }

    if (isWallet && _walletBalance < total) {
      setState(() { _paying = false; _errorMessage = 'Insufficient wallet balance. Please use Razorpay.'; });
      return;
    }

    List<String> orderIds;
    try {
      orderIds = await _reserveStockAndCreateOrders(
        items: items, isWallet: isWallet, total: total, referralDiscount: referralDiscount);
    } on FirebaseFunctionsException catch (e) {
      if (e.details is Map && (e.details as Map)['reservationReleased'] == true) {
        _checkoutFingerprint = null;
      }
      if (mounted) setState(() {
        _paying = false;
        _errorMessage = e.message ?? 'Could not prepare checkout. Please retry.';
      });
      return;
    } on _InsufficientStockException catch (e) {
      setState(() {
        _paying = false;
        _errorMessage = e.available <= 0
            ? '"${e.bagTitle}" just sold out — please remove it from your cart.'
            : 'Only ${e.available} left of "${e.bagTitle}" — please update the quantity in your cart.';
      });
      return;
    } catch (e) {
      setState(() { _paying = false; _errorMessage = 'Checkout failed: $e'; });
      return;
    }

    // Best-effort: remember this name on the customer's own profile so
    // it's already filled in next time, on this device or any other -
    // never blocks checkout if it fails for any reason.
    FirebaseFirestore.instance.collection('users').doc(currentUserUid)
        .update({'name': _nameController.text.trim()}).catchError((_) {});

    if (isWallet || _checkoutAlreadyConfirmed) {
      try {
        // Fetch the pickup codes that were just written to these orders,
        // keyed by merchant, so the vendor notification can show the
        // code directly rather than requiring an extra tap to find it.
        final codeByMerchant = <String, String>{};
        for (final oid in orderIds) {
          final doc = await FirebaseFirestore.instance.collection('orders').doc(oid).get();
          final d = doc.data();
          if (d != null) {
            final mid = d['merchantId'] as String?;
            final code = d['pickupCode'] as String?;
            if (mid != null && code != null) codeByMerchant[mid] = code;
          }
        }
        for (final m in items.map((i) => i.merchantId).toSet()) {
          final titles = items.where((i) => i.merchantId == m).map((i) => i.title).join(', ');
          await NotificationService.notifyVendorNewOrder(
            vendorUid: m, bagTitle: titles, amount: total, orderId: orderIds.first,
            pickupCode: codeByMerchant[m] ?? '');
        }
      } catch (_) {}
      try { await EcosystemService.recordConfirmedOrders(orderIds); } catch (_) {}
      // Same fix as the Razorpay success path above - these are
      // best-effort side effects that must never block the customer
      // from seeing their already-confirmed wallet-paid order.
      try {
        await _handleReferralReward();
      } catch (e) {
        // ignore - best-effort only.
      }
      try {
        await _incrementLoyaltyCount();
      } catch (e) {
        // ignore - best-effort only.
      }
      final groupId = _pendingOrderGroupId ?? orderIds.first;
      _cart.clear();
      if (mounted) {
        context.goNamed(OrderConfirmationWidget.routeName,
            queryParameters: {'orderId': serializeParam(groupId, ParamType.String)}.withoutNulls);
      }
      return;
    }

    _pendingOrderIds = orderIds;
    final rawPhone = currentPhoneNumber;
    final formattedPhone = _formatPhoneForRazorpay(rawPhone);
    final desc = items.length == 1 ? items.first.title : '${items.length} bags';

    try {
      _razorpay.open({
        'key': 'rzp_live_TSRp3ixw7IySWR',
        'amount': _authorizedAmountPaise!,
        'order_id': _razorpayOrderId!,
        'currency': 'INR',
        'name': 'Surpl',
        'description': desc,
        'image': 'https://surpl.in/logo-icon.png',
        'prefill': {
          'contact': formattedPhone,
          'email': currentUserEmail.isNotEmpty ? currentUserEmail : 'customer@surpl.in',
        },
        // CRITICAL FIX: this previously fell back to an empty string
        // ('') if _pendingOrderGroupId was ever null at this exact
        // point. Traced the consequence all the way through: an empty
        // string note means `if (!groupId) return;` in BOTH
        // razorpayWebhook's payment.captured handler AND
        // cleanupAbandonedOrders' Razorpay-payment matching treat it as
        // "no group id present" - a falsy empty string is
        // indistinguishable from a missing note to either function.
        // There is no other way either system matches a payment to an
        // order (confirmed: no Razorpay Order object is ever created
        // before checkout, so no razorpayOrderId field exists to fall
        // back to). If this branch had ever fired: the customer's
        // payment would succeed, the webhook could never confirm the
        // order (stuck at "pending" forever), and the cleanup job would
        // then wrongly mark it abandoned/cancelled despite the
        // successful charge - the exact failure mode of a customer
        // being charged with no order ever confirmed. Falls back to the
        // actual reserved order id instead of an empty string - matches
        // the same safe pattern already used for the wallet-payment
        // branch above, which was never at risk since it never went
        // through Razorpay at all.
        'notes': {'surpl_order_group_id': _pendingOrderGroupId ??
            ((_pendingOrderIds?.isNotEmpty ?? false) ? _pendingOrderIds!.first : '')},
        'theme': {'color': '#1A4731'},
        'modal': {'confirm_close': true, 'animation': true},
        'retry': {'enabled': true, 'max_count': 3},
      });
    } catch (e) {
      await _handlePaymentNotConfirmed(
          'Payment could not open. Check My Orders before attempting another payment.');
    }
  }

  Widget _payOption(String id, String label, String sub, IconData icon, {bool disabled = false}) {
    final sel = _selectedPayment == id;
    return GestureDetector(
      onTap: disabled ? null : () => setState(() => _selectedPayment = id),
      child: Opacity(opacity: disabled ? 0.45 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: sel ? _kMintBg : Colors.white,
            border: Border.all(color: sel ? _kGreen : _kBorder, width: sel ? 1.5 : 1),
            borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Icon(icon, size: 20, color: sel ? _kGreen : _kTextSecondary),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 13,
                fontWeight: sel ? FontWeight.w700 : FontWeight.w500, color: sel ? _kGreen : _kTextDark)),
              Text(sub, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: _kTextSecondary)),
            ])),
            Container(width: 18, height: 18,
              decoration: BoxDecoration(shape: BoxShape.circle,
                border: Border.all(color: sel ? _kGreen : _kBorder, width: 2),
                color: sel ? _kGreen : Colors.white),
              child: sel ? const Icon(Icons.check, size: 10, color: Colors.white) : null),
          ]),
        )),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cart.isEmpty) {
      return Scaffold(backgroundColor: _kBgLight,
        body: Center(child: Text('Your cart is empty',
          style: GoogleFonts.plusJakartaSans(color: _kTextSecondary))));
    }

    return AnimatedBuilder(
      animation: _cart,
      builder: (context, _) {
        final items = _cart.items;
        final canUseWallet = _walletBalance >= _total;

        return GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Scaffold(
            backgroundColor: _kBgLight,
            body: SafeArea(child: Column(children: [
              Container(color: _kGreen,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(width: 32, height: 32,
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), shape: BoxShape.circle),
                      child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 16))),
                  const SizedBox(width: 10),
                  Text('Checkout', style: GoogleFonts.plusJakartaSans(
                    fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                ])),

              Expanded(child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  // Bag list
                  Container(
                    decoration: BoxDecoration(color: Colors.white,
                      border: Border.all(color: _kBorder), borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.all(14),
                    child: Column(children: [
                      for (final item in items) ...[
                        Row(children: [
                          ClipRRect(borderRadius: BorderRadius.circular(10),
                            child: item.image.isNotEmpty
                              ? CachedNetworkImage(imageUrl: item.image, width: 52, height: 52, fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => Container(width: 52, height: 52, color: _kMintBg,
                                    child: const Icon(Icons.shopping_bag, color: _kGreen)))
                              : Container(width: 52, height: 52, color: _kMintBg,
                                  child: const Icon(Icons.shopping_bag, color: _kGreen))),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(item.title, style: GoogleFonts.plusJakartaSans(
                              fontSize: 14, fontWeight: FontWeight.w700, color: _kTextDark)),
                            Text('${item.merchantName} · Qty ${item.quantity}', style: GoogleFonts.plusJakartaSans(
                              fontSize: 11, color: _kTextSecondary)),
                          ])),
                          Text('₹${item.lineTotal.toStringAsFixed(2)}', style: GoogleFonts.plusJakartaSans(
                            fontSize: 14, fontWeight: FontWeight.w700, color: _kTextDark)),
                        ]),
                        if (item != items.last) const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Divider(color: _kBorder, height: 1)),
                      ],
                    ])),
                  const SizedBox(height: 14),

                  // Price breakdown
                  Container(
                    decoration: BoxDecoration(color: Colors.white,
                      border: Border.all(color: _kBorder), borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('PRICE BREAKDOWN', style: GoogleFonts.plusJakartaSans(fontSize: 11,
                        fontWeight: FontWeight.w700, letterSpacing: 0.5, color: _kTextSecondary)),
                      const SizedBox(height: 12),
                      _priceRow('Bags subtotal (${_cart.totalQuantity})', _subtotal),
                      const SizedBox(height: 8),
                      _priceRow('Platform fee', _kPlatformFee, sub: 'Keeps Surpl running'),
                      if (_referralDiscount > 0) ...[
                        const SizedBox(height: 8),
                        _priceRowDiscount('Referral discount (${_referralDiscountPct.toInt()}%)', _referralDiscount),
                      ],
                      const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(color: _kBorder, height: 1)),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('Total', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: _kTextDark)),
                        Text('₹${_total.toStringAsFixed(2)}', style: GoogleFonts.plusJakartaSans(
                          fontSize: 16, fontWeight: FontWeight.w800, color: _kGreen)),
                      ]),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6F4ED),
                          borderRadius: BorderRadius.circular(10)),
                        child: Row(children: [
                          const Icon(Icons.directions_walk_rounded, size: 18, color: _kGreen),
                          const SizedBox(width: 8),
                          Expanded(child: Text(
                            'You\'re picking this up yourself — no delivery fee, no surge pricing, no rider tip. Just the food.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5, color: _kGreen, fontWeight: FontWeight.w600))),
                        ]),
                      ),
                    ])),
                  const SizedBox(height: 14),

                  // Customer name - so vendors and admin can see who
                  // placed the order, instead of just a generic
                  // "Customer" label. Pre-filled if already known.
                  Container(
                    decoration: BoxDecoration(color: Colors.white,
                      border: Border.all(color: _kBorder), borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('YOUR NAME', style: GoogleFonts.plusJakartaSans(fontSize: 11,
                        fontWeight: FontWeight.w700, letterSpacing: 0.5, color: _kTextSecondary)),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          hintText: 'So the vendor knows who to expect',
                          hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.grey.shade400),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          border: const UnderlineInputBorder(),
                        ),
                        style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 14),

                  // Payment method
                  Container(
                    decoration: BoxDecoration(color: Colors.white,
                      border: Border.all(color: _kBorder), borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('PAYMENT METHOD', style: GoogleFonts.plusJakartaSans(fontSize: 11,
                        fontWeight: FontWeight.w700, letterSpacing: 0.5, color: _kTextSecondary)),
                      const SizedBox(height: 12),
                      _payOption('razorpay', 'Razorpay', 'UPI · Card · Net Banking', Icons.payment_rounded),
                      const SizedBox(height: 8),
                      _payOption('wallet', 'Surpl Wallet',
                        canUseWallet ? 'Balance: ₹${_walletBalance.toStringAsFixed(2)}' : 'Insufficient: ₹${_walletBalance.toStringAsFixed(2)}',
                        Icons.account_balance_wallet_rounded, disabled: !canUseWallet),
                    ])),

                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
                      child: Row(children: [
                        Icon(Icons.error_outline, color: Colors.red.shade700, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_errorMessage!, style: GoogleFonts.plusJakartaSans(
                          fontSize: 12, color: Colors.red.shade700))),
                      ])),
                  ],
                  const SizedBox(height: 80),
                ]))),

              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: _kBorder))),
                child: SafeArea(top: false,
                  child: GestureDetector(
                    onTap: _paying ? null : _pay,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: _paying ? _kGreen.withValues(alpha: 0.6) : _kGreen, borderRadius: BorderRadius.circular(14)),
                      alignment: Alignment.center,
                      child: _paying
                        ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(
                              strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))),
                            const SizedBox(width: 12),
                            Text('Processing...', style: GoogleFonts.plusJakartaSans(
                              fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                          ])
                        : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const Icon(Icons.lock_rounded, color: Colors.white, size: 16),
                            const SizedBox(width: 8),
                            Text('Pay ₹${_total.toStringAsFixed(2)} securely', style: GoogleFonts.plusJakartaSans(
                              fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                          ]),
                    )))),
            ])),
          ),
        );
      },
    );
  }

  Widget _priceRow(String label, double amount, {String? sub}) =>
      Padding(padding: const EdgeInsets.only(bottom: 2),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: _kTextSecondary)),
            if (sub != null) Text(sub, style: GoogleFonts.plusJakartaSans(fontSize: 10, color: _kTextSecondary.withValues(alpha: 0.6))),
          ])),
          const SizedBox(width: 10),
          Text('₹${amount.toStringAsFixed(2)}', style: GoogleFonts.plusJakartaSans(
            fontSize: 13, fontWeight: FontWeight.w600, color: _kTextDark)),
        ]));

  Widget _priceRowDiscount(String label, double amount) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.green.shade700))),
        const SizedBox(width: 10),
        Text('-₹${amount.toStringAsFixed(2)}', style: GoogleFonts.plusJakartaSans(
          fontSize: 13, fontWeight: FontWeight.w600, color: Colors.green.shade700)),
      ]);
}
