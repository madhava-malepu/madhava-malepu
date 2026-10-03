import '/pages/community/loyal_customers_page.dart';
import '/services/location_service.dart';
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '/services/notification_service.dart';
import '/services/cart_service.dart';
import '/services/time_helpers.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

class HomeFeedWidget extends StatefulWidget {
  const HomeFeedWidget({Key? key}) : super(key: key);
  static String get routeName => 'HomeFeed';
  static String get routePath => '/homeFeed';
  @override
  State<HomeFeedWidget> createState() => _HomeFeedWidgetState();
}

class _HomeFeedWidgetState extends State<HomeFeedWidget> {
  static const _green = Color(0xFF1A4731);
  static const _amber = Color(0xFFF5A623);

  final _searchController = TextEditingController();
  StreamSubscription<RemoteMessage>? _notificationTapSub;
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _foodTypeFilter = 'all'; // 'all', 'veg', 'nonveg' — a distinct
  // filter button, not folded into the category chips, matching the
  // Zomato/Swiggy convention.
  String _locationText = 'Jagtial, Telangana';
  bool _isVendor = false;
  String _userName = '';
  int _cityMealsRescued = 0;
  bool _isFirstTimeUser = false;
  String _uid = '';

  final List<String> _categories = [
    'All','Bakery','Restaurant','Cafe','Grocery','Sweets','Other'
  ];

  // FIX: this list was genuinely hardcoded to Jagtial's own localities
  // and shown identically for every city - a Korutla customer would see
  // "Angadi Bazar" (a Jagtial-specific area) as a filter option, which is
  // exactly the confusion flagged. Now keyed per city instead.
  // Jagtial's list is the original, already-established one - unchanged.
  // The other 3 cities intentionally use a generic, honest starting list
  // rather than specific-sounding neighborhood names that haven't been
  // verified as real - these need real local knowledge to refine
  // properly before relying on them for actual area-based filtering.
  static const Map<String, List<String>> _areasByCity = {
    'Jagtial': [
      'Angadi Bazar', 'New Bus Stand', 'Old Bus Stand', 'Yawar Road',
      'Collectorate Road', 'Gandhi Chowk', 'Jagitial Fort Area',
      'RTC Colony', 'Bypass Road', 'Korutla Road', 'Other Area',
    ],
    'Korutla': [
      'Sairampura Colony', 'Hajipura', 'Kumariwada', 'Korutla Main Road',
      'Jagtial Road', 'Jhansi Road', 'Kallur Road', 'Raheempura', 'Other Area',
    ],
    'Karimnagar': [
      'Mukarampura', 'Vavilalapally', 'Jagtial Road', 'Ganesh Nagar',
      'Jyothinagar', 'Sai Nagar', 'Court Chowrastha', 'Kothirampur',
      'Christian Colony', 'Kothapalli', 'Other Area',
    ],
    'Warangal': [
      'Bus Stand Area', 'Railway Station Area', 'Main Market', 'Other Area',
    ],
  };
  List<String> get _jagtialAreas => _areasByCity[_customerCity] ?? _areasByCity['Jagtial']!;

  String _selectedArea = 'All Areas';
  double? _userLat;
  double? _userLng;

  // Verified city-center coordinates (Wikipedia, checked directly - not
  // from memory) for the 4 currently-supported cities. Used only to find
  // the nearest match for GPS auto-detection - a customer can always
  // override this manually via the city selector.
  static const Map<String, List<double>> _cityCenters = {
    'Jagtial': [18.7943, 78.9982],
    'Korutla': [18.8215, 78.7119],
    'Karimnagar': [18.4386, 79.1288],
    'Warangal': [17.9689, 79.5941],
  };
  // Defaults to Jagtial (matching the existing, already-migrated data)
  // until GPS detection completes or the customer picks manually. This
  // is deliberately plain state, not tied to the bags stream at all -
  // recreating that stream on every city change was exactly the
  // "blinking" bug already fixed elsewhere in this file, so city
  // filtering happens entirely in the existing client-side filter step
  // instead, alongside search/category/area.
  String _customerCity = 'Jagtial';

  String _nearestCity(double lat, double lng) {
    String nearest = 'Jagtial';
    double best = double.infinity;
    _cityCenters.forEach((city, coords) {
      final dist = Geolocator.distanceBetween(lat, lng, coords[0], coords[1]);
      if (dist < best) { best = dist; nearest = city; }
    });
    return nearest;
  }

  // Created once in initState, never recreated on rebuild — this is what
  // fixes the "blinking on every tap" issue. Previously this stream was
  // built inline inside StreamBuilder, so every setState() (tapping a
  // category, an area filter, typing in search) rebuilt the widget tree
  // and called queryBagsRecord() again, handing StreamBuilder a brand
  // new Stream object. StreamBuilder treats a new stream as a fresh
  // subscription and briefly shows its loading state before reconnecting
  // — that flash was the reported "blinking."
  late final Stream<List<BagsRecord>> _bagsStream;

