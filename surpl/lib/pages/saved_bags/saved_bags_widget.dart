import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'saved_bags_model.dart';
export 'saved_bags_model.dart';

const _kGreen = Color(0xFF1A4731);
const _kAmber = Color(0xFFF5A623);
const _kBorder = Color(0xFFD4E8D4);
const _kTextDark = Color(0xFF0D1F12);
const _kTextSecondary = Color(0xFF4D6B57);
const _kMintBg = Color(0xFFE6F4ED);
const _kBgLight = Color(0xFFF4F7F4);

class SavedBagsWidget extends StatefulWidget {
  const SavedBagsWidget({super.key});
  static String routeName = 'SavedBags';
  static String routePath = '/savedBags';
  @override
  State<SavedBagsWidget> createState() => _SavedBagsWidgetState();
}

class _SavedBagsWidgetState extends State<SavedBagsWidget> {
  late SavedBagsModel _model;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => SavedBagsModel());
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  Future<void> _unsave(String bagId) async {
    final uid = _uid;
    if (uid == null) return;
    // set+merge works even if savedBags field doesn't exist yet
    await FirebaseFirestore.instance.collection('users').doc(uid).set(
      {'savedBags': FieldValue.arrayRemove([bagId])},
      SetOptions(merge: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;

    return Scaffold(
      backgroundColor: _kBgLight,
      body: Column(
        children: [
          // ── Header ──
          Container(
            color: _kGreen,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16, right: 16, bottom: 16),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => context.goNamed(HomeFeedWidget.routeName),
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white, size: 20))),
                const SizedBox(width: 12),
                const Expanded(child: Text('Saved Bags',
                  style: TextStyle(
                    color: Colors.white, fontSize: 20,
                    fontWeight: FontWeight.w800))),
                const Icon(Icons.favorite_rounded, color: _kAmber, size: 22),
              ],
            ),
          ),

          // ── Body ──
          Expanded(
            child: uid == null
              ? _emptyState('Sign in to see your saved bags', showBrowse: false)
              : StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users').doc(uid).snapshots(),
                  builder: (context, userSnap) {
                    if (!userSnap.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(color: _kGreen));
                    }
                    final data =
                        userSnap.data!.data() as Map<String, dynamic>?;
                    final rawSavedIds =
                        List<String>.from(data?['savedBags'] ?? []);
                    // FIX: Firestore's whereIn caps at 30 items - this had
                    // no limit at all, so any customer with more than 30
                    // saved bags would hit a genuinely failing query with
                    // no error handling, most likely showing as a
                    // permanently stuck spinner (the same symptom already
                    // found and fixed once in the admin dashboard this
                    // session). Takes the most recently saved 30, since
                    // savedBags is appended to over time.
                    final savedIds = rawSavedIds.length > 30
                        ? rawSavedIds.sublist(rawSavedIds.length - 30)
                        : rawSavedIds;

                    if (savedIds.isEmpty) {
                      return _emptyState(
                        'No saved bags yet\nTap ♥ on any bag to save it',
                        showBrowse: true);
                    }

                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('bags')
                          .where(FieldPath.documentId, whereIn: savedIds)
                          .snapshots(),
                      builder: (context, bagSnap) {
                        if (!bagSnap.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(color: _kGreen));
                        }
                        final nowMillis = DateTime.now().millisecondsSinceEpoch;
                        final bags = bagSnap.data!.docs.where((doc) {
                          final d = doc.data() as Map<String, dynamic>;
                          final isActive = d['isActive'] as bool? ?? true;
                          final availableQty = (d['availableQuantity'] as num?)?.toInt() ?? 0;
                          final endMillis = (d['pickupEndMillis'] as num?)?.toInt() ?? 0;
                          var notExpired = endMillis == 0 || nowMillis <= endMillis;
                          if (endMillis == 0) {
                            final createdAt = d['createdAt'];
                            if (createdAt is Timestamp) {
                              final ageMillis = nowMillis - createdAt.millisecondsSinceEpoch;
                              if (ageMillis > 48 * 60 * 60 * 1000) notExpired = false;
                            }
                          }
                          return isActive && availableQty > 0 && notExpired;
                        }).toList();
                        if (bags.isEmpty) {
                          return _emptyState(
                            'Saved bags not found', showBrowse: true);
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: bags.length,
                          itemBuilder: (context, i) {
                            return _BagCard(
                              doc: bags[i],
                              onUnsave: () => _unsave(bags[i].id),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(String msg, {required bool showBrowse}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88, height: 88,
              decoration: BoxDecoration(
                color: _kMintBg,
                shape: BoxShape.circle,
                border: Border.all(color: _kBorder, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: _kGreen.withValues(alpha: 0.08),
                    blurRadius: 16, offset: const Offset(0, 4)),
                ]),
              child: const Icon(Icons.favorite_outline_rounded,
                size: 40, color: _kGreen)),
            const SizedBox(height: 20),
            Text(msg,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15, color: _kTextSecondary, height: 1.6,
                letterSpacing: -0.2)),
            if (showBrowse) ...[
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => context.goNamed(HomeFeedWidget.routeName),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 14),
                  decoration: BoxDecoration(
                    color: _kGreen,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: _kGreen.withValues(alpha: 0.3),
                        blurRadius: 10, offset: const Offset(0, 4)),
                    ]),
                  child: const Text('Browse Bags',
                    style: TextStyle(
                      color: Color(0xFFFBF3E4),
                      fontWeight: FontWeight.w700,
                      fontSize: 14)))),
            ],
          ],
        ),
      ),
    );
  }
}

