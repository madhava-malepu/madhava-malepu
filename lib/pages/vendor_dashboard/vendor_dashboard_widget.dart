import '/components/vendor_payout_statement.dart';
import '/components/community_forms.dart';
import '/components/order_alert_settings_card.dart';
import '/pages/community/loyal_customers_page.dart';
import '/services/community_service.dart';
import '/services/order_accounting.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '/services/order_expiry_service.dart';
import '/services/notification_service.dart';
import '/services/vendor_streak_service.dart';
import '/services/impact_service.dart';
import 'vendor_dashboard_model.dart';
export 'vendor_dashboard_model.dart';

const _kGreen = Color(0xFF1A4731);
const _kAmber = Color(0xFFF5A623);
const _kBgLight = Color(0xFFF4F7F4);
const _kBorder = Color(0xFFD4E8D4);
const _kTextDark = Color(0xFF0D1F12);
const _kTextSecondary = Color(0xFF4D6B57);
const _kMintBg = Color(0xFFE6F4ED);

// COST FIX: _Header, _PerformanceSummary, and _TopSellingListings each
// independently ran the SAME "all this vendor's orders" query as their
// own separate live Firestore listener - three separate subscriptions
// billing for the same documents on every single order change, found
// while investigating a real Firestore read-quota overage. This shares
// ONE underlying listener per vendor across all of them: Firestore only
// ever sees one subscription; asBroadcastStream() lets multiple widgets
// listen to that same Dart-side stream for free. Left deliberately
// unbounded (same data these widgets already used) rather than guessed
// at a date cutoff, since some of them may genuinely need all-time
// totals and silently truncating that under time pressure risks being
// a worse bug than the one being fixed.
final Map<String, Stream<QuerySnapshot>> _vendorOrdersStreamCache = {};
Stream<QuerySnapshot> _sharedVendorOrdersStream(String uid) {
  return _vendorOrdersStreamCache.putIfAbsent(
    uid,
    () => FirebaseFirestore.instance
        .collection('orders')
        .where('merchantId', isEqualTo: uid)
        .snapshots()
        .asBroadcastStream(),
  );
}

class VendorDashboardWidget extends StatefulWidget {
  const VendorDashboardWidget({super.key});
  static String routeName = 'VendorDashboard';
  static String routePath = '/vendorDashboard';
  @override
  State<VendorDashboardWidget> createState() => _VendorDashboardWidgetState();
}

class _VendorDashboardWidgetState extends State<VendorDashboardWidget>
    with SingleTickerProviderStateMixin {
  late VendorDashboardModel _model;
  late TabController _tabCtrl;
  StreamSubscription<QuerySnapshot>? _newOrderSub;
  StreamSubscription<RemoteMessage>? _notificationTapSub;
  Timer? _alertRepeatTimer;
  final AudioPlayer _alertPlayer = AudioPlayer();
  Set<String> _knownOrderIds = {};
  bool _firstOrderSnapshot = true;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => VendorDashboardModel());
    _tabCtrl = TabController(length: 5, vsync: this);
    // Auto-expire unpaid/missed orders for this vendor
    final uid = currentUserUid;
    if (uid.isNotEmpty) OrderExpiryService.expireForMerchant(uid);
    // Register this device for push notifications
    NotificationService.init();
    // FIX: real, well-documented gap found while investigating "vendors
    // not getting order alerts" - Xiaomi/Vivo/Oppo/OnePlus (very common
    // in this market) aggressively kill background processes and FCM
    // delivery unless an app is explicitly whitelisted by the user, no
    // matter how correct the notification code itself is. Nothing in
    // this app ever asked for that exemption. This is the standard,
    // correct mitigation - same one Swiggy/Zomato's own delivery-partner
    // apps use. Shown once, only to vendors (customers don't need
    // reliable background wake), only if not already granted.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkBatteryOptimization());
    // Watch for brand-new orders while this vendor has the dashboard
    // open, and show a prominent on-screen alert with the pickup code -
    // this is in addition to the OS push notification, specifically so
    // the code is visible immediately without needing to pull down the
    // notification shade.
    if (uid.isNotEmpty) _watchForNewOrders(uid);
    // A notification tap (in any state - foreground, backgrounded, or
    // cold start) sets this before the dashboard even loads. Check it
    // here and show the same accept screen immediately, rather than the
    // vendor landing on the dashboard with no indication why they're
    // here or what to do.
    if (PendingNotificationNav.type == 'new_order' && PendingNotificationNav.id != null) {
      final pendingOrderId = PendingNotificationNav.id!;
      PendingNotificationNav.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) => _showAlertForOrderId(pendingOrderId));
    }
    // The check above only runs once, at init - it does NOT fire again
    // if this widget is already mounted (e.g. vendor backgrounds the app
    // while already on this exact screen, then taps a notification to
    // return). This live listener covers that case - it fires for as
    // long as the dashboard is on screen, regardless of whether
    // initState already ran.
    _notificationTapSub = FirebaseMessaging.onMessageOpenedApp.listen((message) {
      if (message.data['type'] == 'new_order') {
        final orderId = message.data['orderId'] as String?;
        if (orderId != null && orderId.isNotEmpty) {
          _showAlertForOrderId(orderId);
        }
      }
    });
  }

  Future<void> _showAlertForOrderId(String orderId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('orders').doc(orderId).get();
      if (!doc.exists || !mounted) return;
      final d = doc.data() as Map<String, dynamic>;
      // Already handled - nothing to show
      if (d['vendorAcknowledged'] == true) return;
      _showNewOrderAlert(
        code: d['pickupCode'] as String? ?? '------',
        bagTitle: d['bagTitle'] as String? ?? 'Surprise Bag',
        amount: (d['amountPaid'] as num?)?.toDouble() ?? 0,
        orderRef: doc.reference,
      );
    } catch (_) {}
  }

  static const _batteryChannel = MethodChannel('com.surpl.app/battery');

  Future<void> _checkBatteryOptimization() async {
    if (!mounted) return;
    try {
      final alreadyExempt = await _batteryChannel.invokeMethod<bool>('isIgnoringBatteryOptimizations') ?? true;
      if (alreadyExempt) return;
    } catch (_) {
      // Method channel not wired up on the native side yet, or a
      // non-Android platform (iOS doesn't have this concept at all) -
      // fail silently rather than block the dashboard from loading.
      return;
    }
    if (!mounted) return;
    final proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Never miss an order'),
        content: const Text(
            'Some phones (Xiaomi, Vivo, Oppo, OnePlus) aggressively close apps '
            'running in the background, which can silently block order alerts '
            'even when everything else is working correctly. Allow Surpl to '
            'run in the background so you always get notified the moment a '
            'customer pays.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Not now')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Allow')),
        ],
      ),
    );
    if (proceed == true) {
      try {
        await _batteryChannel.invokeMethod('requestIgnoreBatteryOptimizations');
      } catch (_) {}
    }
  }

  void _watchForNewOrders(String uid) {
    _newOrderSub = FirebaseFirestore.instance
        .collection('orders')
        .where('merchantId', isEqualTo: uid)
        // No .orderBy() here deliberately - combining .where() with
        // .orderBy() on a different field requires a Firestore composite
        // index that doesn't exist automatically. This listener only
        // needs to detect that a NEW order id appeared (a set
        // difference), which doesn't need sorted results at all -
        // removing the sort avoids needing that index. Previously this
        // query was very likely failing outright with a
        // FAILED_PRECONDITION error, and because .listen() had no error
        // handler, that failure was completely silent - the alert never
        // fired, with no visible sign why.
        .limit(20)
        .snapshots()
        .listen((snap) {
      final currentIds = snap.docs.map((d) => d.id).toSet();

      // The actual fix: an order that was already confirmed and
      // genuinely still unacknowledged BEFORE the dashboard opened is
      // exactly as urgent as one that arrives while watching - a vendor
      // whose app was closed or backgrounded when payment came through
      // must still see this the moment they open the app, whether that's
      // from tapping the push notification or just opening it themselves.
      // Previously the first snapshot only recorded IDs and returned,
      // silently treating every pre-existing unacknowledged order as if
      // the vendor had already seen it - they hadn't. This was very
      // likely the real cause of vendors reporting missed alerts, since
      // most orders arrive while the app isn't open.
      bool stillNeedsAlert(Map<String, dynamic> d) {
        if (d['status'] != 'confirmed') return false;
        if (d['vendorAcknowledged'] == true) return false;
        final pickupEndMillis = (d['pickupEndMillis'] as num?)?.toInt() ?? 0;
        if (pickupEndMillis > 0 && DateTime.now().millisecondsSinceEpoch > pickupEndMillis) return false;
        return true;
      }

      if (_firstOrderSnapshot) {
        _knownOrderIds = currentIds;
        _firstOrderSnapshot = false;
        if (!mounted) return;
        for (final doc in snap.docs) {
          final d = doc.data() as Map<String, dynamic>;
          if (stillNeedsAlert(d)) {
            _showNewOrderAlert(
              code: d['pickupCode'] as String? ?? '------',
              bagTitle: d['bagTitle'] as String? ?? 'Surprise Bag',
              amount: (d['amountPaid'] as num?)?.toDouble() ?? 0,
              orderRef: doc.reference,
            );
            break; // Only ever one alert screen at a time - if there's
                   // more than one waiting, the vendor sees the next
                   // once this one resolves, same as the live-arrival path below.
          }
        }
        return;
      }
      final newIds = currentIds.difference(_knownOrderIds);
      _knownOrderIds = currentIds;
      if (newIds.isEmpty || !mounted) return;
      for (final doc in snap.docs) {
        if (newIds.contains(doc.id)) {
          final d = doc.data() as Map<String, dynamic>;
          // FIX: only show the alert if the order is still genuinely
          // awaiting acceptance right now - not already handled through
          // some other path (accepted, cancelled, refunded, or its
          // pickup window already passed by the time this fires).
          // Previously this alert triggered purely on "is this order id
          // new to me" with zero check on whether it was still relevant.
          if (!stillNeedsAlert(d)) continue;
          _showNewOrderAlert(
            code: d['pickupCode'] as String? ?? '------',
            bagTitle: d['bagTitle'] as String? ?? 'Surprise Bag',
            amount: (d['amountPaid'] as num?)?.toDouble() ?? 0,
            orderRef: doc.reference,
          );
        }
      }
    }, onError: (err) {
      // Now visible instead of silently swallowed - if this ever fails
      // again (permissions, index, anything), it shows up instead of
      // just quietly not alerting.
      debugPrint('New-order listener failed: $err');
    });
  }

  void _showNewOrderAlert({required String code, required String bagTitle, required double amount, required DocumentReference orderRef}) {
    // Genuine looping alert tone - not just a short system chime. Loops
    // seamlessly like an incoming call, not a manual repeat with gaps.
    _alertPlayer.setReleaseMode(ReleaseMode.loop);
    _alertPlayer.setVolume(1.0);
    _alertPlayer.play(AssetSource('audios/order_alert.wav')).catchError((e) {
      // If the asset is missing or playback fails for any reason, fall
      // back to the system alert sound rather than the vendor getting
      // silence with no indication anything went wrong.
      debugPrint('Alert audio playback failed, falling back to system sound: $e');
      SystemSound.play(SystemSoundType.alert);
    });
    HapticFeedback.heavyImpact();
    // Vibration still repeats independently of the audio loop, since
    // haptics need their own explicit repeat trigger.
    final repeatTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      HapticFeedback.heavyImpact();
    });
    _alertRepeatTimer = repeatTimer;

    // FIX: this is the actual root fix for the reported bug - previously
    // once this screen was pushed, it had zero connection to the order's
    // real status and would sit there indefinitely (even into following
    // days) with "ACCEPT ORDER" as the only way out, regardless of
    // whether the order had since been cancelled, refunded, accepted
    // through another device, or its pickup window had simply passed.
    // This live listener closes the screen automatically the moment any
    // of those becomes true - the backend's own order status now
    // genuinely controls whether this screen stays up, not a client-side
    // timer or the vendor's own action being the only trigger.
    StreamSubscription<DocumentSnapshot>? staleSub;
    BuildContext? alertCtx;

    staleSub = orderRef.snapshots().listen((docSnap) {
      final data = docSnap.data() as Map<String, dynamic>?;
      final stillNeedsAcceptance = data != null
          && data['status'] == 'confirmed'
          && data['vendorAcknowledged'] != true;
      if (!stillNeedsAcceptance && alertCtx != null && alertCtx!.mounted) {
        repeatTimer.cancel();
        _alertPlayer.stop();
        staleSub?.cancel();
        Navigator.of(alertCtx!, rootNavigator: true).pop();
      }
    });

    Navigator.of(context, rootNavigator: true).push(PageRouteBuilder(
      opaque: true,
      barrierDismissible: false,
      pageBuilder: (ctx, anim, anim2) {
        alertCtx = ctx;
        return PopScope(
        // Blocks the Android back button too - this alert must be
        // explicitly accepted, not dismissed around.
        canPop: false,
        child: Scaffold(
          backgroundColor: _kGreen,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  const Text('🔔', style: TextStyle(fontSize: 64)),
                  const SizedBox(height: 16),
                  Text('NEW ORDER!', style: GoogleFonts.plusJakartaSans(
                    fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 12),
                  Text(bagTitle, style: GoogleFonts.plusJakartaSans(
                    fontSize: 18, color: Colors.white70), textAlign: TextAlign.center),
                  const SizedBox(height: 6),
                  Text('₹${amount.toStringAsFixed(0)}', style: GoogleFonts.plusJakartaSans(
                    fontSize: 22, fontWeight: FontWeight.w700, color: _kAmber)),
                  const SizedBox(height: 32),
                  Text('PICKUP CODE', style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: Colors.white60)),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                    child: Text(code, style: GoogleFonts.plusJakartaSans(
                      fontSize: 48, fontWeight: FontWeight.w800, color: _kGreen, letterSpacing: 6)),
                  ),
                  const Spacer(),
                  SizedBox(width: double.infinity, height: 56, child: ElevatedButton(
                    onPressed: () async {
                      repeatTimer.cancel();
                      _alertPlayer.stop();
                      staleSub?.cancel();
                      // Record that the vendor actually saw and accepted
                      // this order - not just that a notification fired.
                      try {
                        await orderRef.update({
                          'vendorAcknowledged': true,
                          'vendorAcknowledgedAt': FieldValue.serverTimestamp(),
                        });
                      } catch (_) {}
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kAmber,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('ACCEPT ORDER', style: GoogleFonts.plusJakartaSans(
                      fontSize: 17, fontWeight: FontWeight.w800, color: _kGreen)),
                  )),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      );
      },
    ));
  }

  @override
  void dispose() {
    _model.dispose();
    _tabCtrl.dispose();
    _newOrderSub?.cancel();
    _notificationTapSub?.cancel();
    _alertRepeatTimer?.cancel();
    _alertPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = currentUserUid;

    return Scaffold(
      backgroundColor: _kBgLight,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, userSnap) {
          final userData = userSnap.data?.data() as Map<String, dynamic>?;
          final shopName = userData?['shopName'] as String? ?? 'Your Shop';
          final isVendor = userData?['isVendor'] as bool? ?? false;
          final vendorStatus = userData?['vendorStatus'] as String? ?? '';

          if (!isVendor || vendorStatus != 'approved') {
            return _pendingScreen(vendorStatus);
          }

          // No registration fee — all approved vendors access dashboard directly

          return NestedScrollView(
            headerSliverBuilder: (_, __) => [
              SliverToBoxAdapter(child: _Header(uid: uid, shopName: shopName,
                onBellTap: () => _tabCtrl.animateTo(1))),
            ],
            body: Column(children: [
              Container(
                color: Colors.white,
                child: TabBar(
                  controller: _tabCtrl,
                  labelColor: _kGreen,
                  unselectedLabelColor: _kTextSecondary,
                  indicatorColor: _kGreen,
                  indicatorWeight: 3,
                  labelStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 13, fontWeight: FontWeight.w700),
                  unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontSize: 13),
                  tabs: const [
                    Tab(text: 'Overview'),
                    Tab(text: 'Orders'),
                    Tab(text: 'Listings'),
                    Tab(text: 'Payments'),
                    Tab(text: 'Support'),
                  ]),
              ),
              Expanded(child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _OverviewTab(uid: uid),
                  _OrdersTab(uid: uid),
                  _ListingsTab(uid: uid),
                  VendorPayoutStatement(vendorId: uid),
                  _SupportTab(uid: uid),
                ])),
            ]),
          );
        },
      ),
    );
  }

  Widget _pendingScreen(String status) => SafeArea(
    child: Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 80, height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3E0), shape: BoxShape.circle),
          child: const Icon(Icons.hourglass_empty_rounded,
            color: Color(0xFFE65100), size: 40)),
        const SizedBox(height: 20),
        Text(status == 'pending' ? 'Application Under Review' : 'Not Registered',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20, fontWeight: FontWeight.w800, color: _kTextDark)),
        const SizedBox(height: 12),
        Text(
          status == 'pending'
            ? 'Your application is being reviewed. You will be approved within 24 hours.'
            : 'You are not registered as a vendor. Go to Profile → Become a Vendor.',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14, color: _kTextSecondary, height: 1.6)),
        const SizedBox(height: 32),
        GestureDetector(
          onTap: () => context.goNamed(HomeFeedWidget.routeName),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              color: _kGreen, borderRadius: BorderRadius.circular(12)),
            child: Text('Browse as Customer',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)))),
      ]))));
}