  @override
  void initState() {
    super.initState();
    _bagsStream = queryBagsRecord(
        queryBuilder: (q) => q.where('isActive', isEqualTo: true).limit(100));
    _loadUserData();
    NotificationService.init();
    _checkForUnredeemedSurprises();
    // A notification tap (cold-start or backgrounded) sets this before
    // this screen even loads - check it here and navigate immediately,
    // rather than the customer landing on the home feed with no
    // indication why they got a notification or what to do about it.
    if (PendingNotificationNav.type != null && PendingNotificationNav.id != null) {
      final navType = PendingNotificationNav.type!;
      final navId = PendingNotificationNav.id!;
      PendingNotificationNav.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) => _navigateForNotification(navType, navId));
    }
    // Covers the case where this screen is already mounted (app
    // backgrounded while already on home feed, then a notification is
    // tapped) - the check above only runs once, at init, and won't
    // re-fire for an already-mounted widget.
    _notificationTapSub = FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final navType = message.data['type'] as String?;
      final navId = (message.data['orderId'] ?? message.data['bagId']) as String?;
      if (navType != null && navId != null) {
        _navigateForNotification(navType, navId);
      }
    });
  }

  // Gifts remain available until the issuing vendor confirms collection.
  Future<void> _checkForUnredeemedSurprises() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    try {
      final snap = await FirebaseFirestore.instance.collection('vendorSurprises')
          .where('customerId', isEqualTo: uid)
          .where('redeemed', isEqualTo: false)
          .limit(1)
          .get();
      if (snap.docs.isEmpty || !mounted) return;
      final doc = snap.docs.first;
      final data = doc.data();
      final message = data['message'] as String? ?? 'A little something on us!';
      String vendorName = 'A vendor';
      try {
        final result = await FirebaseFunctions.instanceFor(region: 'asia-south1')
            .httpsCallable('getPublicVendorInfo')
            .call({'vendorId': data['vendorId']});
        final vName = (result.data as Map)['shopName'] as String?;
        if (vName != null && vName.isNotEmpty) vendorName = vName;
      } catch (_) { /* fall back to generic name, not fatal */ }
      if (!mounted) return;
      showDialog(context: context, builder: (ctx) => AlertDialog(
        title: const Text('🎁 You got a surprise!'),
        content: Text('$vendorName sent you this:\n\n"$message"\n\nShow this to them on your next visit.'),
        actions: [TextButton(onPressed: () {
          Navigator.pop(ctx);
        }, child: const Text('Keep for later')), TextButton(onPressed: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerSurprisesPage())); }, child: const Text('My gifts'))],
      ));
    } catch (e) {
      // Silent failure by design - a missing surprise notification is
      // not worth interrupting the customer's home feed load over.
    }
  }

  void _navigateForNotification(String type, String id) {
    if (!mounted) return;
    if (type == 'order_update') {
      context.pushNamed(MyOrdersWidget.routeName);
    } else if (type == 'new_bag') {
      context.pushNamed(BagDetailWidget.routeName,
        queryParameters: {'bagId': id});
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _notificationTapSub?.cancel();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _uid = uid;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users').doc(uid).get();
      final data = doc.data();
      if (mounted) setState(() {
        _isVendor = data?['isVendor'] as bool? ?? false;
        _userName = data?['name'] as String? ?? '';
        _isFirstTimeUser = (data?['hasSeenOnboarding'] as bool?) != true;
        final area = data?['area'] as String?;
        if (area != null && area.isNotEmpty) _locationText = area;
        // Try to get real location name
        _detectRealLocation();
      });
      if (_isFirstTimeUser && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _showOnboarding());
      }
    } catch (_) {}
  }

  Future<void> _markOnboardingSeen() async {
    if (_uid.isEmpty) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(_uid)
          .set({'hasSeenOnboarding': true}, SetOptions(merge: true));
    } catch (_) {}
  }

  void _showOnboarding() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
          Row(children: [
            const Text('👋', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            const Text('How Surpl works', style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1A4731))),
          ]),
          const SizedBox(height: 16),
          _howItWorksStep('1', 'Browse bags from local restaurants below'),
          _howItWorksStep('2', 'Add bags to your cart and pay online — takes 30 seconds'),
          _howItWorksStep('3', 'Get a 6-digit pickup code instantly'),
          _howItWorksStep('4', 'Go to the shop, show your code, collect your bags!'),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(12)),
              alignment: Alignment.center,
              child: const Text('Got it', style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15))))),
        ]),
      ),
    ).then((_) => _markOnboardingSeen());
  }

  List<BagsRecord> _filterBags(List<BagsRecord> bags) {
    final nowMillis = DateTime.now().millisecondsSinceEpoch;
    final filtered = bags.where((bag) {
      final matchesSearch = _searchQuery.isEmpty ||
          bag.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          bag.category.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory =
          _selectedCategory == 'All' || bag.category == _selectedCategory;
      final bagFoodType = (bag.snapshotData['foodType'] as String?) ?? 'veg';
      final matchesFoodType = _foodTypeFilter == 'all' || bagFoodType == _foodTypeFilter;
      final bagArea = (bag.snapshotData['shopArea'] as String?) ?? 'Other Area';
      final matchesArea = _selectedArea == 'All Areas' || bagArea == _selectedArea;
      // THE core multi-city filter - a customer only ever sees bags from
      // their own detected/selected city. Every existing bag was tagged
      // "Jagtial" in the Step 1 migration, and every new bag inherits its
      // city automatically from the vendor's own account - so this
      // should always have a real value, but falls back safely to
      // "Jagtial" for any edge case, matching the same pattern already
      // used for shopArea just above.
      final bagCity = (bag.snapshotData['city'] as String?) ?? 'Jagtial';
      final matchesCity = bagCity == _customerCity;
      // Hide bags whose pickup window has already passed — this was
      // missing before, so expired bags kept showing as if available.
      final pickupEndMillis = (bag.snapshotData['pickupEndMillis'] as num?)?.toInt() ?? 0;
      var notExpired = pickupEndMillis == 0 || nowMillis <= pickupEndMillis;
      // Fallback safety net: bags created before pickupEndMillis existed
      // (or where it was never set) would otherwise never expire at all.
      // Treat anything older than 48 hours as stale regardless.
      if (pickupEndMillis == 0) {
        final createdAt = bag.snapshotData['createdAt'];
        if (createdAt is Timestamp) {
          final ageMillis = nowMillis - createdAt.millisecondsSinceEpoch;
          if (ageMillis > 48 * 60 * 60 * 1000) notExpired = false;
        }
      }
      return matchesSearch && matchesCategory && matchesFoodType && matchesArea && matchesCity && bag.availableQuantity > 0 && notExpired;
    }).toList();

    // "Near Me" default sort — nearest bags first. Bags without shopLat/
    // shopLng (older listings created before this field existed) fall
    // back to the end of the list rather than breaking the sort or
    // crashing — they simply don't have a known distance yet.
    if (_userLat != null && _userLng != null) {
      filtered.sort((a, b) {
        final ac = LocationService.vendorCoordinates(a.snapshotData);
        final bc = LocationService.vendorCoordinates(b.snapshotData);
        final aDist = LocationService.distanceKm(_userLat, _userLng, ac?.$1, ac?.$2) ?? double.infinity;
        final bDist = LocationService.distanceKm(_userLat, _userLng, bc?.$1, bc?.$2) ?? double.infinity;
        return aDist.compareTo(bDist);
      });
    }

    return filtered;
  }

  // ── Detect real location but keep Jagtial listings ──────────
  Future<void> _detectRealLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 5),
        ),
      );
      if (!LocationService.freshPosition(pos)) return;
      final detectedCity = _nearestCity(pos.latitude, pos.longitude);
      final distanceToDetectedKm = Geolocator.distanceBetween(
        pos.latitude, pos.longitude,
        _cityCenters[detectedCity]![0], _cityCenters[detectedCity]![1]) / 1000;
      if (mounted) {
        setState(() {
          _userLat = pos.latitude;
          _userLng = pos.longitude;
          // Only trust the GPS-detected city if genuinely close to one of
          // the 7 supported cities - someone testing the app from far
          // away (outside any supported city) keeps the Jagtial default
          // rather than being silently assigned to whichever city
          // happens to be nearest, however far that actually is.
          if (distanceToDetectedKm < 30) {
            _customerCity = detectedCity;
            _locationText = 'Near $detectedCity';
          } else {
            _locationText = '$_customerCity, Telangana';
          }
        });
      }
    } catch (_) {
      // Keep default Jagtial city/text if location fails
    }
  }

  void _showCitySelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      // FIX: without this, the sheet is capped at a default height that
      // doesn't account for real content - on shorter phone screens,
      // that caused a genuine "bottom overflowed by 8.0 pixels" render
      // error. isScrollControlled lets the sheet size itself to content
      // (up to the full screen), and wrapping the list below in a
      // SingleChildScrollView means it can never overflow again,
      // regardless of screen size or how many cities are ever added.
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Align(alignment: Alignment.centerLeft,
                  child: Text('Choose your city',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0D1F12)))),
              ),
              ..._cityCenters.keys.map((c) => ListTile(
                title: Text(c, style: TextStyle(
                  fontWeight: c == _customerCity ? FontWeight.w800 : FontWeight.w500,
                  color: c == _customerCity ? _green : const Color(0xFF0D1F12))),
                trailing: c == _customerCity ? const Icon(Icons.check_circle, color: _green) : null,
                onTap: () {
                  setState(() {
                    _customerCity = c;
                    _locationText = '$c, Telangana';
                    _selectedArea = 'All Areas';
                  });
                  Navigator.pop(ctx);
                },
              )),
              const SizedBox(height: 8),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _loadRescueCounter() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('city_stats')
          .doc('jagtial')
          .get();
      if (snap.exists && mounted) {
        setState(() {
          _cityMealsRescued = (snap.data()?['mealsRescued'] as int?) ?? 0;
        });
      }
    } catch (_) {}
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'morning';
    if (h < 17) return 'afternoon';
    return 'evening';
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'S';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  // Distinct Veg/Non-veg filter chip — separate from category chips,
  // matches the Zomato/Swiggy convention (color-coded square marker).
  Widget _foodTypeChip(String value, String label) {
    final sel = _foodTypeFilter == value;
    final isVeg = value == 'veg';
    final markerColor = isVeg
        ? const Color(0xFF1A8A3E)
        : (value == 'nonveg' ? const Color(0xFFA83232) : null);
    return GestureDetector(
      onTap: () => setState(() => _foodTypeFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: sel ? const Color(0xFFFFF3DC) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: sel ? _amber : const Color(0xFFE3E8E3),
            width: sel ? 1.5 : 1)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (markerColor != null) ...[
            Container(width: 12, height: 12,
              decoration: BoxDecoration(
                border: Border.all(color: markerColor, width: 1.3),
                borderRadius: BorderRadius.circular(2)),
              child: Center(child: Container(width: 6, height: 6,
                decoration: BoxDecoration(color: markerColor,
                  shape: isVeg ? BoxShape.circle : BoxShape.rectangle)))),
            const SizedBox(width: 6),
          ],
          Text(label, style: TextStyle(fontSize: 12.5,
            fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
            color: sel ? const Color(0xFF8A5A00) : const Color(0xFF4D5D53))),
        ]),
      ),
    );
  }

  String _categoryEmoji(String category) {
    switch (category) {
      case 'All': return '🍽️';
      case 'Bakery': return '🥐';
      case 'Restaurant': return '🍛';
      case 'Cafe': return '☕';
      case 'Grocery': return '🛒';
      case 'Sweets': return '🍬';
      default: return '🍴';
    }
  }

  Widget _buildComingSoonScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F3EC),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🚀', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 20),
              Text('Surpl is coming to $_customerCity soon!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800,
                  color: Color(0xFF0D1F12))),
              const SizedBox(height: 12),
              const Text(
                "We're not live here just yet, but we're working on it. "
                "Check back soon, or switch to a city that's already live.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14.5, color: Color(0xFF5B6B5F), height: 1.5)),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _showCitySelector,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: const Text('Switch City',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Jagtial is fully live; Korutla is actively launching next, so it
    // gets the normal home screen too (vendors are onboarding there).
    // Karimnagar and Warangal have no real activity yet - showing the
    // normal (empty) home screen there would be confusing, so they get
    // an explicit "coming soon" screen instead.
    if (!{'Jagtial', 'Korutla'}.contains(_customerCity)) {
      return _buildComingSoonScreen();
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_selectedCategory != 'All') {
          // A category filter (Restaurant/Bakery/Cafe/etc) is active —
          // back button clears it first, instead of exiting the app.
          setState(() => _selectedCategory = 'All');
          return;
        }
        // On Home with no filter active — this is a real exit attempt.
        // Confirm first so an accidental back press doesn't close the
        // app without warning.
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Exit Surpl?'),
            content: const Text('Are you sure you want to close the app?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text('Exit', style: TextStyle(color: Colors.red.shade600, fontWeight: FontWeight.w700))),
            ],
          ),
        );
        if (shouldExit == true) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
      backgroundColor: const Color(0xFFF5F8F5),
      body: Column(children: [
        // ── Pinned top section: greeting + Street Snacks + search bar ──
        Container(
          color: _green,
          padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 10, 16, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Text('Good ${_greeting()}! 👋',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7), fontSize: 13)),
                const SizedBox(height: 2),
                Row(children: [
                  const Icon(Icons.location_on, color: _amber, size: 14),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: _showCitySelector,
                    child: Row(children: [
                      Text(_locationText,
                        style: const TextStyle(
                          color: Colors.white, fontSize: 16,
                          fontWeight: FontWeight.w800)),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 18),
                    ]),
                  ),
                ]),
              ])),
              // Cart button
              GestureDetector(
                onTap: () => context.pushNamed(CartWidget.routeName),
                child: AnimatedBuilder(
                  animation: CartService(),
                  builder: (context, _) => Container(
                    width: 36, height: 36,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10)),
                    child: Stack(clipBehavior: Clip.none, children: [
                      const Center(child: Icon(Icons.shopping_bag_outlined,
                        color: Colors.white, size: 18)),
                      if (CartService().totalQuantity > 0)
                        Positioned(right: -4, top: -4,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                                color: _amber, shape: BoxShape.circle),
                            constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
                            child: Text('${CartService().totalQuantity}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: _green,
                                    fontSize: 9, fontWeight: FontWeight.w900)))),
                    ]),
                  ),
                )),
              IconButton(tooltip: 'My gifts', icon: const Icon(Icons.card_giftcard, color: Colors.white), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerSurprisesPage()))),
              // Referral button
              GestureDetector(
                onTap: () => _showReferral(context),
                child: Container(
                  width: 36, height: 36,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.redeem_rounded,
                    color: _amber, size: 20))),
            ]),
            const SizedBox(height: 12),
            // Street Snacks banner
            GestureDetector(
              onTap: () => context.pushNamed('LocalKitchens'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF7043), Color(0xFFF5A623)],
                    begin: Alignment.centerLeft, end: Alignment.centerRight),
                  borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  const Text('🥟', style: TextStyle(fontSize: 26)),
                  const SizedBox(width: 10),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Street Snacks', style: const TextStyle(
                        color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                      Text('Fresh chaat, samosa & more — order now',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 11)),
                    ])),
                  const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 14),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            // Search bar — rebuilt using TextField's own prefixIcon/
            // suffixIcon system instead of manually building a Row. The
            // manual approach was fighting Flutter's own text layout,
            // causing the vertical clipping and cramped width — this is
            // the standard, properly-tested way to build this.
            Container(
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10, offset: const Offset(0, 3))]),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v),
                textAlignVertical: TextAlignVertical.center,
                style: const TextStyle(color: Color(0xFF0D1F12), fontSize: 14.5),
                decoration: InputDecoration(
                  hintText: 'Search bags, restaurants...',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade500, fontSize: 14.5),
                  prefixIcon: Icon(Icons.search, color: Colors.grey.shade500, size: 22),
                  suffixIcon: _searchQuery.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        child: Icon(Icons.close, color: Colors.grey.shade400, size: 18))
                    : null,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ]),
        ),


        // ── Everything else lives in ONE single scrollable list —
        // header, filters, banners, and bag cards together. This means
        // the header/banners scroll away naturally as part of normal
        // list scrolling (like Uber Eats/Zomato/Swiggy), with zero
        // custom scroll-position tracking or animation code that could
        // fight the gesture the way the last two attempts did.
        Expanded(child: StreamBuilder<List<BagsRecord>>(
          stream: _bagsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(
                color: Color(0xFF1A4731)));
            }
            final bags = _filterBags(snapshot.data ?? []);
            if (bags.isEmpty) {
              return ListView(children: [
                // Category icons — light-theme version (this section now
                // scrolls with everything else, sitting on the white/light
                // list background instead of the green header, so it's
                // restyled for that context).
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: SizedBox(
                    height: 78,
                    child: ListView.builder(
                      key: const PageStorageKey('category_scroll'),
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      itemBuilder: (context, i) {
                        final cat = _categories[i];
                        final sel = _selectedCategory == cat;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedCategory = cat),
                          child: Container(
                            width: 62,
                            margin: const EdgeInsets.only(right: 10),
                            child: Column(children: [
                              Container(
                                width: 52, height: 52,
                                decoration: BoxDecoration(
                                  color: sel ? _amber : const Color(0xFFF4F7F4),
                                  shape: BoxShape.circle,
                                  border: sel ? null : Border.all(color: const Color(0xFFE3E8E3)),
                                  boxShadow: sel ? [BoxShadow(
                                    color: _amber.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 3))] : null,
                                ),
                                alignment: Alignment.center,
                                child: Text(_categoryEmoji(cat),
                                  textAlign: TextAlign.center,
                                  strutStyle: const StrutStyle(height: 1, forceStrutHeight: true),
                                  style: const TextStyle(fontSize: 24, height: 1)),
                              ),
                              const SizedBox(height: 5),
                              Text(cat, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: sel ? const Color(0xFF8A5A00) : const Color(0xFF4D5D53),
                                  fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
                                  fontSize: 11.5)),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),
                ),

        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Row(children: [
            _foodTypeChip('all', 'All'),
            const SizedBox(width: 8),
            _foodTypeChip('veg', 'Veg'),
            const SizedBox(width: 8),
            _foodTypeChip('nonveg', 'Non-Veg'),
          ]),
        ),

        // Self-pickup value banner — the core differentiator vs. delivery
        // apps, surfaced early on the home feed itself, not just tucked
        // away at checkout where a customer only sees it after they've
        // already decided to buy.
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFE6F4ED),
              borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              const Icon(Icons.directions_walk_rounded, size: 16, color: _green),
              const SizedBox(width: 7),
              Expanded(child: Text(
                'Self-pickup — no delivery fee, no surge pricing, no rider tip',
                style: const TextStyle(fontSize: 11.5, color: _green, fontWeight: FontWeight.w700))),
            ]),
          ),
        ),

        if (_cityMealsRescued > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: GestureDetector(
              onTap: () => context.pushNamed(ActivityFeedWidget.routeName),
              child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _green,
                borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                const Text('🌱', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Jagtial has rescued $_cityMealsRescued meals!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                    Text(
                      'Every bag you buy saves food from being wasted',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 11)),
                  ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5A623),
                    borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    '+1 per order',
                    style: const TextStyle(
                      color: Color(0xFF1A4731),
                      fontSize: 10,
                      fontWeight: FontWeight.w700))),
              ])),
            ),
          ),

        // ── Area filter ──
        Container(
          color: const Color(0xFFF4F7F4),
          padding: const EdgeInsets.fromLTRB(16, 10, 0, 8),
          child: SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: ['All Areas', ..._jagtialAreas].length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, i) {
                final area = ['All Areas', ..._jagtialAreas][i];
                final sel = _selectedArea == area;
                return GestureDetector(
                  onTap: () => setState(() => _selectedArea = area),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel ? _green : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: sel ? _green : const Color(0xFFD4E8D4))),
                    child: Text(area, style: TextStyle(
                      color: sel ? Colors.white : const Color(0xFF4D6B57),
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 12))));
              }))),

        // ── Quick access: Expiring Soon ──
        Container(
          color: const Color(0xFFF4F7F4),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          child: GestureDetector(
            onTap: () => context.pushNamed('ExpiringSoon'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF5A623).withValues(alpha: 0.3))),
              child: Row(children: [
                const Text('⏰', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 6),
                Text('Expiring soon near you', style: TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w600,
                  color: const Color(0xFFE65100))),
                const Spacer(),
                Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Colors.grey.shade500),
              ]),
            ),
          ),
        ),


                Center(child: Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                  Container(width: 72, height: 72,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE8F5EE), shape: BoxShape.circle),
                    child: const Icon(Icons.shopping_bag_outlined,
                      color: Color(0xFF1A4731), size: 36)),
                  const SizedBox(height: 16),
                  const Text('No bags available',
                    style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text('Check back later for surprise bags',
                    style: TextStyle(
                      color: Colors.grey.shade500, fontSize: 13)),
                ]))),
              ]);
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 100),
              children: [
                // Category icons — light-theme version (this section now
                // scrolls with everything else, sitting on the white/light
                // list background instead of the green header, so it's
                // restyled for that context).
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: SizedBox(
                    height: 78,
                    child: ListView.builder(
                      key: const PageStorageKey('category_scroll'),
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      itemBuilder: (context, i) {
                        final cat = _categories[i];
                        final sel = _selectedCategory == cat;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedCategory = cat),
                          child: Container(
                            width: 62,
                            margin: const EdgeInsets.only(right: 10),
                            child: Column(children: [
                              Container(
                                width: 52, height: 52,
                                decoration: BoxDecoration(
                                  color: sel ? _amber : const Color(0xFFF4F7F4),
                                  shape: BoxShape.circle,
                                  border: sel ? null : Border.all(color: const Color(0xFFE3E8E3)),
                                  boxShadow: sel ? [BoxShadow(
                                    color: _amber.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 3))] : null,
                                ),
                                alignment: Alignment.center,
                                child: Text(_categoryEmoji(cat),
                                  textAlign: TextAlign.center,
                                  strutStyle: const StrutStyle(height: 1, forceStrutHeight: true),
                                  style: const TextStyle(fontSize: 24, height: 1)),
                              ),
                              const SizedBox(height: 5),
                              Text(cat, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: sel ? const Color(0xFF8A5A00) : const Color(0xFF4D5D53),
                                  fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
                                  fontSize: 11.5)),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),
                ),

        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Row(children: [
            _foodTypeChip('all', 'All'),
            const SizedBox(width: 8),
            _foodTypeChip('veg', 'Veg'),
            const SizedBox(width: 8),
            _foodTypeChip('nonveg', 'Non-Veg'),
          ]),
        ),

        // Self-pickup value banner — the core differentiator vs. delivery
        // apps, surfaced early on the home feed itself, not just tucked
        // away at checkout where a customer only sees it after they've
        // already decided to buy.
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFE6F4ED),
              borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              const Icon(Icons.directions_walk_rounded, size: 16, color: _green),
              const SizedBox(width: 7),
              Expanded(child: Text(
                'Self-pickup — no delivery fee, no surge pricing, no rider tip',
                style: const TextStyle(fontSize: 11.5, color: _green, fontWeight: FontWeight.w700))),
            ]),
          ),
        ),

        if (_cityMealsRescued > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: GestureDetector(
              onTap: () => context.pushNamed(ActivityFeedWidget.routeName),
              child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _green,
                borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                const Text('🌱', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Jagtial has rescued $_cityMealsRescued meals!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                    Text(
                      'Every bag you buy saves food from being wasted',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 11)),
                  ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5A623),
                    borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    '+1 per order',
                    style: const TextStyle(
                      color: Color(0xFF1A4731),
                      fontSize: 10,
                      fontWeight: FontWeight.w700))),
              ])),
            ),
          ),

        // ── Area filter ──
        Container(
          color: const Color(0xFFF4F7F4),
          padding: const EdgeInsets.fromLTRB(16, 10, 0, 8),
          child: SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: ['All Areas', ..._jagtialAreas].length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, i) {
                final area = ['All Areas', ..._jagtialAreas][i];
                final sel = _selectedArea == area;
                return GestureDetector(
                  onTap: () => setState(() => _selectedArea = area),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel ? _green : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: sel ? _green : const Color(0xFFD4E8D4))),
                    child: Text(area, style: TextStyle(
                      color: sel ? Colors.white : const Color(0xFF4D6B57),
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 12))));
              }))),

        // ── Quick access: Expiring Soon ──
        Container(
          color: const Color(0xFFF4F7F4),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          child: GestureDetector(
            onTap: () => context.pushNamed('ExpiringSoon'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF5A623).withValues(alpha: 0.3))),
              child: Row(children: [
                const Text('⏰', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 6),
                Text('Expiring soon near you', style: TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w600,
                  color: const Color(0xFFE65100))),
                const Spacer(),
                Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Colors.grey.shade500),
              ]),
            ),
          ),
        ),


                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Row(children: [
                  Text('${bags.length} bag${bags.length == 1 ? '' : 's'} available',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15,
                      color: Colors.black87)),
                ])),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(children: _selectedArea != 'All Areas'
                    ? bags.map((b) => _BagCard(bag: b)).toList()
                    : _buildGroupedSections(bags, _customerCity)),
                ),
              ],
            );
          })),
      ]),
      bottomNavigationBar: const _SurplBottomNav(currentIndex: 0),
      ),
    );
  }

  void _showReferral(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final referralCode = uid.substring(0, 8).toUpperCase();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Container(width: 72, height: 72,
            decoration: const BoxDecoration(
              color: Color(0xFFE6F4ED), shape: BoxShape.circle),
            child: const Icon(Icons.redeem_rounded,
              color: Color(0xFF1A4731), size: 36)),
          const SizedBox(height: 16),
          const Text('Refer & Earn 🎁',
            style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w800,
              color: Color(0xFF0D1F12))),
          const SizedBox(height: 8),
          const Text(
            'Share your code with a friend. When they register and place their first order, you earn ₹20 Surpl Wallet credit. Your friend gets 10% off their first order!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13, color: Color(0xFF4D6B57), height: 1.5)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F7F4),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFD4E8D4))),
            child: Column(children: [
              const Text('YOUR REFERRAL CODE',
                style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: Color(0xFF4D6B57), letterSpacing: 1)),
              const SizedBox(height: 8),
              Text(referralCode,
                style: const TextStyle(
                  fontSize: 32, fontWeight: FontWeight.w900,
                  color: Color(0xFF1A4731), letterSpacing: 6)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  await _copyToClipboard(
                    '🎁 Hey! Join Surpl and get 10% OFF your first surprise food bag!\n\nUse my code *$referralCode* when you sign up.\n\nGet great food from local restaurants at 40-60% off in Jagtial! 🍱\n\nDownload: https://play.google.com/store/apps/details?id=com.surpl.app',
                    context);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A4731),
                    borderRadius: BorderRadius.circular(10)),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                    Icon(Icons.share_rounded,
                      color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text('Share Referral Link',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
                  ])))
            ])),
          const SizedBox(height: 14),
          // Referral stats — friends referred + total earned so far
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users').doc(uid).snapshots(),
            builder: (context, snapshot) {
              final count = (snapshot.data?.data()
                  as Map<String, dynamic>?)?['referralCount'] as int? ?? 0;
              final earned = count * 20;
              return Row(children: [
                Expanded(child: _referralStatCard('$count',
                  count == 1 ? 'Friend referred' : 'Friends referred')),
                const SizedBox(width: 10),
                Expanded(child: _referralStatCard('₹$earned', 'Total earned')),
              ]);
            },
          ),
          const SizedBox(height: 16),
          // How it works
          _referralStep('1', 'Share your code with friends'),
          _referralStep('2', 'Friend signs up using your code'),
          _referralStep('3', 'Friend places their first order'),
          _referralStep('4', 'You get ₹20 credit. Friend gets 10% off first order!'),
          const SizedBox(height: 8),
        ])));
  }

  Widget _referralStatCard(String value, String label) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: BoxDecoration(
      color: const Color(0xFFF4F7F4),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFD4E8D4))),
    child: Column(children: [
      Text(value, style: const TextStyle(
        fontSize: 22, fontWeight: FontWeight.w900,
        color: Color(0xFF1A4731))),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(
        fontSize: 11, color: Color(0xFF4D6B57))),
    ]),
  );

  Widget _howItWorksStep(String num, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Row(children: [
      Container(
        width: 20, height: 20,
        decoration: BoxDecoration(
          color: const Color(0xFFF5A623),
          shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Text(num, style: const TextStyle(
          fontSize: 11, fontWeight: FontWeight.w800,
          color: Color(0xFF1A4731)))),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: const TextStyle(
        fontSize: 12, color: Color(0xFF7B4F00)))),
    ]));

  Widget _referralStep(String num, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Container(width: 28, height: 28,
        decoration: const BoxDecoration(
          color: Color(0xFFF5A623), shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Text(num, style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w800,
          color: Color(0xFF1A4731)))),
      const SizedBox(width: 12),
      Text(text, style: const TextStyle(
        fontSize: 13, color: Color(0xFF4D6B57))),
    ]));

  Future<void> _copyToClipboard(String text, BuildContext ctx) async {
    // Try WhatsApp first
    final encoded = Uri.encodeComponent(text);
    final whatsappUri = Uri.parse('https://wa.me/?text=$encoded');
    try {
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Fallback: copy to clipboard
      await Clipboard.setData(ClipboardData(text: text));
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: const Text('Referral message copied! Paste it on WhatsApp.'),
          backgroundColor: const Color(0xFF1A4731),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
      }
    }
  }
}

