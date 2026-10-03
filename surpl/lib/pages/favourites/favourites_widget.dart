import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';

// The dedicated "My Favourites" list - separate from the per-vendor
// "Notify me" button already built on the bag detail page. That button
// subscribes a customer to one vendor at a time; this page is where
// they can see and manage everyone they've subscribed to in one place.
class FavouritesWidget extends StatelessWidget {
  const FavouritesWidget({Key? key}) : super(key: key);
  static String get routeName => 'Favourites';
  static String get routePath => '/favourites';

  static const _green = Color(0xFF1A4731);
  static const _greenDark = Color(0xFF0D1F12);
  static const _amber = Color(0xFFF5A623);
  static const _sage = Color(0xFF4D6B57);

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F3EC),
      appBar: AppBar(
        backgroundColor: _green,
        title: const Text('My Favourites', style: TextStyle(
          color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: uid == null
        ? const Center(child: Text('Please sign in to see your favourites.'))
        : StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator(color: _green));
              }
              final data = snap.data?.data() as Map<String, dynamic>?;
              final subscribed = ((data?['subscribedVendors'] as List?) ?? []).cast<String>();
              if (subscribed.isEmpty) {
                return Center(child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.favorite_border_rounded, size: 48, color: _sage),
                    const SizedBox(height: 12),
                    const Text('No favourites yet', style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15, color: _greenDark)),
                    const SizedBox(height: 4),
                    const Text('Tap "Notify me" on any vendor\'s page to add them here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _sage, fontSize: 12.5)),
                  ]),
                ));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: subscribed.length,
                itemBuilder: (context, i) => _FavouriteVendorRow(merchantId: subscribed[i]),
              );
            },
          ),
    );
  }
}

class _FavouriteVendorRow extends StatelessWidget {
  final String merchantId;
  const _FavouriteVendorRow({required this.merchantId});

  @override
  Widget build(BuildContext context) {
    // FIX: this was reading users/{merchantId} directly, which a
    // customer has zero permission to do - the entire Favourites list
    // was silently rendering empty for every customer, no matter how
    // many vendors they'd actually subscribed to. Same root cause and
    // same fix as VendorDetailWidget and Party Mode - routed through
    // the safe callable function instead.
    return FutureBuilder<Map<String, dynamic>?>(
      future: FirebaseFunctions.instanceFor(region: 'asia-south1')
          .httpsCallable('getPublicVendorInfo')
          .call({'vendorId': merchantId})
          .then<Map<String, dynamic>?>((result) => Map<String, dynamic>.from(result.data as Map))
          .catchError((_) => null),
      builder: (context, snap) {
        final data = snap.data;
        if (data == null) return const SizedBox.shrink();
        final shopName = data['shopName'] as String? ?? 'Local Vendor';
        final avgRating = (data['avgRating'] as num?)?.toDouble();
        final totalRatings = (data['totalRatings'] as num?)?.toInt() ?? 0;
        final shopArea = data['shopArea'] as String? ?? '';

        return GestureDetector(
          onTap: () => context.pushNamed(VendorDetailWidget.routeName,
            queryParameters: {'merchantId': merchantId}),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE8E8E8))),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: const Color(0xFFE6F4ED),
                  borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.storefront_rounded, color: Color(0xFF1A4731), size: 22)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(shopName, style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 14.5, color: Color(0xFF0D1F12))),
                const SizedBox(height: 2),
                Row(children: [
                  if (avgRating != null && totalRatings > 0) ...[
                    const Icon(Icons.star_rounded, color: Color(0xFFF5A623), size: 14),
                    Text(' ${avgRating.toStringAsFixed(1)}  ', style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4D6B57))),
                  ],
                  if (shopArea.isNotEmpty)
                    Text(shopArea, style: const TextStyle(fontSize: 12, color: Color(0xFF4D6B57))),
                ]),
              ])),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF4D6B57)),
            ]),
          ),
        );
      },
    );
  }
}