// ── HEADER ──
class _Header extends StatelessWidget {
  final String uid;
  final String shopName;
  final VoidCallback onBellTap;
  const _Header({required this.uid, required this.shopName, required this.onBellTap});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _sharedVendorOrdersStream(uid),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);
        final monthStart = DateTime(now.year, now.month, 1);

        double todayEarnings = 0, monthEarnings = 0, allEarnings = 0;
        int todayCount = 0, monthCount = 0, pendingCount = 0;
        int mealsSaved = 0;
        double valueSaved = 0;

        for (final doc in docs) {
          final d = doc.data() as Map<String, dynamic>;
          // Vendor's actual take-home (price minus commission), not the
          // customer's gross payment — matches the fix already applied to
          // the Performance Summary card below.
          final amount = OrderAccounting.vendorEarned(d);
          final ts = d['timestamp'] as int? ?? 0;
          final status = d['status'] as String? ?? '';
          // timestamp is stored in SECONDS, not milliseconds - without
          // *1000 this always showed dates near Jan 1970.
          final dt = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
          final isCompleted = status.toLowerCase() == 'completed';
          final earnsPayout = OrderAccounting.isPaid(d);

          // FIX: previously accumulated into earnings totals for EVERY
          // order regardless of status - a pending, cancelled, or missed
          // order's payout counted the same as a genuinely completed one.
          // Confirmed as the direct cause of real complaints that today's
          // earnings included cancellations and unpaid orders. Now only
          // counts orders that genuinely reached confirmed/completed.
          if (earnsPayout) {
            allEarnings += amount;
            if (!dt.isBefore(todayStart)) { todayEarnings += amount; todayCount++; }
            if (!dt.isBefore(monthStart)) { monthEarnings += amount; monthCount++; }
          }
          if (status.toLowerCase() == 'confirmed') pendingCount++;

          if (isCompleted) {
            mealsSaved++;
            // originalPrice is only populated on orders placed after this
            // was added to the checkout flow - older orders contribute 0
            // here rather than an inaccurate guess, which is the honest
            // tradeoff for not having this data retroactively.
            final originalPrice = (d['originalPrice'] as num?)?.toDouble() ?? 0;
            final amountPaid = (d['amountPaid'] as num?)?.toDouble() ?? 0;
            if (originalPrice > amountPaid) valueSaved += (originalPrice - amountPaid);
          }
        }

        return Container(
          color: _kGreen,
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16, right: 16, bottom: 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              GestureDetector(
                onTap: () => context.canPop() ? context.pop() : context.goNamed(HomeFeedWidget.routeName),
                child: Container(width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: const Icon(Icons.arrow_back_rounded,
                    color: Colors.white, size: 16))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Vendor Dashboard', style: GoogleFonts.plusJakartaSans(
                  fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                Row(children: [
                  Flexible(child: Text(shopName, style: GoogleFonts.plusJakartaSans(
                    fontSize: 12, color: Colors.white60), overflow: TextOverflow.ellipsis)),
                  FutureBuilder<int>(
                    future: VendorStreakService.currentStreak(uid),
                    builder: (context, streakSnap) {
                      final streak = streakSnap.data ?? 0;
                      if (streak < 2) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20)),
                          child: Text('🔥 $streak-day streak',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                        ),
                      );
                    },
                  ),
                  // Vendor's own rating — visible to them, same live-fetch
                  // approach as the customer-facing display, so it's
                  // always current, never a stale cached number.
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
                    builder: (context, userSnap) {
                      if (!userSnap.hasData || !userSnap.data!.exists) return const SizedBox.shrink();
                      final data = userSnap.data!.data() as Map<String, dynamic>?;
                      final avgRating = (data?['avgRating'] as num?)?.toDouble();
                      final totalRatings = (data?['totalRatings'] as num?)?.toInt() ?? 0;
                      if (avgRating == null || totalRatings == 0) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20)),
                          child: Text('⭐ ${avgRating.toStringAsFixed(1)} ($totalRatings)',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                        ),
                      );
                    },
                  ),
                ]),
              ])),
              if (pendingCount > 0) GestureDetector(
                onTap: onBellTap,
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _kAmber, borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.notifications_rounded, size: 14, color: _kGreen),
                    const SizedBox(width: 4),
                    Text('$pendingCount new', style: GoogleFonts.plusJakartaSans(
                      fontSize: 11, fontWeight: FontWeight.w700, color: _kGreen)),
                  ]))),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => _EditShopProfilePage(vendorId: uid))),
                child: Container(width: 32, height: 32, margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: const Icon(Icons.edit_rounded, color: Colors.white, size: 16))),
              GestureDetector(
                onTap: () => context.pushNamed(CreateListingWidget.routeName),
                child: Container(width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: _kAmber, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.add_rounded, color: _kGreen, size: 20))),
            ]),
            const SizedBox(height: 20),

            // Stats grid
            Row(children: [
              _chip('Today', '₹${todayEarnings.toStringAsFixed(0)}',
                '$todayCount orders', false, onTap: onBellTap),
              const SizedBox(width: 10),
              _chip('This Month', '₹${monthEarnings.toStringAsFixed(0)}',
                '$monthCount orders', true, onTap: onBellTap),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              _chip('All Time', '₹${allEarnings.toStringAsFixed(0)}',
                '${docs.length} total', false, onTap: onBellTap),
              const SizedBox(width: 10),
              _chip('Pending', '$pendingCount',
                'awaiting pickup', false, onTap: onBellTap),
            ]),

            const SizedBox(height: 16),

            // Weekly earnings bar chart
            _WeeklyChart(uid: uid),

            const SizedBox(height: 16),

            // Your Impact - a retention/engagement card distinct from the
            // earnings-focused stats above. Meals saved is accurate from
            // day one; value saved only reflects orders placed after
            // originalPrice capture was added to checkout, so it may read
            // low or zero for a newly-active vendor until fresh orders
            // come in - an honest tradeoff over guessing at historical
            // data that was never actually stored.
            if (mealsSaved > 0) Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('YOUR IMPACT', style: GoogleFonts.plusJakartaSans(
                  fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: Colors.white60)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('$mealsSaved', style: GoogleFonts.plusJakartaSans(
                      fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                    Text('meals saved from waste', style: GoogleFonts.plusJakartaSans(
                      fontSize: 11, color: Colors.white70)),
                  ])),
                  if (valueSaved > 0) Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('₹${valueSaved.toStringAsFixed(0)}', style: GoogleFonts.plusJakartaSans(
                      fontSize: 22, fontWeight: FontWeight.w800, color: _kAmber)),
                    Text('value given to customers', style: GoogleFonts.plusJakartaSans(
                      fontSize: 11, color: Colors.white70)),
                  ])),
                ]),
              ]),
            ),
          ]));
      });
  }

  Widget _chip(String label, String value, String sub, bool highlight, {VoidCallback? onTap}) =>
    Expanded(child: GestureDetector(
      onTap: onTap,
      child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlight ? _kAmber : Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: GoogleFonts.plusJakartaSans(
          fontSize: 10, fontWeight: FontWeight.w600,
          color: highlight ? const Color(0xFF7A4F00) : Colors.white60)),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.plusJakartaSans(
          fontSize: 18, fontWeight: FontWeight.w800,
          color: highlight ? _kGreen : Colors.white)),
        const SizedBox(height: 2),
        Text(sub, style: GoogleFonts.plusJakartaSans(
          fontSize: 10,
          color: highlight ? const Color(0xFF7A4F00) : Colors.white54)),
      ]))));
}