// ── Bag Card ──
String _snackLabel(String? type) {
  const labels = {
    'chaat': 'Chaat',
    'samosa': 'Samosa / Kachori',
    'bajji': 'Bajji / Fritters',
    'other_snack': 'Other Snacks',
  };
  return labels[type] ?? 'Snacks';
}

class _BagCard extends StatefulWidget {
  final BagsRecord bag;
  const _BagCard({required this.bag});

  @override
  State<_BagCard> createState() => _BagCardState();
}

class _BagCardState extends State<_BagCard> {
  static const _green = Color(0xFF1A4731);
  static const _amber = Color(0xFFF5A623);
  static const _lightGreen = Color(0xFFE8F5EE);

  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    // Ticks once a minute so the pickup countdown stays live without
    // needing the underlying Firestore data to change.
    _countdownTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  Future<void> _toggleSave(bool currentlySaved) async {
    final uid = _uid;
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'savedBags': currentlySaved
          ? FieldValue.arrayRemove([widget.bag.reference.id])
          : FieldValue.arrayUnion([widget.bag.reference.id]),
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    // Same fix as bag_detail_widget.dart: widget.bag.price includes a
    // silent 5% GST markup the vendor never sees or intended as part of
    // their discount - dividing it back out here means the "% off"
    // shown on this card matches the vendor's real, intended discount.
    // Price is the vendor's real, unmarked-up value directly - no GST
    // markup exists at the source anymore.
    final vendorRealPrice = widget.bag.price;
    final savings = widget.bag.originalPrice > 0
        ? (((widget.bag.originalPrice - vendorRealPrice) / widget.bag.originalPrice) * 100).round()
        : 0;
    final qty = widget.bag.availableQuantity;
    final isLow = qty <= 2 && qty > 0;
    final uid = _uid;

    return GestureDetector(
      onTap: () => context.pushNamed(BagDetailWidget.routeName,
          queryParameters: {'bagId': widget.bag.reference.id}),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10, offset: const Offset(0, 3))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16)),
              child: widget.bag.image.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: widget.bag.image,
                      height: 160, width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (ctx, url) => Container(
                          height: 160, color: _lightGreen,
                          child: const Center(child: CircularProgressIndicator(
                            color: _green, strokeWidth: 2))),
                      errorWidget: (_, __, ___) => _placeholder())
                  : _placeholder()),
            if (savings > 0) Positioned(top: 10, left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _amber, borderRadius: BorderRadius.circular(20)),
                child: Text('Save $savings%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800, fontSize: 11)))),
            if (isLow) Positioned(top: 10, right: 48,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.shade600,
                  borderRadius: BorderRadius.circular(20)),
                child: Text('Only $qty left!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700, fontSize: 11)))),
            // FIX: a customer browsing the feed had no way to tell Happy
            // Hour or Skip the Queue apart from a regular Surprise Bag
            // until they tapped in - the detail page already made this
            // distinction, the feed card never did. Placed bottom-left on
            // the image so it doesn't collide with Save% (top-left) or
            // the stock/heart badges (top-right).
            Positioned(bottom: 10, left: 10,
              child: Builder(builder: (context) {
                final lt = (widget.bag.snapshotData['listingType'] as String?) ?? 'surplus';
                final ltInfo = {
                  'surplus': ('🎁', 'Surprise Bag', _green),
                  'happyHour': ('⚡', 'Happy Hour', const Color(0xFFB45309)),
                  'freshFood': ('⏩', 'Skip the Queue', const Color(0xFF0369A1)),
                }[lt] ?? ('🎁', 'Surprise Bag', _green);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12), blurRadius: 4)]),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(ltInfo.$1, style: const TextStyle(fontSize: 11)),
                    const SizedBox(width: 3),
                    Text(lt == 'freshFood'
                        ? '${ltInfo.$2} \u00b7 ${_snackLabel(widget.bag.snapshotData['snackType'] as String?)}'
                        : ltInfo.$2, style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w800, color: ltInfo.$3)),
                  ]));
              })),
            // Heart — StreamBuilder for live updates
            Positioned(top: 8, right: 8,
              child: uid == null
                ? const SizedBox.shrink()
                : StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users').doc(uid).snapshots(),
                    builder: (context, snap) {
                      final data = snap.data?.data() as Map<String, dynamic>?;
                      final saved = List<String>.from(
                        data?['savedBags'] ?? []);
                      final isSaved = saved.contains(widget.bag.reference.id);
                      return GestureDetector(
                        onTap: () => _toggleSave(isSaved),
                        child: Container(
                          width: 34, height: 34,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 6)]),
                          child: Icon(
                            isSaved
                              ? Icons.favorite
                              : Icons.favorite_border,
                            color: isSaved
                              ? _amber
                              : Colors.grey.shade400,
                            size: 18)));
                    })),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Row(children: [
                Builder(builder: (context) {
                  final foodType = (widget.bag.snapshotData['foodType'] as String?) ?? 'veg';
                  final isVeg = foodType == 'veg';
                  final markerColor = isVeg ? const Color(0xFF1A8A3E) : const Color(0xFFA83232);
                  final bgColor = isVeg ? const Color(0xFFEAF7EE) : const Color(0xFFFBEAEA);
                  // FIX: previously a 14x14px icon with no text at all -
                  // easy to miss entirely. Now a proper pill badge: the
                  // same universally-recognized square-and-dot symbol,
                  // large enough to actually notice, plus a text label so
                  // it reads correctly even at a glance.
                  return Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: markerColor.withValues(alpha: 0.4), width: 1)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(width: 12, height: 12,
                        decoration: BoxDecoration(
                          border: Border.all(color: markerColor, width: 1.5),
                          borderRadius: BorderRadius.circular(2)),
                        child: Center(child: Container(width: 6, height: 6,
                          decoration: BoxDecoration(color: markerColor,
                            shape: isVeg ? BoxShape.circle : BoxShape.rectangle)))),
                      const SizedBox(width: 4),
                      Text(isVeg ? 'VEG' : 'NON-VEG',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800,
                          color: markerColor, letterSpacing: 0.3)),
                    ]),
                  );
                }),
                Expanded(child: Text(widget.bag.title,
                  style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700,
                    color: Colors.black87),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                if (widget.bag.category.isNotEmpty) Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _lightGreen,
                    borderRadius: BorderRadius.circular(20)),
                  child: Text(widget.bag.category,
                    style: const TextStyle(
                      color: _green, fontSize: 10,
                      fontWeight: FontWeight.w600))),
              ]),
              const SizedBox(height: 3),
              // ── Vendor/Restaurant name + live rating ─────────
              Builder(builder: (context) {
                final name = (widget.bag.snapshotData['merchantName'] as String?) ?? '';
                final merchantId = (widget.bag.snapshotData['merchantId'] as String?) ?? '';
                if (name.isEmpty) return const SizedBox.shrink();
                return Row(children: [
                  Icon(Icons.storefront_rounded,
                    color: _green.withValues(alpha: 0.7), size: 13),
                  const SizedBox(width: 3),
                  Expanded(child: Text(name,
                    style: const TextStyle(
                      color: _green,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis)),
                  // Live rating — fetched fresh, not copied onto the bag
                  // at creation time, since a vendor's reputation changes
                  // over time and a stale snapshot would mislead
                  // customers (and undersell a vendor who's since earned
                  // great reviews).
                  if (merchantId.isNotEmpty)
                    FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('users').doc(merchantId).get(),
                      builder: (context, snap) {
                        if (!snap.hasData || !snap.data!.exists) return const SizedBox.shrink();
                        final data = snap.data!.data() as Map<String, dynamic>?;
                        final avgRating = (data?['avgRating'] as num?)?.toDouble();
                        final totalRatings = (data?['totalRatings'] as num?)?.toInt() ?? 0;
                        if (avgRating == null || totalRatings == 0) return const SizedBox.shrink();
                        return Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.star_rounded, color: _amber, size: 13),
                          const SizedBox(width: 2),
                          Text('${avgRating.toStringAsFixed(1)} ($totalRatings)',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _amber)),
                        ]);
                      },
                    ),
                ]);
              }),
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.schedule,
                  color: Colors.grey.shade400, size: 13),
                const SizedBox(width: 3),
                Text('${widget.bag.pickupStart} – ${widget.bag.pickupEnd}',
                  style: TextStyle(
                    color: Colors.grey.shade500, fontSize: 12)),
                Builder(builder: (context) {
                  final ts = widget.bag.snapshotData['createdAt'];
                  final createdAt = ts is Timestamp ? ts.toDate() : null;
                  final label = TimeHelpers.listedAgo(createdAt);
                  if (label.isEmpty) return const SizedBox.shrink();
                  return Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('  •  ', style: TextStyle(color: Colors.grey.shade300, fontSize: 12)),
                    Text(label, style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                  ]);
                }),
              ]),
              // Live countdown — "Pickup in 2h 15m" — ticks every minute
              // via the Timer in initState. Uses the pickupEndMillis field
              // already stored on every bag; no new data needed.
              Builder(builder: (context) {
                final endMillis = (widget.bag.snapshotData['pickupEndMillis'] as num?)?.toInt() ?? 0;
                if (endMillis == 0) return const SizedBox.shrink();
                final remainingMs = endMillis - DateTime.now().millisecondsSinceEpoch;
                if (remainingMs <= 0) return const SizedBox.shrink();
                final totalMinutes = (remainingMs / 60000).ceil();
                final hours = totalMinutes ~/ 60;
                final mins = totalMinutes % 60;
                final urgent = totalMinutes <= 30;
                final label = hours > 0 ? 'Pickup in ${hours}h ${mins}m' : 'Pickup in ${mins}m';
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(children: [
                    Icon(Icons.timer_outlined, size: 13,
                      color: urgent ? const Color(0xFFDC2626) : _amber),
                    const SizedBox(width: 3),
                    Text(label, style: TextStyle(
                      color: urgent ? const Color(0xFFDC2626) : const Color(0xFF8A5A00),
                      fontWeight: FontWeight.w700, fontSize: 12)),
                  ]),
                );
              }),
              const SizedBox(height: 12),
              Row(children: [
                Text('₹${widget.bag.price.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w900,
                    color: _green)),
                const SizedBox(width: 6),
                if (widget.bag.originalPrice > widget.bag.price)
                  Text('₹${widget.bag.originalPrice.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 13, color: Colors.grey.shade400,
                      decoration: TextDecoration.lineThrough)),
                const Spacer(),
                GestureDetector(
                  onTap: () => context.pushNamed(
                    CheckoutWidget.routeName,
                    queryParameters: {'bagId': widget.bag.reference.id}),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _amber,
                      borderRadius: BorderRadius.circular(10)),
                    child: const Text('Book Now',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)))),
              ]),
            ])),
        ])));
  }

  Widget _placeholder() => Container(
    height: 160, color: const Color(0xFFE8F5EE),
    child: const Center(child: Icon(
      Icons.shopping_bag, color: Color(0xFF1A4731), size: 48)));
}