class _BagCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final VoidCallback onUnsave;
  const _BagCard({required this.doc, required this.onUnsave});

  @override
  Widget build(BuildContext context) {
    final d = doc.data() as Map<String, dynamic>;
    final bagId = doc.id;
    final title = d['title'] as String? ?? 'Surprise Bag';
    final image = d['image'] as String? ?? '';
    final price = (d['price'] as num?)?.toDouble() ?? 0;
    final originalPrice = (d['originalPrice'] as num?)?.toDouble() ?? 0;
    final pickupStart = d['pickupStart'] as String? ?? '';
    final pickupEnd = d['pickupEnd'] as String? ?? '';
    final category = d['category'] as String? ?? '';
    final availableQty = (d['availableQuantity'] as num?)?.toInt() ?? 0;
    final savings = originalPrice > 0
        ? ((originalPrice - price) / originalPrice * 100).round()
        : 0;
    final isSoldOut = availableQty <= 0;

    return GestureDetector(
      onTap: isSoldOut
          ? null
          : () => context.pushNamed(BagDetailWidget.routeName,
              queryParameters: {'bagId': bagId}),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16, offset: const Offset(0, 5)),
            BoxShadow(
              color: _kGreen.withValues(alpha: 0.05),
              blurRadius: 8, offset: const Offset(0, 2)),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4, offset: const Offset(0, 1)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  child: image.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: image,
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _placeholder())
                      : _placeholder()),

                // Savings badge
                if (savings > 0)
                  Positioned(
                    top: 10, left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _kAmber,
                        borderRadius: BorderRadius.circular(20)),
                      child: Text('Save $savings%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 11)))),

                // Sold out overlay
                if (isSoldOut)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16)),
                      child: Container(
                        color: Colors.black54,
                        alignment: Alignment.center,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(8)),
                          child: const Text('SOLD OUT',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              letterSpacing: 2)))))),

                // Unsave (heart) button
                Positioned(
                  top: 8, right: 8,
                  child: GestureDetector(
                    onTap: onUnsave,
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 8),
                        ]),
                      child: const Icon(Icons.favorite_rounded,
                        color: _kAmber, size: 18)))),
              ],
            ),

            // Details
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _kTextDark),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis)),
                      if (category.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _kMintBg,
                            borderRadius: BorderRadius.circular(20)),
                          child: Text(category,
                            style: const TextStyle(
                              color: _kGreen,
                              fontSize: 10,
                              fontWeight: FontWeight.w600))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (pickupStart.isNotEmpty)
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded,
                          color: Colors.grey.shade400, size: 13),
                        const SizedBox(width: 4),
                        Text('Pickup: $pickupStart – $pickupEnd',
                          style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 12)),
                      ],
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text('₹${price.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: _kGreen)),
                      const SizedBox(width: 8),
                      if (originalPrice > price)
                        Text('₹${originalPrice.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade400,
                            decoration: TextDecoration.lineThrough)),
                      const Spacer(),
                      if (!isSoldOut)
                        GestureDetector(
                          onTap: () => context.pushNamed(
                            BagDetailWidget.routeName,
                            queryParameters: {'bagId': bagId}),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 10),
                            decoration: BoxDecoration(
                              color: _kGreen,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: _kGreen.withValues(alpha: 0.3),
                                  blurRadius: 8, offset: const Offset(0, 3)),
                              ]),
                            child: const Text('Book Now',
                              style: TextStyle(
                                color: Color(0xFFFBF3E4),
                                fontWeight: FontWeight.w700,
                                fontSize: 13))))
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 9),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(10)),
                          child: Text('Sold Out',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w600,
                              fontSize: 13))),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
    height: 160, color: _kMintBg,
    child: const Center(
      child: Icon(Icons.shopping_bag_outlined,
        color: _kGreen, size: 52)));
}