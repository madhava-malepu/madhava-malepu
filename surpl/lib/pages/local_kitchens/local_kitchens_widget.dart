import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'local_kitchens_model.dart';
export 'local_kitchens_model.dart';

const _kGreen = Color(0xFF1A4731);
const _kAmber = Color(0xFFF5A623);
const _kBgLight = Color(0xFFF4F7F4);
const _kBorder = Color(0xFFD4E8D4);
const _kTextDark = Color(0xFF0D1F12);
const _kTextSecondary = Color(0xFF4D6B57);
const _kMintBg = Color(0xFFE6F4ED);

/// A deliberately SEPARATE section from Surprise Bags — different
/// branding, different framing (full price, made fresh to order).
/// Narrow scope on purpose: small snack stalls only (chaat, samosa,
/// bajji, similar) — NOT restaurants, tiffin centres, or dhabas. Only
/// vendors manually approved by Surpl (isFreshFoodApproved on their user
/// doc) can list here. Every listing here is genuine skip-the-queue (full
/// price, 0% commission) — the previously-available discounted "Special
/// Offer" option was moved out to its own top-level "Happy Hour" listing
/// type, available to every vendor without needing this approval.
class LocalKitchensWidget extends StatefulWidget {
  const LocalKitchensWidget({super.key});
  static String routeName = 'LocalKitchens';
  static String routePath = '/localKitchens';
  @override
  State<LocalKitchensWidget> createState() => _LocalKitchensWidgetState();
}

class _LocalKitchensWidgetState extends State<LocalKitchensWidget> {
  late LocalKitchensModel _model;
  String _selectedSnackType = 'All';

  static const _snackTypeMeta = {
    'chaat': '🍛 Chaat',
    'samosa': '🥟 Samosa/Kachori',
    'bajji': '🍤 Bajji',
    'other_snack': '🥘 Other',
  };

  // Created once, never recreated on rebuild — same "blinking" fix as
  // Home Feed. Tapping a snack-type filter chip calls setState(), and an
  // inline stream here would be recreated every time, flashing the
  // loading state on every tap.
  late final Stream<QuerySnapshot> _snacksStream;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => LocalKitchensModel());
    _snacksStream = FirebaseFirestore.instance
        .collection('bags')
        .where('listingType', isEqualTo: 'freshFood')
        .snapshots();
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
        title: Text('Street Snacks 🥟',
            style: GoogleFonts.plusJakartaSans(
                color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
      ),
      body: Column(children: [
        Container(
          color: _kGreen,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text('Chaat, samosa, bajji & more — fresh, full price, made to order',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, color: Colors.white.withValues(alpha: 0.85))),
        ),
        Container(
          color: _kGreen,
          padding: const EdgeInsets.only(bottom: 12),
          child: SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _typeChip('All', 'All'),
                ..._snackTypeMeta.entries.map((e) => _typeChip(e.key, e.value)),
              ],
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _snacksStream,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(_kGreen)));
              }
              final nowMillis = DateTime.now().millisecondsSinceEpoch;
              final docs = snapshot.data!.docs.where((d) {
                final data = d.data() as Map<String, dynamic>;
                final isActive = data['isActive'] as bool? ?? true;
                final avail = (data['availableQuantity'] as num?)?.toInt() ?? 0;
                final snackType = data['snackType'] as String? ?? 'other_snack';
                final matchesFilter = _selectedSnackType == 'All' || snackType == _selectedSnackType;
                // Same expiry check added to Home Feed — was missing here,
                // meaning expired Street Snacks listings kept showing.
                final endMillis = (data['pickupEndMillis'] as num?)?.toInt() ?? 0;
                var notExpired = endMillis == 0 || nowMillis <= endMillis;
                // Fallback for bags predating pickupEndMillis being set —
                // treat anything older than 48 hours as stale regardless.
                if (endMillis == 0) {
                  final createdAt = data['createdAt'];
                  if (createdAt is Timestamp) {
                    final ageMillis = nowMillis - createdAt.millisecondsSinceEpoch;
                    if (ageMillis > 48 * 60 * 60 * 1000) notExpired = false;
                  }
                }
                return isActive && avail > 0 && matchesFilter && notExpired;
              }).toList();

              if (docs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text('🥟', style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 12),
                      Text('No snack stalls live right now',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 15, fontWeight: FontWeight.w700, color: _kTextDark)),
                      const SizedBox(height: 6),
                      Text('Check back soon for fresh chaat, samosa & more',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(fontSize: 12, color: _kTextSecondary)),
                    ]),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                itemCount: docs.length,
                itemBuilder: (context, i) => _SnackCard(doc: docs[i]),
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _typeChip(String value, String label) {
    final sel = _selectedSnackType == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _selectedSnackType = value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: sel ? _kAmber : Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20)),
          child: Text(label, style: GoogleFonts.plusJakartaSans(
              fontSize: 12, fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
              color: sel ? _kGreen : Colors.white)),
        ),
      ),
    );
  }
}

class _SnackCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  const _SnackCard({required this.doc});

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final title = data['title'] as String? ?? 'Street Snack';
    final merchantName = data['merchantName'] as String? ?? 'Local Stall';
    final shopArea = data['shopArea'] as String? ?? '';
    final price = (data['price'] as num?)?.toDouble() ?? 0;
    final pickupStart = data['pickupStart'] as String? ?? '';
    final pickupEnd = data['pickupEnd'] as String? ?? '';
    final availableQty = (data['availableQuantity'] as num?)?.toInt() ?? 0;
    final image = data['image'] as String? ?? '';

    return GestureDetector(
      onTap: () => context.pushNamed(BagDetailWidget.routeName,
          queryParameters: {'bagId': doc.id}),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kBorder)),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: image.isNotEmpty
                ? CachedNetworkImage(imageUrl: image, width: 60, height: 60, fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(width: 60, height: 60, color: _kMintBg,
                        child: const Icon(Icons.restaurant_rounded, color: _kGreen)))
                : Container(width: 60, height: 60, color: _kMintBg,
                    child: const Icon(Icons.restaurant_rounded, color: _kGreen)),
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
              Row(children: [
                Icon(Icons.access_time_rounded, size: 11, color: Colors.grey.shade400),
                const SizedBox(width: 3),
                Text('$pickupStart – $pickupEnd',
                    style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: _kTextSecondary)),
              ]),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('₹${price.toStringAsFixed(0)}',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 15, fontWeight: FontWeight.w800, color: _kGreen)),
            Text('$availableQty left',
                style: GoogleFonts.plusJakartaSans(fontSize: 10, color: _kTextSecondary)),
          ]),
        ]),
      ),
    );
  }
}