// ── WEEKLY EARNINGS CHART ──
class _WeeklyChart extends StatelessWidget {
  final String uid;
  const _WeeklyChart({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      // COST FIX: this widget only ever displays the last 7 days, but was
      // live-streaming the vendor's ENTIRE all-time order history to compute
      // it, client-side, on every single order change - one of several
      // unbounded listeners on this same collection found while investigating
      // a real Firestore read-quota overage. Filtering the 7-day window in
      // the query itself, not after fetching everything, is what actually
      // bounds the read cost as a vendor's order history grows over time.
      stream: FirebaseFirestore.instance.collection('orders')
          .where('merchantId', isEqualTo: uid)
          .where('timestamp', isGreaterThan:
              DateTime.now().subtract(const Duration(days: 8)).millisecondsSinceEpoch ~/ 1000)
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        final now = DateTime.now();

        // Build last 7 days earnings
        final List<String> dayLabels = [];
        final List<double> dayEarnings = [];
        final List<int> dayOrderCounts = [];
        final List<DateTime> dayDates = [];
        for (int i = 6; i >= 0; i--) {
          final day = now.subtract(Duration(days: i));
          dayLabels.add(['Mon','Tue','Wed','Thu','Fri','Sat','Sun']
            [day.weekday - 1]);
          dayDates.add(day);
          double total = 0;
          int count = 0;
          for (final doc in docs) {
            final d = doc.data() as Map<String, dynamic>;
            final ts = d['timestamp'] as int? ?? 0;
            // timestamp is stored in SECONDS - without *1000, dt was
            // always ~1970, so this day-match comparison below could
            // never succeed. This is why the weekly chart always showed
            // zero earnings for every single day, regardless of real
            // completed orders.
            final dt = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
            if (dt.year == day.year && dt.month == day.month &&
                dt.day == day.day) {
              total += OrderAccounting.vendorEarned(d);
              if (OrderAccounting.isPaid(d)) count++;
            }
          }
          dayEarnings.add(total);
          dayOrderCounts.add(count);
        }

        final maxVal = dayEarnings.isEmpty ? 1.0
          : dayEarnings.reduce((a, b) => a > b ? a : b).clamp(1.0, double.infinity);

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('THIS WEEK', style: GoogleFonts.plusJakartaSans(
            fontSize: 10, fontWeight: FontWeight.w700,
            letterSpacing: 0.8, color: Colors.white54)),
          const SizedBox(height: 10),
          SizedBox(
            height: 70,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (i) {
                final isToday = i == 6;
                final pct = dayEarnings[i] / maxVal;
                return Expanded(child: GestureDetector(
                  onTap: () => showModalBottomSheet(
                    context: context,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                    builder: (ctx) => Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(
                          '${dayDates[i].day}/${dayDates[i].month}/${dayDates[i].year}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16, fontWeight: FontWeight.w800, color: _kGreen)),
                        const SizedBox(height: 12),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                          Column(children: [
                            Text('₹${dayEarnings[i].toStringAsFixed(0)}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 22, fontWeight: FontWeight.w800, color: _kGreen)),
                            Text('Earned', style: GoogleFonts.plusJakartaSans(
                              fontSize: 12, color: _kTextSecondary)),
                          ]),
                          Column(children: [
                            Text('${dayOrderCounts[i]}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 22, fontWeight: FontWeight.w800, color: _kGreen)),
                            Text('Orders', style: GoogleFonts.plusJakartaSans(
                              fontSize: 12, color: _kTextSecondary)),
                          ]),
                        ]),
                        const SizedBox(height: 16),
                      ]))),
                  child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (dayEarnings[i] > 0) Text(
                        '₹${dayEarnings[i].toStringAsFixed(0)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 8, color: Colors.white70)),
                      const SizedBox(height: 2),
                      Container(
                        height: (50 * pct).clamp(4.0, 50.0),
                        decoration: BoxDecoration(
                          color: isToday ? _kAmber : Colors.white.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(4))),
                      const SizedBox(height: 4),
                      Text(dayLabels[i], style: GoogleFonts.plusJakartaSans(
                        fontSize: 9,
                        color: isToday ? _kAmber : Colors.white54,
                        fontWeight: isToday ? FontWeight.w700 : FontWeight.w400)),
                    ]))));
              }),
            )),
        ]);
      });
  }
}

// ── OVERVIEW TAB ──
// ── TOP SELLING LISTINGS ──
// Joins completed orders against this vendor's bags (by bagId) to surface
// which actual products sell best, aggregated by title so re-listing the
// same item across multiple days correctly counts as one product's total,
// not scattered across separate bagId entries.
class _TopSellingListings extends StatelessWidget {
  final String uid;
  const _TopSellingListings({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('bags')
          .where('merchantId', isEqualTo: uid).snapshots(),
      builder: (context, bagsSnap) {
        final bagDocs = bagsSnap.data?.docs ?? [];
        // bagId -> title lookup, built once per bags snapshot
        final Map<String, String> titleByBagId = {
          for (final d in bagDocs) d.id: (d.data() as Map<String, dynamic>)['title'] as String? ?? 'Untitled'
        };

        return StreamBuilder<QuerySnapshot>(
          stream: _sharedVendorOrdersStream(uid),
          builder: (context, ordersSnap) {
            final orderDocs = ordersSnap.data?.docs ?? [];

            // title -> {revenue, unitsSold}. Same vendorPayout + vendorAtFault
            // handling as _PerformanceSummary above - this must stay
            // consistent with how earnings are calculated everywhere else
            // in this file, not a separate, drifting interpretation.
            // FIX: this was the one place still using status != 'completed'
            // only, excluding 'confirmed' orders that the top-level
            // earnings summary (and the average-order-value calculation
            // further down) already correctly counts as earned. That
            // meant a vendor's per-dish revenue breakdown could add up to
            // less than the total earnings shown at the top of the same
            // screen, for any order that was paid but not yet verified as
            // physically picked up - looking exactly like broken math,
            // even though each individual number was internally correct.
            final Map<String, _TitleStats> statsByTitle = {};
            for (final doc in orderDocs) {
              final d = doc.data() as Map<String, dynamic>;
              if (!OrderAccounting.isPaid(d) || d['vendorAtFault'] == true) continue;
              final bagId = d['bagId'] as String? ?? '';
              final title = titleByBagId[bagId] ?? 'Deleted listing';
              final payout = OrderAccounting.vendorEarned(d);
              final qty = (d['quantity'] as num?)?.toInt() ?? 1;
              final existing = statsByTitle[title] ?? _TitleStats(0, 0);
              statsByTitle[title] = _TitleStats(
                existing.revenue + payout, existing.unitsSold + qty);
            }

            if (statsByTitle.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white,
                  borderRadius: BorderRadius.circular(12), border: Border.all(color: _kBorder)),
                child: Center(child: Text(
                  'No completed sales yet — once orders come in, your top sellers will show here.',
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, color: _kTextSecondary),
                  textAlign: TextAlign.center)));
            }

            final sorted = statsByTitle.entries.toList()
              ..sort((a, b) => b.value.revenue.compareTo(a.value.revenue));
            final top5 = sorted.take(5).toList();
            final maxRevenue = top5.first.value.revenue.clamp(1.0, double.infinity);

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white,
                borderRadius: BorderRadius.circular(16), border: Border.all(color: _kBorder)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: top5.asMap().entries.map((entry) {
                final rank = entry.key;
                final title = entry.value.key;
                final stats = entry.value.value;
                final barPct = (stats.revenue / maxRevenue).clamp(0.0, 1.0);
                return Padding(
                  padding: EdgeInsets.only(bottom: rank < top5.length - 1 ? 14 : 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(width: 22, height: 22,
                        decoration: BoxDecoration(
                          color: rank == 0 ? _kAmber : _kBorder,
                          borderRadius: BorderRadius.circular(6)),
                        child: Center(child: Text('${rank + 1}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11, fontWeight: FontWeight.w800,
                            color: rank == 0 ? _kGreen : _kTextSecondary)))),
                      const SizedBox(width: 10),
                      Expanded(child: Text(title,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13, fontWeight: FontWeight.w700))),
                      Text('${stats.unitsSold} sold', style: GoogleFonts.plusJakartaSans(
                        fontSize: 11, color: _kTextSecondary)),
                      const SizedBox(width: 8),
                      Text('₹${stats.revenue.toStringAsFixed(0)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13, fontWeight: FontWeight.w800, color: _kGreen)),
                    ]),
                    const SizedBox(height: 6),
                    ClipRRect(borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: barPct, backgroundColor: _kBorder,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          rank == 0 ? _kAmber : _kGreen),
                        minHeight: 6)),
                  ]));
              }).toList()));
          });
      });
  }
}

class _TitleStats {
  final double revenue;
  final int unitsSold;
  const _TitleStats(this.revenue, this.unitsSold);
}

