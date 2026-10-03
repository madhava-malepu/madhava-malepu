import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';

// The customer-facing "vendor page" - shown when a customer taps a
// grouped vendor card on the home feed. Deliberately NOT a merge of
// underlying data: each bag listed here still has its own price,
// quantity, and collection window, and tapping one goes to the exact
// same bag_detail/checkout flow as before. This page is purely a
// browsing layer on top of what already exists.
class VendorDetailWidget extends StatefulWidget {
  const VendorDetailWidget({Key? key, required this.merchantId}) : super(key: key);
  final String merchantId;
  static String get routeName => 'VendorDetail';
  static String get routePath => '/vendorDetail';
  @override
  State<VendorDetailWidget> createState() => _VendorDetailWidgetState();
}

class _VendorDetailWidgetState extends State<VendorDetailWidget> {
  static const _green = Color(0xFF1A4731);
  static const _greenDark = Color(0xFF0D1F12);
  static const _amber = Color(0xFFF5A623);
  static const _sage = Color(0xFF4D6B57);
  static const _mintBg = Color(0xFFE6F4ED);

  late Future<Map<String, dynamic>?> _vendorInfoFuture;

  @override
  void initState() {
    super.initState();
    // FIX: this page previously listened directly to
    // users/{merchantId}, which a customer has no permission to read
    // at all - that document also holds bank/UPI details, so the fix
    // isn't opening up read access, it's routing through the callable
    // function that returns only the safe fields. This is a one-time
    // fetch, not a live listener, since Cloud Functions can't stream -
    // an acceptable tradeoff given the alternative was a hard
    // permission-denied error every time this page loaded.
    _vendorInfoFuture = FirebaseFunctions.instanceFor(region: 'asia-south1')
        .httpsCallable('getPublicVendorInfo')
        .call({'vendorId': widget.merchantId})
        .then<Map<String, dynamic>?>((result) => Map<String, dynamic>.from(result.data as Map))
        .catchError((_) => null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F3EC),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _vendorInfoFuture,
        builder: (context, vendorSnap) {
          if (vendorSnap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: _green));
          }
          final vendorData = vendorSnap.data ?? {};
          final shopName = vendorData['shopName'] as String? ?? 'Local Vendor';
          final avgRating = (vendorData['avgRating'] as num?)?.toDouble();
          final totalRatings = (vendorData['totalRatings'] as num?)?.toInt() ?? 0;
          final vendorStory = vendorData['vendorStory'] as String? ?? '';
          final shopArea = vendorData['shopArea'] as String? ?? '';
          final shopAddress = vendorData['shopAddress'] as String? ?? '';
          final fssaiNumber = vendorData['fssaiNumber'] as String? ?? '';

          return CustomScrollView(slivers: [
            SliverAppBar(
              backgroundColor: _green,
              pinned: true,
              expandedHeight: 150,
              iconTheme: const IconThemeData(color: Colors.white),
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 56, bottom: 14, right: 16),
                title: Text(shopName, style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                background: Container(color: _green,
                  child: const Center(child: Icon(Icons.storefront_rounded,
                    color: Colors.white24, size: 64))),
              ),
            ),
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  if (avgRating != null && totalRatings > 0) ...[
                    const Icon(Icons.star_rounded, color: _amber, size: 18),
                    const SizedBox(width: 3),
                    Text('${avgRating.toStringAsFixed(1)} ($totalRatings reviews)',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: _greenDark)),
                    const SizedBox(width: 10),
                  ],
                  if (shopArea.isNotEmpty) ...[
                    const Icon(Icons.location_on_rounded, color: _sage, size: 15),
                    const SizedBox(width: 2),
                    Text(shopArea, style: const TextStyle(fontSize: 13, color: _sage)),
                  ],
                ]),
                if (shopAddress.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(shopAddress, style: const TextStyle(fontSize: 12, color: Color(0xFF999999))),
                ],
                if (fssaiNumber.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFFEAF7EE),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF1A8A3E).withValues(alpha: 0.3))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.verified_rounded, size: 13, color: Color(0xFF1A8A3E)),
                      const SizedBox(width: 4),
                      const Text('FSSAI Verified', style: TextStyle(
                        color: Color(0xFF1A8A3E), fontSize: 11.5, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ],
                if (vendorStory.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(vendorStory, style: const TextStyle(
                    color: _sage, fontSize: 13, height: 1.4, fontStyle: FontStyle.italic)),
                ],
              ]),
            )),
            SliverToBoxAdapter(child: _CustomerPollCard(merchantId: widget.merchantId)),
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text('Available bags', style: const TextStyle(
                fontWeight: FontWeight.w800, fontSize: 16, color: _greenDark)),
            )),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('bags')
                  .where('merchantId', isEqualTo: widget.merchantId)
                  .where('isActive', isEqualTo: true)
                  .snapshots(),
              builder: (context, bagsSnap) {
                if (!bagsSnap.hasData) {
                  return const SliverToBoxAdapter(child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator(color: _green))));
                }
                final bagDocs = bagsSnap.data!.docs;
                if (bagDocs.isEmpty) {
                  return const SliverToBoxAdapter(child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('No bags available right now.',
                      style: TextStyle(color: _sage)))));
                }
                return SliverList(delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final doc = bagDocs[i];
                    final bag = BagsRecord.fromSnapshot(doc);
                    return _VendorBagRow(bag: bag);
                  },
                  childCount: bagDocs.length,
                ));
              },
            ),
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Text('Reviews', style: const TextStyle(
                fontWeight: FontWeight.w800, fontSize: 16, color: _greenDark)),
            )),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('vendorRatings')
                  .where('merchantId', isEqualTo: widget.merchantId)
                  .orderBy('createdAt', descending: true)
                  .limit(10)
                  .snapshots(),
              builder: (context, reviewSnap) {
                if (!reviewSnap.hasData || reviewSnap.data!.docs.isEmpty) {
                  return const SliverToBoxAdapter(child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: Text('No reviews yet.', style: TextStyle(color: _sage, fontSize: 13))));
                }
                return SliverList(delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final r = reviewSnap.data!.docs[i].data() as Map<String, dynamic>;
                    final stars = (r['stars'] as num?)?.toInt() ?? 0;
                    final comment = r['comment'] as String? ?? '';
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE8E8E8))),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: List.generate(5, (s) => Icon(
                            s < stars ? Icons.star_rounded : Icons.star_border_rounded,
                            size: 14, color: _amber))),
                          if (comment.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(comment, style: const TextStyle(fontSize: 12.5, color: _greenDark)),
                          ],
                        ]),
                      ),
                    );
                  },
                  childCount: reviewSnap.data!.docs.length,
                ));
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ]);
        },
      ),
    );
  }
}