// ── Bottom Nav ──
class _SurplBottomNav extends StatelessWidget {
  final int currentIndex;
  const _SurplBottomNav({required this.currentIndex});
  static const _green = Color(0xFF1A4731);

  @override
  Widget build(BuildContext context) {
    final items = [
      _N(Icons.home_rounded, 'Home', HomeFeedWidget.routeName),
      _N(Icons.receipt_long_rounded, 'Orders', MyOrdersWidget.routeName),
      _N(Icons.favorite_rounded, 'Saved', SavedBagsWidget.routeName),
      _N(Icons.person_rounded, 'Profile', ProfileWidget.routeName),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 16, offset: const Offset(0, -4))]),
      child: SafeArea(top: false, child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: items.asMap().entries.map((e) {
            final i = e.key;
            final item = e.value;
            final sel = i == currentIndex;
            return GestureDetector(
              onTap: () {
                if (sel) return;
                if (item.route == HomeFeedWidget.routeName) {
                  context.goNamed(item.route);
                } else {
                  context.pushNamed(item.route);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: sel
                    ? const Color(0xFFE8F5EE)
                    : Colors.transparent,
                  borderRadius: BorderRadius.circular(12)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(item.icon,
                    color: sel ? _green : Colors.grey.shade400,
                    size: 24),
                  const SizedBox(height: 3),
                  Text(item.label, style: TextStyle(
                    color: sel ? _green : Colors.grey.shade400,
                    fontSize: 10,
                    fontWeight: sel
                      ? FontWeight.w700
                      : FontWeight.w500)),
                ])));
          }).toList()))));
  }
}