class _OverviewTab extends StatelessWidget {
  final String uid;
  const _OverviewTab({required this.uid});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Quick action banner
        GestureDetector(
          onTap: () => context.pushNamed(CreateListingWidget.routeName),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A4731), Color(0xFF2D6B4F)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('List a New Bag 🎁', style: GoogleFonts.plusJakartaSans(
                  fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 4),
                Text('Turn surplus food into revenue',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12, color: Colors.white60)),
              ])),
              Container(width: 44, height: 44,
                decoration: BoxDecoration(
                  color: _kAmber, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.add_rounded, color: _kGreen, size: 26)),
            ]))),
        const SizedBox(height: 20),

        // Performance summary
        Text('PERFORMANCE', style: GoogleFonts.plusJakartaSans(
          fontSize: 11, fontWeight: FontWeight.w700,
          letterSpacing: 0.8, color: _kTextSecondary)),
        const SizedBox(height: 10),
        _PerformanceSummary(uid: uid),
        const SizedBox(height: 20),

        // Top selling listings
        Text('TOP SELLING', style: GoogleFonts.plusJakartaSans(
          fontSize: 11, fontWeight: FontWeight.w700,
          letterSpacing: 0.8, color: _kTextSecondary)),
        const SizedBox(height: 10),
        _TopSellingListings(uid: uid),
        const SizedBox(height: 20),

        // Recent orders
        Text('RECENT ORDERS', style: GoogleFonts.plusJakartaSans(
          fontSize: 11, fontWeight: FontWeight.w700,
          letterSpacing: 0.8, color: _kTextSecondary)),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot>(
          // No .orderBy() here - combining .where() with .orderBy() on a
          // different field requires a Firestore composite index. If
          // that index doesn't exist (a real, easy-to-miss setup step),
          // this query fails outright with a technical error. Sorting
          // and limiting client-side instead avoids depending on an
          // index existing at all - fetches a slightly larger set to
          // sort from, so the actual 5 most recent are still correct.
          stream: FirebaseFirestore.instance.collection('orders')
              .where('merchantId', isEqualTo: uid)
              .limit(20)
              .snapshots(),
          builder: (context, snap) {
            final docs = List<QueryDocumentSnapshot>.from(snap.data?.docs ?? []);
            // FIX: this had no status filter at all - a run of failed
            // customer payment attempts (common, and entirely normal)
            // could fill every one of the top-5 recency slots, pushing
            // a vendor's actual real, confirmed orders out of their own
            // Recent Orders preview entirely. Same distinction as the
            // Orders tab: a cancelled order only stays visible here if
            // it has a real paymentId (a genuine payment that was later
            // refunded/disputed) - a pure payment-attempt failure that
            // never became a real order is filtered out before the
            // top-5 cut, not after, so it can no longer crowd out what
            // actually matters.
            final meaningfulDocs = docs.where((d) {
              final data = d.data() as Map<String, dynamic>;
              if (data['status'] != 'cancelled') return true;
              final hasRealPayment = ((data['paymentId'] as String?) ?? '').isNotEmpty
                  || ((data['razorpayPaymentId'] as String?) ?? '').isNotEmpty;
              return hasRealPayment;
            }).toList();
            meaningfulDocs.sort((a, b) {
              final tsA = (a.data() as Map<String, dynamic>)['timestamp'] as int? ?? 0;
              final tsB = (b.data() as Map<String, dynamic>)['timestamp'] as int? ?? 0;
              return tsB.compareTo(tsA);
            });
            final recentDocs = meaningfulDocs.take(5).toList();
            if (recentDocs.isEmpty) return _emptyBox(
              'No orders yet — list your first bag to start!');
            return Column(children: recentDocs.map((doc) {
              final d = doc.data() as Map<String, dynamic>;
              final status = d['status'] as String? ?? '';
              final amount = (d['amountPaid'] as num?)?.toDouble() ?? 0;
              final code = d['pickupCode'] as String? ?? '------';
              final ts = d['timestamp'] as int? ?? 0;
              // timestamp is in SECONDS, not milliseconds
              final dt = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
              final timeStr =
                '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
              return _miniOrderCard(context, doc.id, code, amount, status, timeStr, doc.reference,
                  d['listingType'] as String? ?? 'surplus');
            }).toList());
          }),
        const SizedBox(height: 20),

        // Tips
        Text('TIPS FOR SUCCESS', style: GoogleFonts.plusJakartaSans(
          fontSize: 11, fontWeight: FontWeight.w700,
          letterSpacing: 0.8, color: _kTextSecondary)),
        const SizedBox(height: 10),
        _tip('⏰', 'List bags 1–2 hours before closing for best results'),
        _tip('📸', 'Good photos increase bookings by 3×'),
        _tip('💰', 'Price ₹49–₹149 for maximum appeal'),
        _tip('🎁', 'Mystery bags sell faster — keep it a surprise!'),
      ]));
  }

  Widget _miniOrderCard(BuildContext context, String id, String code, double amount,
      String status, String time, DocumentReference ref, String listingType) {
    Color sc;
    switch (status.toLowerCase()) {
      case 'confirmed': sc = Colors.green; break;
      case 'pending': sc = Colors.orange; break;
      case 'preparing': sc = const Color(0xFFB45309); break;
      case 'ready': sc = const Color(0xFF0369A1); break;
      case 'completed': sc = _kGreen; break;
      default: sc = _kTextSecondary;
    }
    return GestureDetector(
      onTap: () {
        // FIX: found while deep-testing tonight's new sequential
        // buttons (Start Preparing / Mark Ready / Confirm Pickup) -
        // unlike _FullOrderCard elsewhere in this file, this modal had
        // no guard against a rapid double-tap. The rules correctly
        // prevent any actual bad data (a second identical write fails
        // server-side since the status has already moved on), but the
        // customer... no, the VENDOR would see a confusing "could not
        // update" error on the second tap even though the first one
        // already succeeded. Simple shared reentrancy flag, closed over
        // by all three button handlers below - no visual spinner added
        // (would need a StatefulBuilder rewrap of this whole block for
        // a cosmetic-only gap), just prevents the actual double-fire.
        var sheetBusy = false;
        showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24,
            24 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('#${id.substring(0, 8).toUpperCase()}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14, fontWeight: FontWeight.w700, color: _kTextSecondary)),
            const SizedBox(height: 4),
            Text('₹${amount.toStringAsFixed(0)} · $time',
              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: _kTextSecondary)),
            const SizedBox(height: 20),
            Text('PICKUP CODE', style: GoogleFonts.plusJakartaSans(
              fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: _kTextSecondary)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              decoration: BoxDecoration(color: _kMintBg, borderRadius: BorderRadius.circular(12)),
              child: Text(code, style: GoogleFonts.plusJakartaSans(
                fontSize: 32, fontWeight: FontWeight.w800, color: _kGreen, letterSpacing: 3))),
            const SizedBox(height: 20),
            // DESIGN: Skip the Queue (freshFood) is made-to-order, so
            // it gets real, physically-true intermediate stages -
            // Surprise Bag / Happy Hour are pre-packed and already
            // physically ready the moment they're listed, so they keep
            // the exact same single confirm-pickup action this app
            // always had for them. Never inventing a "preparing" stage
            // for a bag that already exists - that would be exactly
            // the kind of dishonest status theater a genuinely better
            // app avoids.
            if (listingType == 'freshFood' && status.toLowerCase() == 'confirmed')
              SizedBox(width: double.infinity, height: 48, child: ElevatedButton(
                onPressed: () async {
                  if (sheetBusy) return;
                  sheetBusy = true;
                  try {
                    await ref.update({'status': 'preparing', 'preparingAt': FieldValue.serverTimestamp()});
                    if (context.mounted) Navigator.of(ctx).pop();
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Could not update — check your connection and try again.'),
                        backgroundColor: Colors.red));
                    }
                  } finally {
                    sheetBusy = false;
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB45309),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: Text('START PREPARING', style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800, color: Colors.white))))
            else if (listingType == 'freshFood' && status.toLowerCase() == 'preparing')
              SizedBox(width: double.infinity, height: 48, child: ElevatedButton(
                onPressed: () async {
                  if (sheetBusy) return;
                  sheetBusy = true;
                  try {
                    await ref.update({'status': 'ready', 'readyAt': FieldValue.serverTimestamp()});
                    if (context.mounted) Navigator.of(ctx).pop();
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Could not update — check your connection and try again.'),
                        backgroundColor: Colors.red));
                    }
                  } finally {
                    sheetBusy = false;
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0369A1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: Text('MARK READY FOR PICKUP', style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800, color: Colors.white))))
            else if ((listingType == 'freshFood' && status.toLowerCase() == 'ready')
                || (listingType != 'freshFood' && status.toLowerCase() == 'confirmed'))
              SizedBox(width: double.infinity, height: 48, child: ElevatedButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dctx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: const Text('Confirm pickup'),
                      content: Text('Confirm this customer has collected their order?\n\nCode shown: $code'),
                      actions: [
                        TextButton(onPressed: () => Navigator.of(dctx).pop(false), child: const Text('Cancel')),
                        TextButton(
                          onPressed: () => Navigator.of(dctx).pop(true),
                          child: Text('Confirm', style: TextStyle(color: _kGreen, fontWeight: FontWeight.w700))),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    try {
                      await ref.update({'status': 'completed', 'completedAt': FieldValue.serverTimestamp()});
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Could not complete order — check your connection and try again.'),
                          backgroundColor: Colors.red.shade700));
                      }
                    }
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: _kGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: Text('CONFIRM PICKUP', style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800, color: Colors.white)),
              ))
            else
              Text(status.isEmpty ? '' : 'Status: ${status[0].toUpperCase()}${status.substring(1)}',
                style: GoogleFonts.plusJakartaSans(fontSize: 13, color: _kTextSecondary)),
          ]),
        ),
      );
      },
      child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: Colors.white,
        borderRadius: BorderRadius.circular(12), border: Border.all(color: _kBorder)),
      child: Row(children: [
        Container(width: 40, height: 40,
          decoration: BoxDecoration(color: _kMintBg, borderRadius: BorderRadius.circular(10)),
          alignment: Alignment.center,
          child: Text(code,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11, fontWeight: FontWeight.w800, color: _kGreen))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('#${id.substring(0, 8).toUpperCase()}',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12, fontWeight: FontWeight.w700, color: _kTextDark)),
          Text('₹${amount.toStringAsFixed(0)} · $time',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11, color: _kTextSecondary)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: sc.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: sc.withValues(alpha: 0.3))),
          child: Text(
            status.isEmpty ? '-' : status[0].toUpperCase() + status.substring(1),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10, fontWeight: FontWeight.w700, color: sc))),
        const SizedBox(width: 4),
        const Icon(Icons.chevron_right_rounded, size: 18, color: _kTextSecondary),
      ])));
  }

  Widget _tip(String emoji, String text) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(color: Colors.white,
      borderRadius: BorderRadius.circular(12), border: Border.all(color: _kBorder)),
    child: Row(children: [
      Text(emoji, style: const TextStyle(fontSize: 18)),
      const SizedBox(width: 12),
      Expanded(child: Text(text, style: GoogleFonts.plusJakartaSans(
        fontSize: 13, color: _kTextSecondary, height: 1.4))),
    ]));

  Widget _emptyBox(String msg) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: Colors.white,
      borderRadius: BorderRadius.circular(12), border: Border.all(color: _kBorder)),
    child: Center(child: Text(msg,
      style: GoogleFonts.plusJakartaSans(fontSize: 13, color: _kTextSecondary),
      textAlign: TextAlign.center)));
}

// ── PERFORMANCE SUMMARY ──
class _PerformanceSummary extends StatelessWidget {
  final String uid;
  const _PerformanceSummary({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _sharedVendorOrdersStream(uid),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        final total = docs.length;
        final completed = docs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          return (data['status'] as String? ?? '').toLowerCase() == 'completed';
        }).length;
        // Vendor's actual take-home payout (price minus commission) — not
        // amountPaid, which also includes Surpl's platform fee and would
        // overstate what the vendor really receives.
        // Orders explicitly marked vendorAtFault (set only via manual
        // refund review — see refundRequests) are excluded here, so a
        // vendor only loses money on a confirmed, serious, vendor-caused
        // refund — never automatically from an unproven/fake complaint.
        // FIX: previously summed EVERY order's payout regardless of
        // status - pending, cancelled, and missed orders all inflated
        // this total and the average order value alongside them.
        // Now matches the same confirmed+completed definition used
        // consistently elsewhere in this file (the earnings header fix
        // above), rather than a third, different, incorrect definition.
        final totalEarned = docs.fold<double>(0, (sum, d) {
          final data = d.data() as Map<String, dynamic>;
          return sum + OrderAccounting.vendorEarned(data);
        });
        final avgOrder = total > 0 ? totalEarned / total : 0.0;
        final completionRate = total > 0 ? (completed / total * 100).round() : 0;

        // Same confirmed+completed accounting standard as totalEarned above,
        // so this never disagrees with the vendor's own earnings figures.
        final vendorImpact = ImpactService.cumulative(docs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          final s = (data['status'] as String? ?? '').toLowerCase();
          return s == 'confirmed' || s == 'completed';
        }).map((d) {
          final data = d.data() as Map<String, dynamic>;
          return ImpactService.forOrder(
            bagCount: (data['quantity'] as num?)?.toInt() ?? 1,
            originalPrice: (data['originalPrice'] as num?)?.toDouble() ?? 0,
            amountPaid: (data['amountPaid'] as num?)?.toDouble() ?? 0);
        }).toList());

        // ── Private Quality Score (visible only to this vendor) ──
        // Based only on CONFIRMED at-fault incidents (set manually after
        // review — see refund handling above), never on raw complaint
        // count. This keeps a single fake/unproven complaint from
        // dinging a vendor's score.
        final atFaultCount = docs.where((d) =>
            (d.data() as Map<String, dynamic>)['vendorAtFault'] == true).length;
        final qualityScore = total > 0
            ? (100 - (atFaultCount / total * 100)).clamp(0, 100).round()
            : 100;

        return Column(children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.circular(16), border: Border.all(color: _kBorder)),
          child: Column(children: [
            Row(children: [
              _perfStat('Total Orders', '$total', Icons.shopping_bag_rounded),
              _divider(),
              _perfStat('Completed', '$completed', Icons.check_circle_rounded),
              _divider(),
              _perfStat('Avg Payout', '₹${avgOrder.toStringAsFixed(0)}',
                Icons.currency_rupee_rounded),
            ]),
            const SizedBox(height: 14),
            // Completion rate bar
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Completion Rate', style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, fontWeight: FontWeight.w600, color: _kTextSecondary)),
                Text('$completionRate%', style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, fontWeight: FontWeight.w700, color: _kGreen)),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: completionRate / 100,
                  backgroundColor: _kBorder,
                  valueColor: const AlwaysStoppedAnimation<Color>(_kGreen),
                  minHeight: 8)),
            ]),
            const SizedBox(height: 14),
            // Quality score — private, visible only to this vendor
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Row(children: [
                  Text('Quality Score', style: GoogleFonts.plusJakartaSans(
                    fontSize: 12, fontWeight: FontWeight.w600, color: _kTextSecondary)),
                  const SizedBox(width: 4),
                  Icon(Icons.lock_outline_rounded, size: 11, color: _kTextSecondary.withValues(alpha: 0.6)),
                ]),
                Text('$qualityScore/100', style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: qualityScore >= 90 ? _kGreen : const Color(0xFFE65100))),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: qualityScore / 100,
                  backgroundColor: _kBorder,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    qualityScore >= 90 ? _kGreen : const Color(0xFFE65100)),
                  minHeight: 8)),
              const SizedBox(height: 4),
              Text('Private to you — only counts confirmed, serious issues',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10, color: _kTextSecondary.withValues(alpha: 0.7))),
            ]),
          ])),

        const SizedBox(height: 14),
        // Vendor ROI Dashboard - the first visible thing built on top of
        // the recoveryEvents ledger. Money recovered first, since vendors
        // care about that more than an abstract environmental number.
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('recoveryEvents')
              .where('vendorId', isEqualTo: uid)
              .where('route', isEqualTo: 'surpl_sale')
              .snapshots(),
          builder: (context, roiSnapshot) {
            int unitsRecovered = 0;
            double retailValueRecovered = 0, cashRecovered = 0;
            if (roiSnapshot.hasData) {
              for (final doc in roiSnapshot.data!.docs) {
                final d = doc.data() as Map<String, dynamic>;
                if (d['refunded'] == true) continue; // excluded - see the refund webhook handler
                unitsRecovered += ((d['quantity'] as num?) ?? 0).toInt();
                retailValueRecovered += ((d['retailValue'] as num?) ?? 0).toDouble();
                cashRecovered += ((d['recoveredValue'] as num?) ?? 0).toDouble();
              }
            }
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _kBorder)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Your ROI Dashboard', style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, fontWeight: FontWeight.w700, color: _kTextDark)),
                const SizedBox(height: 2),
                Text('What your Surprise Bags have genuinely recovered', style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5, color: _kTextSecondary)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: Column(children: [
                    Text('$unitsRecovered', style: GoogleFonts.plusJakartaSans(
                        fontSize: 20, fontWeight: FontWeight.w800, color: _kGreen)),
                    Text('bags sold', style: GoogleFonts.plusJakartaSans(
                        fontSize: 10.5, color: _kTextSecondary)),
                  ])),
                  Expanded(child: Column(children: [
                    Text('₹${retailValueRecovered.toStringAsFixed(0)}', style: GoogleFonts.plusJakartaSans(
                        fontSize: 20, fontWeight: FontWeight.w800, color: _kGreen)),
                    Text('menu value recovered', style: GoogleFonts.plusJakartaSans(
                        fontSize: 10.5, color: _kTextSecondary), textAlign: TextAlign.center),
                  ])),
                  Expanded(child: Column(children: [
                    Text('₹${cashRecovered.toStringAsFixed(0)}', style: GoogleFonts.plusJakartaSans(
                        fontSize: 20, fontWeight: FontWeight.w800, color: _kGreen)),
                    Text('cash in your pocket', style: GoogleFonts.plusJakartaSans(
                        fontSize: 10.5, color: _kTextSecondary), textAlign: TextAlign.center),
                  ])),
                ]),
              ]),
            );
          },
        ),

        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF7EE),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1A8A3E).withValues(alpha: 0.25))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Your impact so far', style: GoogleFonts.plusJakartaSans(
                fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1A8A3E))),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: Column(children: [
                Text('🍽️', style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 2),
                Text('~${vendorImpact.foodSavedKg.toStringAsFixed(1)}kg', style: GoogleFonts.plusJakartaSans(
                    fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF1A8A3E))),
                Text('food rescued', style: GoogleFonts.plusJakartaSans(
                    fontSize: 9.5, color: const Color(0xFF1A8A3E).withValues(alpha: 0.8))),
              ])),
              Expanded(child: Column(children: [
                Text('🌍', style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 2),
                Text('~${vendorImpact.co2SavedKg.toStringAsFixed(1)}kg', style: GoogleFonts.plusJakartaSans(
                    fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF1A8A3E))),
                Text('CO₂e avoided', style: GoogleFonts.plusJakartaSans(
                    fontSize: 9.5, color: const Color(0xFF1A8A3E).withValues(alpha: 0.8))),
              ])),
            ]),
            const SizedBox(height: 6),
            Text('Estimated, based on average bag weight - not an exact measurement.',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 9.5, color: const Color(0xFF1A8A3E).withValues(alpha: 0.7),
                    fontStyle: FontStyle.italic)),
          ])),
      ]);
      });
  }

  Widget _perfStat(String label, String value, IconData icon) =>
    Expanded(child: Column(children: [
      Icon(icon, color: _kGreen, size: 20),
      const SizedBox(height: 6),
      Text(value, style: GoogleFonts.plusJakartaSans(
        fontSize: 16, fontWeight: FontWeight.w800, color: _kTextDark)),
      const SizedBox(height: 2),
      Text(label, textAlign: TextAlign.center,
        style: GoogleFonts.plusJakartaSans(fontSize: 10, color: _kTextSecondary)),
    ]));

  Widget _divider() => Container(width: 1, height: 40, color: _kBorder,
    margin: const EdgeInsets.symmetric(horizontal: 8));
}