class _VendorBagRow extends StatelessWidget {
  final BagsRecord bag;
  const _VendorBagRow({required this.bag});

  @override
  Widget build(BuildContext context) {
    final qty = bag.availableQuantity;
    final soldOut = qty <= 0;
    return GestureDetector(
      onTap: soldOut ? null : () => context.pushNamed(
        BagDetailWidget.routeName,
        queryParameters: {'bagId': bag.reference.id},
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: soldOut ? const Color(0xFFF4F4F4) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE8E8E8))),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(bag.title, style: TextStyle(
              fontWeight: FontWeight.w700, fontSize: 14,
              color: soldOut ? const Color(0xFF999999) : const Color(0xFF0D1F12))),
            const SizedBox(height: 3),
            Text('${bag.pickupStart} – ${bag.pickupEnd}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF4D6B57))),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('₹${bag.price.toStringAsFixed(0)}', style: TextStyle(
              fontWeight: FontWeight.w800, fontSize: 15,
              color: soldOut ? const Color(0xFF999999) : const Color(0xFF1A4731))),
            const SizedBox(height: 2),
            Text(soldOut ? 'Sold out' : '$qty left', style: TextStyle(
              fontSize: 11.5, fontWeight: FontWeight.w600,
              color: soldOut ? Colors.red.shade400 : const Color(0xFF4D6B57))),
          ]),
        ]),
      ),
    );
  }
}

class _CustomerPollCard extends StatelessWidget {
  final String merchantId;
  const _CustomerPollCard({required this.merchantId});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('menuPolls')
          .where('merchantId', isEqualTo: merchantId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) return const SizedBox.shrink();
        final doc = snap.data!.docs.first;
        final data = doc.data() as Map<String, dynamic>;
        final options = (data['options'] as List?)?.cast<String>() ?? [];
        final votes = (data['votes'] as Map?)?.cast<String, dynamic>() ?? {};
        final myVote = uid != null ? votes[uid] as int? : null;
        final counts = List<int>.filled(options.length, 0);
        votes.forEach((_, v) { final i = (v as num).toInt(); if (i < counts.length) counts[i]++; });
        final totalVotes = counts.fold(0, (a, b) => a + b);

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFBF3E4), borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFF5A623).withValues(alpha: 0.35))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('🗳️ ${data['question'] ?? "What should we make next?"}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: const Color(0xFF0D1F12))),
            const SizedBox(height: 8),
            ...List.generate(options.length, (i) {
              final hasVoted = myVote != null;
              final isMine = myVote == i;
              final pct = totalVotes > 0 ? (counts[i] / totalVotes * 100).round() : 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: GestureDetector(
                  onTap: hasVoted ? null : () {
                    if (uid == null) return;
                    doc.reference.update({'votes.$uid': i});
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isMine ? const Color(0xFFEAF7EE) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isMine ? const Color(0xFF1A8A3E) : const Color(0xFFE8E8E8))),
                    child: Row(children: [
                      Expanded(child: Text(options[i], style: const TextStyle(fontSize: 13, color: const Color(0xFF0D1F12)))),
                      if (hasVoted) Text('$pct%', style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF4D6B57))),
                      if (isMine) const Padding(padding: EdgeInsets.only(left: 6),
                        child: Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF1A8A3E))),
                    ]),
                  ),
                ),
              );
            }),
            if (myVote == null)
              const Text('Tap to vote - one vote per person', style: TextStyle(fontSize: 11, color: const Color(0xFF4D6B57))),
          ]),
        );
      },
    );
  }
}