class _N {
  final IconData icon;
  final String label;
  final String route;
  const _N(this.icon, this.label, this.route);
}

// ── Grouped bag list by area ──────────────────────────────────────────
List<Widget> _buildGroupedSections(List<BagsRecord> bags, String city) {
  // FIX: previously hardcoded to Jagtial's own areas regardless of which
  // city was actually selected - now uses the same shared, city-keyed
  // map as the area filter dropdown, so both stay consistent.
  final areaOrder = _HomeFeedWidgetState._areasByCity[city] ??
      _HomeFeedWidgetState._areasByCity['Jagtial']!;
  // Group bags by area
  final Map<String, List<BagsRecord>> grouped = {};
  for (final bag in bags) {
    final area = (bag.snapshotData['shopArea'] as String?)?.isNotEmpty == true
        ? bag.snapshotData['shopArea'] as String
        : 'Other Area';
    grouped.putIfAbsent(area, () => []).add(bag);
  }

  // Build ordered sections
  final List<Widget> sections = [];
  for (final area in areaOrder) {
    final areaBags = grouped[area];
    if (areaBags == null || areaBags.isEmpty) continue;
    sections.add(_AreaSection(area: area, bags: areaBags));
  }
  // Any area not in list (shouldn't happen but safety net)
  for (final area in grouped.keys) {
    if (!areaOrder.contains(area)) {
      sections.add(_AreaSection(area: area, bags: grouped[area]!));
    }
  }
  return sections;
}