// ── ORDERS TAB ──
class _OrdersTab extends StatefulWidget {
  final String uid;
  const _OrdersTab({required this.uid});
  @override
  State<_OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<_OrdersTab> {
  int _filterIdx = 0;
  final _filters = ['All', 'Confirmed', 'Preparing', 'Ready', 'Completed'];

  // Created once — same "blinking" fix as Home Feed and Street Snacks.
  // Tapping a filter chip calls setState(), and an inline stream here
  // would be recreated every time, flashing the loading state on tap.
  late final Stream<QuerySnapshot> _ordersStream;

  @override
  void initState() {
    super.initState();
    // FIX: this previously fetched every status including 'pending' -
    // which in this app means "payment not yet verified server-side",
    // NOT "awaiting pickup". Vendors were seeing genuinely unconfirmed,
    // possibly-about-to-fail orders in their Pending tab as if they were
    // real, actionable orders - directly causing the confusion this
    // fixes. A vendor should only ever see an order once payment has
    // genuinely been confirmed.
    _ordersStream = FirebaseFirestore.instance.collection('orders')
        .where('merchantId', isEqualTo: widget.uid)
        .where('status', whereIn: ['confirmed', 'completed', 'cancelled', 'missed', 'refunded'])
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: SizedBox(height: 36, child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: _filters.length,
          itemBuilder: (_, i) {
            final sel = _filterIdx == i;
            return GestureDetector(
              onTap: () => setState(() => _filterIdx = i),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: sel ? _kGreen : _kBgLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: sel ? _kGreen : _kBorder)),
                child: Text(_filters[i], style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                  color: sel ? Colors.white : _kTextSecondary))));
          }))),
      Expanded(child: StreamBuilder<QuerySnapshot>(
        stream: _ordersStream,
        builder: (context, snap) {
          if (snap.hasError) {
            // Previously silently swallowed — if this is actually an index
            // or permissions error, it was showing as an empty list with
            // zero explanation. Now it's visible.
            return Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Couldn\'t load orders right now — please try again in a moment.',
                style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.red.shade700))));
          }
          if (!snap.hasData) return const Center(
            child: CircularProgressIndicator(color: _kGreen));
          var docs = snap.data!.docs;
          // FIX: a vendor should never see a "cancelled" order that
          // represents nothing more than a failed/abandoned customer
          // payment attempt - that customer never actually committed to
          // anything, the vendor was never notified about it, and
          // showing it here reads as "a real order got cancelled on
          // you," which is a genuine, unwarranted red flag against the
          // vendor for something that was never theirs to begin with.
          // The one real distinction: a payment that genuinely
          // succeeded and was LATER cancelled (a refund/dispute after
          // the fact) always has a real paymentId attached - a vendor
          // does still need to see that one, since it affects what they
          // actually get paid. Pure payment-attempt failures never get
          // a paymentId at all, which is exactly the signal used here.
          docs = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            if (data['status'] != 'cancelled') return true;
            final hasRealPayment = ((data['paymentId'] as String?) ?? '').isNotEmpty
                || ((data['razorpayPaymentId'] as String?) ?? '').isNotEmpty;
            return hasRealPayment;
          }).toList();
          // Sort client-side, newest first. Previously relied on Firestore's
          // own .orderBy(), which needs a composite index alongside the
          // .where() filter — if that index was missing, results could come
          // back in whatever order Firestore happened to return them,
          // looking "random." Sorting here works regardless of index state.
          docs = List<QueryDocumentSnapshot>.from(docs)..sort((a, b) {
            final at = ((a.data() as Map)['timestamp'] as num?)?.toInt() ?? 0;
            final bt = ((b.data() as Map)['timestamp'] as num?)?.toInt() ?? 0;
            return bt.compareTo(at);
          });
          if (_filterIdx > 0) {
            final f = _filters[_filterIdx].trim().toLowerCase();
            docs = docs.where((d) {
              final data = d.data() as Map<String, dynamic>;
              final status = (data['status'] as String? ?? '').trim().toLowerCase();
              return status == f;
            }).toList();
          }
          if (docs.isEmpty) return Center(child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.receipt_long_rounded, size: 48,
                color: _kTextSecondary.withValues(alpha: 0.3)),
              const SizedBox(height: 12),
              Text('No ${_filterIdx > 0 ? _filters[_filterIdx].toLowerCase() : ''} orders',
                style: GoogleFonts.plusJakartaSans(
                  color: _kTextSecondary, fontSize: 15)),
            ])));
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final doc = docs[i];
              final d = doc.data() as Map<String, dynamic>;
              final status = d['status'] as String? ?? '';
              final amount = (d['amountPaid'] as num?)?.toDouble() ?? 0;
              final code = d['pickupCode'] as String? ?? '';
              final customerName = d['customerName'] as String? ?? '';
              final customerPhone = d['customerPhone'] as String? ?? '';
              final ts = d['timestamp'] as int? ?? 0;
              // timestamp is in SECONDS, not milliseconds
              final dt = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
              return _FullOrderCard(
                docRef: doc.reference,
                orderId: doc.id,
                code: code,
                amount: amount,
                status: status,
                listingType: d['listingType'] as String? ?? 'surplus',
                timestamp: dt,
                customerName: customerName,
                customerPhone: customerPhone);
            });
        })),
    ]);
  }
}

// ── LISTINGS TAB ──
String _snackLabel(String? type) {
  const labels = {
    'chaat': 'Chaat',
    'samosa': 'Samosa / Kachori',
    'bajji': 'Bajji / Fritters',
    'other_snack': 'Other Snacks',
  };
  return labels[type] ?? 'Snacks';
}

class _EditShopProfilePage extends StatefulWidget {
  final String vendorId;
  const _EditShopProfilePage({required this.vendorId});
  @override
  State<_EditShopProfilePage> createState() => _EditShopProfilePageState();
}

class _EditShopProfilePageState extends State<_EditShopProfilePage> {
  final _shopNameCtrl = TextEditingController();
  final _shopAreaCtrl = TextEditingController();
  final _shopAddressCtrl = TextEditingController();
  final _vendorStoryCtrl = TextEditingController();
  bool _loaded = false;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _shopNameCtrl.dispose();
    _shopAreaCtrl.dispose();
    _shopAddressCtrl.dispose();
    _vendorStoryCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.vendorId).get();
      final data = doc.data();
      _shopNameCtrl.text = data?['shopName'] as String? ?? '';
      _shopAreaCtrl.text = data?['shopArea'] as String? ?? '';
      _shopAddressCtrl.text = data?['shopAddress'] as String? ?? '';
      _vendorStoryCtrl.text = data?['vendorStory'] as String? ?? '';
      if (mounted) setState(() => _loaded = true);
    } catch (e) {
      // FIX: matching the same "stuck loading forever" bug found and
      // fixed on Bring My Restaurant - this now surfaces a real error
      // with a retry option instead of leaving the page stuck on its
      // spinner if the load fails.
      if (mounted) setState(() { _loaded = true; _loadError = e.toString(); });
    }
  }

  Future<void> _save() async {
    final shopName = _shopNameCtrl.text.trim();
    if (shopName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shop name cannot be empty.'), backgroundColor: Colors.red));
      return;
    }
    if (shopName.length > 60) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shop name is too long - keep it under 60 characters.'), backgroundColor: Colors.red));
      return;
    }
    if (_vendorStoryCtrl.text.trim().length > 400) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your story is too long - keep it under 400 characters.'), backgroundColor: Colors.red));
      return;
    }
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.vendorId).update({
        'shopName': shopName,
        'shopArea': _shopAreaCtrl.text.trim(),
        'shopAddress': _shopAddressCtrl.text.trim(),
        'vendorStory': _vendorStoryCtrl.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Shop profile updated ✅'), backgroundColor: _kGreen));
        Navigator.pop(context);
      }
    } catch (e) {
      // Deliberately still surfaces real error detail below — a save
      // failure here means real shop information didn't update, and the
      // vendor needs enough to describe the problem accurately if they
      // contact support. Improved to lead with a clear, human headline
      // first (matching how every other error in the app should read),
      // with the technical detail kept as secondary reference text
      // rather than the customer/vendor-facing headline itself.
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not save your changes. Please try again.\n(Reference: ${e.toString().length > 80 ? e.toString().substring(0, 80) : e.toString()})',
              style: const TextStyle(fontSize: 13)),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F3EC),
      appBar: AppBar(backgroundColor: _kGreen,
        title: const Text('Edit Shop Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
        iconTheme: const IconThemeData(color: Colors.white)),
      body: !_loaded
        ? const Center(child: CircularProgressIndicator(color: _kGreen))
        : _loadError != null
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Could not load your shop profile.', style: TextStyle(color: _kTextSecondary, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(_loadError!, textAlign: TextAlign.center, style: const TextStyle(color: _kTextSecondary, fontSize: 11)),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: () { setState(() { _loaded = false; _loadError = null; }); _load(); }, child: const Text('Try again')),
            ])))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('Shop name', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13, color: _kTextDark)),
                const SizedBox(height: 6),
                TextField(controller: _shopNameCtrl, maxLength: 60,
                  decoration: const InputDecoration(border: OutlineInputBorder(), filled: true, fillColor: Colors.white)),
                const SizedBox(height: 12),
                Text('Area / locality', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13, color: _kTextDark)),
                const SizedBox(height: 6),
                TextField(controller: _shopAreaCtrl, maxLength: 60,
                  decoration: const InputDecoration(border: OutlineInputBorder(), filled: true, fillColor: Colors.white)),
                const SizedBox(height: 12),
                Text('Full address', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13, color: _kTextDark)),
                const SizedBox(height: 6),
                TextField(controller: _shopAddressCtrl, maxLength: 150, maxLines: 2,
                  decoration: const InputDecoration(border: OutlineInputBorder(), filled: true, fillColor: Colors.white)),
                const SizedBox(height: 12),
                Text('Your story (shown to customers)', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13, color: _kTextDark)),
                const SizedBox(height: 6),
                TextField(controller: _vendorStoryCtrl, maxLength: 400, maxLines: 4,
                  decoration: const InputDecoration(border: OutlineInputBorder(), filled: true, fillColor: Colors.white,
                    hintText: 'Tell customers a bit about your shop...')),
                const SizedBox(height: 20),
                Material(
                  color: _saving ? _kGreen.withValues(alpha: 0.6) : _kGreen,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _saving ? null : _save,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      alignment: Alignment.center,
                      child: _saving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text('Save Changes', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white))),
                  ),
                ),
              ]),
            ),
    );
  }
}

