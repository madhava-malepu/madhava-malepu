import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '/services/time_helpers.dart';
import 'expiring_soon_model.dart';
export 'expiring_soon_model.dart';

const _kGreen = Color(0xFF1A4731);
const _kAmber = Color(0xFFF5A623);
const _kRed = Color(0xFFE53935);
const _kBgLight = Color(0xFFF4F7F4);
const _kBorder = Color(0xFFD4E8D4);
const _kTextDark = Color(0xFF0D1F12);
const _kTextSecondary = Color(0xFF4D6B57);
const _kMintBg = Color(0xFFE6F4ED);

class ExpiringSoonWidget extends StatefulWidget {
  const ExpiringSoonWidget({super.key});
  static String routeName = 'ExpiringSoon';
  static String routePath = '/expiringSoon';
  @override
  State<ExpiringSoonWidget> createState() => _ExpiringSoonWidgetState();
}

class _ExpiringSoonWidgetState extends State<ExpiringSoonWidget> {
  late ExpiringSoonModel _model;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ExpiringSoonModel());
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBgLight,
      appBar: AppBar(
        backgroundColor: _kGreen,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Text('Expiring Soon ⏰',
            style: GoogleFonts.plusJakartaSans(
                color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Single-field ordering (pickupEndMillis) — no composite index
        // required; availableQuantity/isActive are filtered client-side.
        stream: FirebaseFirestore.instance
            .collection('bags')
            .orderBy('pickupEndMillis')
            .limit(100)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(_kGreen)));
          }
          final now = DateTime.now().millisecondsSinceEpoch;
          final docs = snapshot.data!.docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            final avail = (data['availableQuantity'] as num?)?.toInt() ?? 0;
            final isActive = data['isActive'] as bool? ?? true;
            final endMillis = (data['pickupEndMillis'] as num?)?.toInt() ?? 0;
            return avail > 0 && isActive && endMillis > now;
          }).toList();

          if (docs.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.check_circle_outline, size: 56, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text('Nothing expiring right now',
                    style: GoogleFonts.plusJakartaSans(color: _kTextSecondary)),
              ]),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              final bagId = docs[i].id;
              final endMillis = (data['pickupEndMillis'] as num?)?.toInt() ?? 0;
              final minutesLeft = TimeHelpers.minutesUntil(endMillis);
              final title = data['title'] as String? ?? 'Surprise Bag';
              final merchantName = data['merchantName'] as String? ?? 'Local Vendor';
              final shopArea = data['shopArea'] as String? ?? '';
              final price = (data['price'] as num?)?.toDouble() ?? 0;
              final image = data['image'] as String? ?? '';
              final urgent = minutesLeft < 30;

              return GestureDetector(
                onTap: () => context.pushNamed(BagDetailWidget.routeName,
                    queryParameters: {'bagId': bagId}),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: urgent ? _kRed.withValues(alpha: 0.4) : _kBorder)),
                  child: Row(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: image.isNotEmpty
                          ? CachedNetworkImage(imageUrl: image, width: 56, height: 56, fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Container(
                                  width: 56, height: 56, color: _kMintBg,
                                  child: const Icon(Icons.shopping_bag, color: _kGreen)))
                          : Container(width: 56, height: 56, color: _kMintBg,
                              child: const Icon(Icons.shopping_bag, color: _kGreen)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 14, fontWeight: FontWeight.w700, color: _kTextDark)),
                        Text(shopArea.isNotEmpty ? '$merchantName · $shopArea' : merchantName,
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(fontSize: 11, color: _kTextSecondary)),
                        const SizedBox(height: 4),
                        Text('₹${price.toStringAsFixed(0)}',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 13, fontWeight: FontWeight.w700, color: _kGreen)),
                      ]),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: urgent ? _kRed.withValues(alpha: 0.1) : const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(8)),
                      child: Text(TimeHelpers.expiryLabel(minutesLeft),
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 11, fontWeight: FontWeight.w700,
                              color: urgent ? _kRed : const Color(0xFFE65100))),
                    ),
                  ]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