class _AreaSection extends StatelessWidget {
  final String area;
  final List<BagsRecord> bags;
  const _AreaSection({required this.area, required this.bags});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Row(children: [
          const Icon(Icons.location_on_rounded,
            color: Color(0xFF1A4731), size: 14),
          const SizedBox(width: 4),
          Text(area, style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w700,
            color: Color(0xFF1A4731))),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFE6F4ED),
              borderRadius: BorderRadius.circular(20)),
            child: Text('${bags.length}', style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: Color(0xFF1A4731)))),
          Expanded(child: Container(
            margin: const EdgeInsets.only(left: 10),
            height: 1,
            color: const Color(0xFFD4E8D4))),
        ])),
      ...groupBagsByVendor(bags).map((group) => _VendorGroupCard(group: group)),
    ]);
  }
}

// Groups an already-filtered bag list by merchantId - deliberately by
// ID, not by shop name, since two different physical outlets could
// share a similar or identical name (explicit requirement: don't merge
// different pickup locations just because they're named alike).
class VendorBagGroup {
  final String merchantId;
  final String merchantName;
  final String vendorAddress;
  final double? avgRating;
  final int totalRatings;
  final List<BagsRecord> bags;
  VendorBagGroup({required this.merchantId, required this.merchantName,
    required this.vendorAddress, required this.avgRating,
    required this.totalRatings, required this.bags});
}