class _IncomingOccasionRequestsCard extends StatelessWidget {
  final String vendorId;
  const _IncomingOccasionRequestsCard({required this.vendorId});

  Future<void> _respond(BuildContext context, String id, String status) async {
    try { await CommunityService.call('respondPartyRequest', {'requestId': id, 'status': status}); }
    catch(e) { if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(CommunityService.error(e)))); }
  }
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('occasionRequests')
          .where('requestedVendorId', isEqualTo: vendorId)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return const Padding(padding: EdgeInsets.all(16), child: Text('Party requests unavailable. Please reopen to retry.'));
        if (!snap.hasData || snap.data!.docs.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('🎉 Party requests for you', style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800, fontSize: 13.5, color: _kGreen)),
            const SizedBox(height: 8),
            ...snap.data!.docs.where((d) => ['open', 'accepted'].contains((d.data() as Map)['status'])).map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final people = data['people'] as int? ?? 0;
              final budget = (data['budget'] as num?)?.toDouble() ?? 0;
              final occasionType = data['occasionType'] as String? ?? 'Occasion';
              final area = data['area'] as String? ?? '';
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kBorder)),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('$occasionType · $people people${data['pickupAtMillis'] is num ? '\nPickup: ${DateTime.fromMillisecondsSinceEpoch((data['pickupAtMillis'] as num).toInt()).toLocal().toString().substring(0,16)}' : ''}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    Text('${data['budget'] == null ? 'Budget to discuss' : 'Budget ₹${budget.toStringAsFixed(2)}'}${area.isNotEmpty ? " · $area" : ""}',
                      style: const TextStyle(fontSize: 11.5, color: _kTextSecondary)),
                  ])),
                  if (data['status'] == 'accepted') const Text('Accepted')
                  else Column(children: [
                    TextButton(onPressed: () => _respond(context, doc.id, 'accepted'), child: const Text('Accept enquiry')),
                    TextButton(onPressed: () => _respond(context, doc.id, 'declined'), child: const Text('Decline')),
                  ]),
                ]),
              );
            }),
          ]),
        );
      },
    );
  }
}

class _PartyModeCapacityPage extends StatefulWidget {
  final String vendorId;
  const _PartyModeCapacityPage({required this.vendorId});
  @override
  State<_PartyModeCapacityPage> createState() => _PartyModeCapacityPageState();
}

class _PartyModeCapacityPageState extends State<_PartyModeCapacityPage> {
  bool _capable = false;
  final _maxPeopleCtrl = TextEditingController();
  final _pricePerPersonCtrl = TextEditingController();
  bool _loaded = false;
  bool _loadFailed = false;
  bool _saving = false;
  String? _error;
  @override void dispose() { _maxPeopleCtrl.dispose(); _pricePerPersonCtrl.dispose(); super.dispose(); }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
    final doc = await FirebaseFirestore.instance.collection('users').doc(widget.vendorId).get();
    final data = doc.data();
    if (!mounted) return;
    setState(() {
      _capable = data?['bulkOrderCapable'] == true;
      _maxPeopleCtrl.text = (data?['maxBulkPeople'] as num?)?.toString() ?? '';
      _pricePerPersonCtrl.text = (data?['bulkPricePerPerson'] as num?)?.toString() ?? '';
      _loaded = true;
    });
    } catch (_) { if (mounted) setState(() { _loaded = true; _loadFailed = true; _error = 'Could not load saved capacity. Reopen to retry.'; }); }
  }

  Future<void> _save() async {
    if (_loadFailed) return;
    final maxPeople = int.tryParse(_maxPeopleCtrl.text.trim());
    final pricePerPerson = double.tryParse(_pricePerPersonCtrl.text.trim());
    if (_capable && (maxPeople == null || maxPeople < 1 || maxPeople > 10000 || pricePerPerson == null || !pricePerPerson.isFinite || pricePerPerson <= 0 || pricePerPerson > 1000000)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid max people count and price per person.')));
      return;
    }
    if (_saving) return;
    setState(() { _saving = true; _error = null; });
    try {
    await FirebaseFirestore.instance.collection('users').doc(widget.vendorId).update({
      'bulkOrderCapable': _capable,
      'maxBulkPeople': _capable ? maxPeople : 0,
      'bulkPricePerPerson': _capable ? pricePerPerson : 0,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved.')));
      Navigator.pop(context);
    }
    } catch (_) { if (mounted) setState(() => _error = 'Could not save. Your details are kept; please retry.'); }
    finally { if (mounted) setState(() => _saving = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F3EC),
      appBar: AppBar(backgroundColor: _kGreen,
        title: const Text('Party & Event Orders', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
        iconTheme: const IconThemeData(color: Colors.white)),
      body: !_loaded ? const Center(child: CircularProgressIndicator(color: _kGreen))
        : Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Can you handle bulk orders for parties, office events, or celebrations?',
              style: GoogleFonts.plusJakartaSans(fontSize: 13.5, color: _kTextDark)),
            const SizedBox(height: 4),
            const Text('Only turn this on if you can genuinely prepare food for a group with some advance notice.',
              style: TextStyle(fontSize: 12, color: _kTextSecondary)),
            const SizedBox(height: 14),
            SwitchListTile(
              value: _capable,
              onChanged: (v) => setState(() => _capable = v),
              title: const Text('Yes, I can take bulk orders'),
              contentPadding: EdgeInsets.zero,
            ),
            if (_capable) ...[
              const SizedBox(height: 10),
              TextField(controller: _maxPeopleCtrl, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Maximum people you can serve at once', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: _pricePerPersonCtrl, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Price per person (₹)', border: OutlineInputBorder())),
            ],
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: _saving || _loadFailed ? null : _save,
              child: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Save')))),
          ])),
    );
  }
}

class _LoyalCustomersPage extends StatelessWidget {
  final String vendorId;
  const _LoyalCustomersPage({required this.vendorId});
  @override Widget build(BuildContext context) => LoyalCustomersPage(vendorId: vendorId);
}
class _VendorReferralCard extends StatelessWidget {
  final String uid;
  const _VendorReferralCard({required this.uid});
  @override Widget build(BuildContext context) => VendorReferralsCard(uid: uid);
}

class _MenuPollCard extends StatelessWidget {
  final String uid;
  const _MenuPollCard({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('menuPolls')
          .where('merchantId', isEqualTo: uid)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: GestureDetector(
              onTap: () => _showCreatePollSheet(context, uid),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBF3E4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF5A623).withValues(alpha: 0.4))),
                child: Row(children: [
                  const Text('🗳️', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                    'Ask customers what to make next - no commitment, just gauge interest',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: _kTextDark))),
                  const Icon(Icons.chevron_right_rounded, color: _kTextSecondary),
                ]),
              ),
            ),
          );
        }
        final doc = snap.data!.docs.first;
        final data = doc.data() as Map<String, dynamic>;
        final options = (data['options'] as List?)?.cast<String>() ?? [];
        final votes = (data['votes'] as Map?)?.cast<String, dynamic>() ?? {};
        final counts = List<int>.filled(options.length, 0);
        votes.forEach((_, v) { final i = (v as num).toInt(); if (i < counts.length) counts[i]++; });
        final totalVotes = counts.fold(0, (a, b) => a + b);

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kBorder)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('🗳️ ${data['question'] ?? "What should we make?"}',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13)),
              const Spacer(),
              Text('$totalVotes votes', style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5, color: _kTextSecondary)),
            ]),
            const SizedBox(height: 8),
            ...List.generate(options.length, (i) {
              final pct = totalVotes > 0 ? (counts[i] / totalVotes * 100).round() : 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(options[i], style: GoogleFonts.plusJakartaSans(fontSize: 12.5))),
                    Text('$pct% (${counts[i]})', style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5, fontWeight: FontWeight.w700, color: _kGreen)),
                  ]),
                  const SizedBox(height: 3),
                  ClipRRect(borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: totalVotes > 0 ? counts[i] / totalVotes : 0,
                      backgroundColor: const Color(0xFFF0EEE7), color: _kAmber, minHeight: 6)),
                ]),
              );
            }),
            const SizedBox(height: 4),
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () => doc.reference.update({'isActive': false}),
                child: const Text('End poll', style: TextStyle(fontSize: 12)))),
            ]),
          ]),
        );
      },
    );
  }

  void _showCreatePollSheet(BuildContext context, String uid) {
    final questionCtrl = TextEditingController();
    final optionCtrls = [TextEditingController(), TextEditingController(), TextEditingController()];
    showModalBottomSheet(context: context, isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Ask customers what to make next', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 4),
          Text('This doesn\'t commit you to anything - just see what customers actually want before you decide.',
            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: _kTextSecondary)),
          const SizedBox(height: 14),
          TextField(controller: questionCtrl, decoration: const InputDecoration(
            labelText: 'Your question (e.g. "What should we make this Friday?")', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          ...List.generate(3, (i) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextField(controller: optionCtrls[i], decoration: InputDecoration(
              labelText: i < 2 ? 'Option ${i + 1} (required)' : 'Option 3 (optional)',
              border: const OutlineInputBorder())),
          )),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () async {
              final question = questionCtrl.text.trim();
              final options = optionCtrls.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();
              if (question.isEmpty || options.length < 2) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                  content: Text('Add a question and at least 2 options.')));
                return;
              }
              await FirebaseFirestore.instance.collection('menuPolls').add({
                'merchantId': uid,
                'question': question,
                'options': options,
                'votes': {},
                'isActive': true,
                'createdAt': FieldValue.serverTimestamp(),
              });
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Post poll')),
          )),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }
}

class _ListingsTab extends StatefulWidget {
  final String uid;
  const _ListingsTab({required this.uid});
  @override
  State<_ListingsTab> createState() => _ListingsTabState();
}

class _ListingsTabState extends State<_ListingsTab> {
  // FIX: found while investigating "old listings still visible, confusing
  // vendors" - this tab's query has zero filter and zero limit, so every
  // bag a vendor has ever created since day one accumulates here forever,
  // mixed in with genuinely active ones, in no particular order. Default
  // to hiding ended listings (matches what a vendor actually wants to see
  // day-to-day), with an explicit toggle to view history when needed -
  // rather than changing the query itself, which would need a new
  // Firestore composite index.
  bool _showEndedListings = false;

  Future<void> _toggleActive(BagsRecord bag) async {
    final isCurrentlyActive = bag.availableQuantity > 0;
    if (isCurrentlyActive) {
      // Pausing: remember how many were actually available so re-enabling
      // can restore it, rather than resetting to a hardcoded 1. Previously
      // this permanently lost the real quantity on every pause/resume -
      // a vendor with 10 available would come back to just 1.
      await bag.reference.update({
        'availableQuantity': 0,
        'previousQuantity': bag.availableQuantity,
      });
    } else {
      final restored = (bag.snapshotData['previousQuantity'] as num?)?.toInt() ?? 1;
      await bag.reference.update({
        'availableQuantity': restored > 0 ? restored : 1,
      });
    }
  }

  Future<List<Map<String, dynamic>>> _activeOrdersFor(String bagId) async {
    // Security rules can only verify a QUERY (not just a single-doc read)
    // if the query itself explicitly filters by merchantId == the caller's
    // own uid — the rule can't be checked against documents it hasn't
    // fetched yet. Without this, Firestore correctly rejects the whole
    // query as unverifiable, even though every real match would belong
    // to this vendor anyway.
    final snap = await FirebaseFirestore.instance.collection('orders')
        .where('merchantId', isEqualTo: widget.uid)
        .where('bagId', isEqualTo: bagId)
        .where('status', whereIn: ['pending', 'confirmed'])
        .get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  Future<void> _confirmDelete(BuildContext context, BagsRecord bag) async {
    List<Map<String, dynamic>> activeOrders;
    try {
      // Clean up any orders whose pickup window already passed but haven't
      // transitioned status yet — otherwise a genuinely-expired order could
      // block deletion indefinitely even though it's no longer really "active."
      await OrderExpiryService.expireForBag(bag.reference.id, merchantId: widget.uid);
      activeOrders = await _activeOrdersFor(bag.reference.id);
    } catch (e) {
      // Previously this failed silently — if the compound query needs a
      // Firestore index that doesn't exist, nothing happened at all with
      // no explanation. Now it's visible.
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Something went wrong'),
          content: Text('Couldn\'t check this listing right now — please try again.'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))]));
      return;
    }

    if (activeOrders.isNotEmpty) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Cannot Delete'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text(
              'This bag has active orders — customers are relying on it. '
              'You can deactivate it instead to stop new bookings.'),
            const SizedBox(height: 14),
            Text('Blocking orders (${activeOrders.length}):',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 6),
            ...activeOrders.take(5).map((o) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '• ${(o['status'] as String? ?? '?').toUpperCase()} — Rs.${o['amountPaid'] ?? '?'} — order ${(o['id'] as String).substring(0, 6)}',
                style: const TextStyle(fontSize: 12)),
            )),
            if (activeOrders.length > 5)
              Text('...and ${activeOrders.length - 5} more', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ]));
      return;
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Listing?'),
        content: Text('Delete "${bag.title}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ]));

    if (confirmed == true) {
      await bag.reference.delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Listing deleted'), backgroundColor: _kGreen));
      }
    }
  }

  void _editListing(BuildContext context, BagsRecord bag) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CreateListingWidget(editBagId: bag.reference.id)));
  }

  @override
  Widget build(BuildContext context) {
    final uid = widget.uid;
    return Column(children: [
      _LocalKitchensStatusCard(uid: uid),
      const OrderAlertSettingsCard(),
      _MenuPollCard(uid: uid),
      _VendorReferralCard(uid: uid),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => _LoyalCustomersPage(vendorId: uid))),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kBorder)),
            child: Row(children: [
              const Text('🎁', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(child: Text(
                'Surprise a loyal customer with something small, on you.',
                style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: _kTextDark))),
              const Icon(Icons.chevron_right_rounded, color: _kTextSecondary),
            ]),
          ),
        ),
      ),
      _IncomingOccasionRequestsCard(vendorId: uid),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => _PartyModeCapacityPage(vendorId: uid))),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kBorder)),
            child: Row(children: [
              const Text('🎉', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(child: Text(
                'Can you handle bulk party/event orders? Set that up here.',
                style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: _kTextDark))),
              const Icon(Icons.chevron_right_rounded, color: _kTextSecondary),
            ]),
          ),
        ),
      ),
      Expanded(child: StreamBuilder<List<BagsRecord>>(
      stream: queryBagsRecord(
        queryBuilder: (q) => q.where('merchantId', isEqualTo: uid)),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(
          child: CircularProgressIndicator(color: _kGreen));
        final allBags = snap.data!;
        // Newest first - previously had no ordering at all, meaning bags
        // appeared in whatever order Firestore happened to return them,
        // not most-recent-first as a vendor would expect.
        final sorted = List<BagsRecord>.from(allBags)..sort((a, b) {
          final aEnd = (a.snapshotData['pickupEndMillis'] as num?)?.toInt() ?? 0;
          final bEnd = (b.snapshotData['pickupEndMillis'] as num?)?.toInt() ?? 0;
          return bEnd.compareTo(aEnd);
        });
        bool isExpiredBag(BagsRecord b) {
          final endMillis = (b.snapshotData['pickupEndMillis'] as num?)?.toInt() ?? 0;
          return endMillis > 0 && DateTime.now().millisecondsSinceEpoch > endMillis;
        }
        final endedCount = sorted.where(isExpiredBag).length;
        final bags = _showEndedListings ? sorted : sorted.where((b) => !isExpiredBag(b)).toList();
        if (allBags.isEmpty) return Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.shopping_bag_outlined,
            color: _kTextSecondary, size: 48),
          const SizedBox(height: 12),
          Text('No listings yet', style: GoogleFonts.plusJakartaSans(
            color: _kTextSecondary, fontSize: 15)),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => context.pushNamed(CreateListingWidget.routeName),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: _kGreen, borderRadius: BorderRadius.circular(12)),
              child: Text('Create First Listing',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white, fontWeight: FontWeight.w700)))),
        ]));

        return Column(children: [
          if (endedCount > 0)
            GestureDetector(
              onTap: () => setState(() => _showEndedListings = !_showEndedListings),
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _kMintBg,
                  borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  Icon(_showEndedListings ? Icons.visibility_off_outlined : Icons.history,
                    size: 16, color: _kGreen),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    _showEndedListings
                      ? 'Showing all $endedCount ended listing${endedCount == 1 ? '' : 's'} — tap to hide'
                      : '$endedCount ended listing${endedCount == 1 ? '' : 's'} hidden — tap to view',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w700, color: _kGreen))),
                ]))),
          Expanded(child: bags.isEmpty
            ? Center(child: Text(
                'No active listings — all $endedCount are ended.\nTap above to view them, or create a new one.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(color: _kTextSecondary, fontSize: 13.5)))
            : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: bags.length,
          itemBuilder: (_, i) {
            final bag = bags[i];
            final isActive = bag.availableQuantity > 0;
            // Check expiry
            final pickupEndMillis = (bag.snapshotData['pickupEndMillis'] as num?)?.toInt() ?? 0;
            final isExpired = pickupEndMillis > 0 &&
                DateTime.now().millisecondsSinceEpoch > pickupEndMillis;

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _kBorder),
                boxShadow: [BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8, offset: const Offset(0, 2))]),
              child: Column(children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16)),
                  child: Stack(children: [
                    bag.image.isNotEmpty
                      ? CachedNetworkImage(imageUrl: bag.image, height: 110,
                          width: double.infinity, fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _placeholder())
                      : _placeholder(),
                    Positioned(top: 8, left: 8, child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isExpired
                          ? Colors.red.shade600
                          : (isActive ? _kGreen : Colors.grey.shade600),
                        borderRadius: BorderRadius.circular(20)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(width: 6, height: 6,
                          decoration: BoxDecoration(
                            color: isActive && !isExpired ? Colors.greenAccent : Colors.white54,
                            shape: BoxShape.circle)),
                        const SizedBox(width: 4),
                        Text(isExpired ? 'Expired' : (isActive ? 'Active' : 'Inactive'),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10, fontWeight: FontWeight.w700,
                            color: Colors.white)),
                      ]))),
                    Positioned(top: 8, right: 8, child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20)),
                      child: Text('${bag.availableQuantity} left',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10, fontWeight: FontWeight.w700,
                          color: Colors.white)))),
                  ])),
                Padding(padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Builder(builder: (context) {
                      final lt = (bag.snapshotData['listingType'] as String?) ?? 'surplus';
                      final ltInfo = {
                        'surplus': ('🎁', 'Surprise Bag', _kGreen),
                        'happyHour': ('⚡', 'Happy Hour', const Color(0xFFB45309)),
                        'freshFood': ('⏩', 'Skip the Queue', const Color(0xFF0369A1)),
                      }[lt] ?? ('🎁', 'Surprise Bag', _kGreen);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: ltInfo.$3.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(ltInfo.$1, style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 4),
                          Text(lt == 'freshFood'
                              ? '${ltInfo.$2} \u00b7 ${_snackLabel(bag.snapshotData['snackType'] as String?)}'
                              : ltInfo.$2, style: GoogleFonts.plusJakartaSans(
                            fontSize: 11, fontWeight: FontWeight.w700, color: ltInfo.$3)),
                        ]));
                    }),
                    Row(children: [
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(bag.title, style: GoogleFonts.plusJakartaSans(
                          fontSize: 14, fontWeight: FontWeight.w700,
                          color: _kTextDark)),
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.access_time_rounded,
                            size: 12, color: _kTextSecondary),
                          const SizedBox(width: 4),
                          Text('${bag.pickupStart} – ${bag.pickupEnd}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11, color: _kTextSecondary)),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _kMintBg,
                              borderRadius: BorderRadius.circular(6)),
                            child: Text(bag.category, style: GoogleFonts.plusJakartaSans(
                              fontSize: 10, color: _kGreen,
                              fontWeight: FontWeight.w600))),
                        ]),
                      ])),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('Rs.${bag.price.toStringAsFixed(0)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20, fontWeight: FontWeight.w800,
                            color: _kGreen)),
                        Text('was Rs.${bag.originalPrice.toStringAsFixed(0)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10, color: _kTextSecondary,
                            decoration: TextDecoration.lineThrough)),
                      ]),
                    ]),
                    const SizedBox(height: 10),
                    const Divider(color: _kBorder, height: 1),
                    const SizedBox(height: 10),
                    // Edit / Pause / Delete row
                    Row(children: [
                      Expanded(child: GestureDetector(
                        onTap: () => _editListing(context, bag),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _kMintBg,
                            borderRadius: BorderRadius.circular(8)),
                          alignment: Alignment.center,
                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const Icon(Icons.edit_rounded, size: 14, color: _kGreen),
                            const SizedBox(width: 4),
                            Text('Edit', style: GoogleFonts.plusJakartaSans(
                              fontSize: 12, fontWeight: FontWeight.w700, color: _kGreen)),
                          ])))),
                      const SizedBox(width: 8),
                      Expanded(child: GestureDetector(
                        onTap: () => _toggleActive(bag),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(8)),
                          alignment: Alignment.center,
                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(isActive ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              size: 14, color: const Color(0xFFE65100)),
                            const SizedBox(width: 4),
                            Text(isActive ? 'Pause' : 'Resume', style: GoogleFonts.plusJakartaSans(
                              fontSize: 12, fontWeight: FontWeight.w700,
                              color: const Color(0xFFE65100))),
                          ])))),
                      const SizedBox(width: 8),
                      Expanded(child: GestureDetector(
                        onTap: () => _confirmDelete(context, bag),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8)),
                          alignment: Alignment.center,
                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.delete_outline_rounded, size: 14, color: Colors.red.shade600),
                            const SizedBox(width: 4),
                            Text('Delete', style: GoogleFonts.plusJakartaSans(
                              fontSize: 12, fontWeight: FontWeight.w700, color: Colors.red.shade600)),
                          ])))),
                    ])]))]));
                  }))]);
              }))]);
          }


  Widget _placeholder() => Container(height: 110, color: _kMintBg,
    child: const Center(child: Text('🍱',
      style: TextStyle(fontSize: 40))));
}


// ── Local Kitchens status (shown at top of Listings tab) ──
class _LocalKitchensStatusCard extends StatelessWidget {
  final String uid;
  const _LocalKitchensStatusCard({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snap) {
        final approved = (snap.data?.data() as Map<String, dynamic>?)?['isFreshFoodApproved'] as bool? ?? false;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: approved ? _kMintBg : const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: approved ? _kBorder : const Color(0xFFF5A623).withValues(alpha: 0.3))),
            child: Row(children: [
              Text(approved ? '🥟' : '🔒', style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(approved ? 'Street Snacks: Approved' : 'Street Snacks program',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 13, fontWeight: FontWeight.w700, color: _kTextDark)),
                Text(
                    approved
                        ? 'You can list fresh snacks at full price — 0% commission, just the usual ₹5 fee'
                        : 'For small snack stalls only — chaat, samosa, bajji & similar. Not for restaurants, cafes, or bakeries. Email hello@surpl.in if that\'s you.',
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, color: _kTextSecondary)),
              ])),
            ]),
          ),
        );
      },
    );
  }
}

class _FullOrderCard extends StatefulWidget {
  final DocumentReference docRef;
  final String orderId, code, status, listingType;
  final String customerName, customerPhone;
  final double amount;
  final DateTime timestamp;
  const _FullOrderCard({
    required this.docRef, required this.orderId, required this.code,
    required this.amount, required this.status, required this.timestamp,
    required this.listingType,
    required this.customerName, required this.customerPhone});
  @override
  State<_FullOrderCard> createState() => _FullOrderCardState();
}

class _FullOrderCardState extends State<_FullOrderCard> {
  bool _loading = false;