List<VendorBagGroup> groupBagsByVendor(List<BagsRecord> bags) {
  final Map<String, List<BagsRecord>> byMerchant = {};
  for (final bag in bags) {
    final id = (bag.snapshotData['merchantId'] as String?) ?? '';
    if (id.isEmpty) continue;
    byMerchant.putIfAbsent(id, () => []).add(bag);
  }
  return byMerchant.entries.map((entry) {
    final first = entry.value.first;
    return VendorBagGroup(
      merchantId: entry.key,
      merchantName: (first.snapshotData['merchantName'] as String?) ?? 'Local Vendor',
      vendorAddress: (first.snapshotData['vendorAddress'] as String?) ?? '',
      avgRating: (first.snapshotData['avgRating'] as num?)?.toDouble(),
      totalRatings: (first.snapshotData['totalRatings'] as num?)?.toInt() ?? 0,
      bags: entry.value,
    );
  }).toList();
}

class _VendorGroupCard extends StatelessWidget {
  final VendorBagGroup group;
  const _VendorGroupCard({required this.group});

  @override
  Widget build(BuildContext context) {
    // A single-bag vendor is shown exactly as before (the original,
    // familiar bag card) - grouping only changes the experience once
    // there's genuinely more than one bag to group.
    if (group.bags.length == 1) return _BagCard(bag: group.bags.first);

    return GestureDetector(
      onTap: () => context.pushNamed(VendorDetailWidget.routeName,
        queryParameters: {'merchantId': group.merchantId}),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE8E8E8)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8, offset: const Offset(0, 2))]),
        child: Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: const Color(0xFFE6F4ED),
              borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.storefront_rounded, color: Color(0xFF1A4731), size: 24)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(group.merchantName, style: const TextStyle(
              fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0D1F12))),
            const SizedBox(height: 3),
            Row(children: [
              if (group.avgRating != null && group.totalRatings > 0) ...[
                const Icon(Icons.star_rounded, color: Color(0xFFF5A623), size: 15),
                const SizedBox(width: 2),
                Text('${group.avgRating!.toStringAsFixed(1)} (${group.totalRatings})',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF4D6B57))),
                const SizedBox(width: 8),
              ],
              Text('${group.bags.length} bags available',
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF4D6B57))),
            ]),
            if (group.vendorAddress.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(group.vendorAddress,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF999999))),
            ],
          ])),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFF4D6B57)),
        ]),
      ),
    );
  }
}