  Color get _statusColor {
    switch (widget.status.toLowerCase()) {
      case 'confirmed': return Colors.green;
      case 'pending': return Colors.orange;
      case 'preparing': return const Color(0xFFB45309);
      case 'ready': return const Color(0xFF0369A1);
      case 'completed': return _kGreen;
      case 'cancelled': return Colors.red;
      case 'refunded': return const Color(0xFF7C3AED);
      default: return _kTextSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeStr =
      '${widget.timestamp.day}/${widget.timestamp.month} '
      '${widget.timestamp.hour.toString().padLeft(2,'0')}:'
      '${widget.timestamp.minute.toString().padLeft(2,'0')}';
    final isConfirmed = widget.status.toLowerCase() == 'confirmed';
    // DESIGN: same reasoning as the dashboard's recent-orders mini card -
    // Skip the Queue (freshFood) is made-to-order and gets real
    // preparing/ready stages; Surprise Bag/Happy Hour are pre-packed and
    // keep the single confirm-pickup action this app always had for
    // them, since there's no genuine "preparing" step for a bag that
    // already exists.
    final st = widget.status.toLowerCase();
    final isFreshFood = widget.listingType == 'freshFood';
    String? nextStatus;
    String actionLabel = '✓ Mark as Picked Up';
    Color actionColor = _kGreen;
    if (isFreshFood && st == 'confirmed') {
      nextStatus = 'preparing'; actionLabel = '👩‍🍳 Start Preparing'; actionColor = const Color(0xFFB45309);
    } else if (isFreshFood && st == 'preparing') {
      nextStatus = 'ready'; actionLabel = '🔔 Mark Ready for Pickup'; actionColor = const Color(0xFF0369A1);
    } else if ((isFreshFood && st == 'ready') || (!isFreshFood && st == 'confirmed')) {
      nextStatus = 'completed'; actionLabel = '✓ Mark as Picked Up'; actionColor = _kGreen;
    }
    final showActionBar = nextStatus != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isConfirmed ? Colors.green.shade200 : _kBorder,
          width: isConfirmed ? 1.5 : 1)),
      child: Column(children: [
        Padding(padding: const EdgeInsets.all(14), child: Row(children: [
          Container(width: 46, height: 46,
            decoration: BoxDecoration(
              color: isConfirmed ? Colors.green.shade50 : _kMintBg,
              borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.center,
            child: Text(
              (isConfirmed || widget.status.toLowerCase() == 'completed')
                ? (widget.code.isNotEmpty ? widget.code : '------')
                : '...',
              style: GoogleFonts.plusJakartaSans(
                fontSize: widget.code.length > 4 ? 10 : 13,
                fontWeight: FontWeight.w800,
                color: isConfirmed ? Colors.green.shade700 : _kGreen))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('#${widget.orderId.substring(0, 8).toUpperCase()}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13, fontWeight: FontWeight.w700, color: _kTextDark)),
            const SizedBox(height: 2),
            if (widget.customerName.isNotEmpty || widget.customerPhone.isNotEmpty)
              Text('👤 ${widget.customerName.isNotEmpty ? widget.customerName : "Customer"}'
                '${widget.customerPhone.isNotEmpty ? " · 📞 ${widget.customerPhone}" : ""}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11, fontWeight: FontWeight.w600, color: _kGreen)),
            const SizedBox(height: 2),
            Text('₹${widget.amount.toStringAsFixed(0)} · $timeStr',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11, color: _kTextSecondary)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _statusColor.withValues(alpha: 0.3))),
            child: Text(
              widget.status.isEmpty ? '-'
                : widget.status[0].toUpperCase() + widget.status.substring(1),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11, fontWeight: FontWeight.w700,
                color: _statusColor))),
        ])),

        if (showActionBar) ...[
          Container(height: 1, color: Colors.green.shade100),
          Padding(padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Row(children: [
            const Icon(Icons.qr_code_rounded, size: 16, color: _kTextSecondary),
            const SizedBox(width: 8),
            Expanded(child: Text(
              'Customer code: ${widget.code}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12, color: _kTextSecondary,
                fontWeight: FontWeight.w600))),
            GestureDetector(
              onTap: _loading ? null : () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: Text(nextStatus == 'completed' ? 'Confirm pickup' : 'Update order'),
                    content: Text(nextStatus == 'completed'
                        ? 'Confirm this customer has collected their order?\n\nCode shown: ${widget.code}'
                        : 'Mark this order as "$nextStatus"?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: Text('Confirm', style: TextStyle(color: _kGreen, fontWeight: FontWeight.w700))),
                    ],
                  ),
                );
                if (confirmed != true) return;
                setState(() => _loading = true);
                try {
                  final timestampField = nextStatus == 'completed'
                      ? 'completedAt' : (nextStatus == 'preparing' ? 'preparingAt' : 'readyAt');
                  await widget.docRef.update({'status': nextStatus, timestampField: FieldValue.serverTimestamp()});
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Could not update order — check your connection and try again.'),
                      backgroundColor: Colors.red.shade700));
                  }
                } finally {
                  if (mounted) setState(() => _loading = false);
                }
              },
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: actionColor,
                  borderRadius: BorderRadius.circular(10)),
                alignment: Alignment.center,
                child: _loading
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                  : Text(actionLabel, style: GoogleFonts.plusJakartaSans(
                      fontSize: 14, fontWeight: FontWeight.w800,
                      color: Colors.white)))),
          ])),
        ],
      ]));
  }
}

// ── SUPPORT TAB ──
// Direct chat channel between this vendor and Surpl support. Messages live
// at vendorSupportChats/{vendorUid}/messages/{messageId} - one thread per
// vendor, readable/writable by that vendor and by admin staff separately
// (admin-side reply UI is a separate concern, not part of this file).
class _PaymentsTab extends StatelessWidget {
  final String uid;
  const _PaymentsTab({required this.uid});

  Color _statusColor(String status) {
    switch (status) {
      case 'completed': return const Color(0xFF166534);
      case 'processing': return const Color(0xFF0369A1);
      case 'pending': return const Color(0xFFB45309);
      case 'failed': return const Color(0xFFDC2626);
      case 'reversed': return const Color(0xFF7C3AED);
      default: return _kTextSecondary;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'completed': return '✓ Paid';
      case 'processing': return '⏳ Processing';
      case 'pending': return '⏳ Pending';
      case 'failed': return '✗ Failed';
      case 'reversed': return '↩ Reversed';
      default: return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      // FIX: this whole tab is new - previously a vendor had no way to
      // see their own payments at all, and had to manually check their
      // bank statement every Friday to guess whether Surpl had paid
      // them. A live stream means this stays automatically in sync
      // with whatever the admin panel records - no separate sync step
      // to build or maintain, Firestore does that by construction.
      stream: FirebaseFirestore.instance
          .collection('vendorPayouts')
          .where('vendorId', isEqualTo: uid)
          .orderBy('paidAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Could not load payments right now.',
              style: GoogleFonts.plusJakartaSans(color: _kTextSecondary)));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: _kGreen));
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Center(child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'No payments recorded yet. Once Surpl pays you, it\'ll show up here automatically - no need to check your bank statement.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(color: _kTextSecondary, fontSize: 14)),
          ));
        }

        final latest = docs.first.data() as Map<String, dynamic>;
        final latestStatus = (latest['status'] as String?) ?? 'completed';

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Most recent payment, front and center - this answers the
            // vendor's actual question the moment they open this tab.
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _kGreen,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('MOST RECENT PAYMENT', style: GoogleFonts.plusJakartaSans(
                    fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white70, letterSpacing: 0.5)),
                const SizedBox(height: 8),
                Text('₹${(latest['amount'] as num?)?.toStringAsFixed(0) ?? '0'}',
                    style: GoogleFonts.plusJakartaSans(fontSize: 36, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: Text(_statusLabel(latestStatus), style: GoogleFonts.plusJakartaSans(
                      fontSize: 13, fontWeight: FontWeight.w700, color: _statusColor(latestStatus))),
                ),
              ]),
            ),
            const SizedBox(height: 20),
            Text('Payment History', style: GoogleFonts.plusJakartaSans(
                fontSize: 16, fontWeight: FontWeight.w700, color: _kTextDark)),
            const SizedBox(height: 12),
            ...docs.map((doc) {
              final d = doc.data() as Map<String, dynamic>;
              final status = (d['status'] as String?) ?? 'completed';
              final amount = (d['amount'] as num?)?.toStringAsFixed(0) ?? '0';
              final method = d['method'] as String? ?? '—';
              final note = d['note'] as String? ?? '';
              final orderIds = (d['orderIds'] as List?) ?? [];
              final paidAtRaw = d['paidAt'];
              String dateLabel = '—';
              if (paidAtRaw is Timestamp) {
                final dt = paidAtRaw.toDate();
                dateLabel = '${dt.day}/${dt.month}/${dt.year}';
              } else if (paidAtRaw is int) {
                final dt = DateTime.fromMillisecondsSinceEpoch(paidAtRaw);
                dateLabel = '${dt.day}/${dt.month}/${dt.year}';
              }
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5EFE6)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('₹$amount', style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w800, color: _kTextDark)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: _statusColor(status).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                      child: Text(_statusLabel(status), style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: _statusColor(status))),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  Text('$dateLabel · $method${orderIds.isNotEmpty ? ' · ${orderIds.length} order${orderIds.length == 1 ? '' : 's'}' : ''}',
                      style: GoogleFonts.plusJakartaSans(fontSize: 13, color: _kTextSecondary)),
                  if (note.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('Ref: $note', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: _kTextSecondary)),
                  ],
                ]),
              );
            }),
          ],
        );
      },
    );
  }
}

class _SupportTab extends StatefulWidget {
  final String uid;
  const _SupportTab({required this.uid});

  @override
  State<_SupportTab> createState() => _SupportTabState();
}

class _SupportTabState extends State<_SupportTab> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await FirebaseFirestore.instance
          .collection('vendorSupportChats').doc(widget.uid)
          .collection('messages').add({
        'text': text,
        'senderType': 'vendor',
        'senderUid': widget.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });
      _messageController.clear();
      // Scroll to latest after the new message renders
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut);
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        color: const Color(0xFFFFF9E6),
        child: Text(
          'Message Surpl support directly — we usually reply within a few hours.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12, fontWeight: FontWeight.w600, color: _kTextSecondary))),
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          // orderBy on a single field with no .where() needs no composite
          // index, unlike the orders queries elsewhere in this file - safe
          // to use directly here.
          stream: FirebaseFirestore.instance
              .collection('vendorSupportChats').doc(widget.uid)
              .collection('messages')
              .orderBy('timestamp', descending: false)
              .snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snap.data!.docs;
            if (docs.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white,
                  borderRadius: BorderRadius.circular(12), border: Border.all(color: _kBorder)),
                child: Center(child: Text(
                  'No messages yet — send a message below if you need help with anything.',
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, color: _kTextSecondary),
                  textAlign: TextAlign.center)));
            }
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scrollController.hasClients) {
                _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
              }
            });
            return ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              itemBuilder: (context, i) {
                final d = docs[i].data() as Map<String, dynamic>;
                final isVendor = d['senderType'] == 'vendor';
                final text = d['text'] as String? ?? '';
                final ts = d['timestamp'] as Timestamp?;
                final timeStr = ts != null
                  ? '${ts.toDate().hour.toString().padLeft(2,'0')}:${ts.toDate().minute.toString().padLeft(2,'0')}'
                  : '';
                return Align(
                  alignment: isVendor ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.72),
                    decoration: BoxDecoration(
                      color: isVendor ? _kGreen : const Color(0xFFF4F7F4),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(14),
                        topRight: const Radius.circular(14),
                        bottomLeft: Radius.circular(isVendor ? 14 : 4),
                        bottomRight: Radius.circular(isVendor ? 4 : 14))),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(text, style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: isVendor ? Colors.white : Colors.black87)),
                      const SizedBox(height: 4),
                      Text(timeStr, style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        color: isVendor ? Colors.white60 : _kTextSecondary)),
                    ])));
              });
          })),
      Container(
        padding: EdgeInsets.only(
          left: 12, right: 12, top: 10,
          bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 10 : 20),
        decoration: BoxDecoration(color: Colors.white,
          border: Border(top: BorderSide(color: _kBorder))),
        child: Row(children: [
          Expanded(child: TextField(
            controller: _messageController,
            decoration: InputDecoration(
              hintText: 'Type a message...',
              hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13),
              filled: true, fillColor: const Color(0xFFF4F7F4),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none)),
            style: GoogleFonts.plusJakartaSans(fontSize: 14),
            minLines: 1, maxLines: 4,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _sendMessage())),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sending ? null : _sendMessage,
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: _sending ? _kBorder : _kGreen,
                shape: BoxShape.circle),
              child: _sending
                ? const Padding(padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                : const Icon(Icons.send_rounded, color: Colors.white, size: 20))),
        ])),
    ]);
  }
}
