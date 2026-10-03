import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';

const _green = Color(0xFF1A4731);
const _amber = Color(0xFFF5A623);
const _red = Color(0xFFE53935);
const _bg = Color(0xFFF5F8F5);

class HotDealsWidget extends StatefulWidget {
  const HotDealsWidget({super.key});
  static String routeName = 'HotDeals';
  static String routePath = '/hotDeals';
  @override
  State<HotDealsWidget> createState() => _HotDealsWidgetState();
}

class _HotDealsWidgetState extends State<HotDealsWidget> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Column(children: [
        // Header
        Container(
          color: _red,
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16, right: 16, bottom: 16),
          child: Row(children: [
            GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.arrow_back_rounded,
                  color: Colors.white, size: 18))),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Text('🔥 Hot Deals',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20, fontWeight: FontWeight.w800,
                  color: Colors.white)),
              Text('Limited time — grab them fast!',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.8))),
            ])),
          ])),

        // Hot deals list
        Expanded(child: StreamBuilder<QuerySnapshot>(
          // No .orderBy() here - 3 .where() clauses plus 2 .orderBy()
          // clauses on different fields would require a Firestore
          // composite index (a query this complex essentially always
          // needs one). Sorting client-side instead, alongside the
          // expired-deal filtering that already happens below, avoids
          // depending on that index existing at all.
          stream: FirebaseFirestore.instance
              .collection('bags')
              .where('isHotDeal', isEqualTo: true)
              .where('isActive', isEqualTo: true)
              .where('availableQuantity', isGreaterThan: 0)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator(
                color: _red));
            }

            // Filter out expired deals
            final now = DateTime.now().millisecondsSinceEpoch;
            final docs = snapshot.data!.docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final endsAt = (data['hotDealEndsAt'] as int?) ?? 0;
              return endsAt > now;
            }).toList();

            // Sort client-side, matching the original intended order:
            // lowest stock first, then soonest-ending first.
            docs.sort((a, b) {
              final dataA = a.data() as Map<String, dynamic>;
              final dataB = b.data() as Map<String, dynamic>;
              final qtyA = (dataA['availableQuantity'] as num?) ?? 0;
              final qtyB = (dataB['availableQuantity'] as num?) ?? 0;
              final qtyCompare = qtyA.compareTo(qtyB);
              if (qtyCompare != 0) return qtyCompare;
              final endsAtA = (dataA['hotDealEndsAt'] as int?) ?? 0;
              final endsAtB = (dataB['hotDealEndsAt'] as int?) ?? 0;
              return endsAtA.compareTo(endsAtB);
            });

            if (docs.isEmpty) {
              return Center(child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 88, height: 88,
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.red.shade100, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: _red.withValues(alpha: 0.10),
                            blurRadius: 16, offset: const Offset(0, 4)),
                        ]),
                      child: const Icon(Icons.local_fire_department_rounded,
                        color: _red, size: 42)),
                    const SizedBox(height: 20),
                    Text('No hot deals right now',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 17, fontWeight: FontWeight.w800,
                        color: _green, letterSpacing: -0.3)),
                    const SizedBox(height: 8),
                    Text('Vendors post flash deals throughout the day.\nCheck back soon!',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13, color: Colors.grey.shade500, height: 1.5)),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6F4ED),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFD4E8D4))),
                      child: Text('Turn on notifications to never miss a Hot Deal',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12, color: _green,
                          fontWeight: FontWeight.w600))),
                  ])));
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              itemBuilder: (_, i) {
                final data = docs[i].data() as Map<String, dynamic>;
                return _HotDealCard(
                  docId: docs[i].id,
                  data: data,
                );
              });
          })),
      ]),
    );
  }
}

class _HotDealCard extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  const _HotDealCard({required this.docId, required this.data});
  @override
  State<_HotDealCard> createState() => _HotDealCardState();
}

class _HotDealCardState extends State<_HotDealCard> {
  late Timer _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateRemaining();
    });
  }

  void _updateRemaining() {
    final endsAt = (widget.data['hotDealEndsAt'] as int?) ?? 0;
    final diff = DateTime.fromMillisecondsSinceEpoch(endsAt)
        .difference(DateTime.now());
    if (mounted) setState(() => _remaining = diff.isNegative ? Duration.zero : diff);
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String get _timerText {
    if (_remaining == Duration.zero) return 'EXPIRED';
    final m = _remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = _remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${_remaining.inHours > 0 ? '${_remaining.inHours}:' : ''}$m:$s';
  }

  Color get _timerColor {
    if (_remaining.inMinutes < 3) return Colors.red;
    if (_remaining.inMinutes < 10) return Colors.orange;
    return _green;
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.data['title'] as String? ?? 'Hot Deal Bag';
    final price = (widget.data['price'] as num?)?.toDouble() ?? 0;
    final originalPrice = (widget.data['originalPrice'] as num?)?.toDouble() ?? 0;
    final qty = (widget.data['availableQuantity'] as num?)?.toInt() ?? 0;
    final image = widget.data['image'] as String? ?? '';
    final merchantName = (widget.data['merchantName'] as String?) ?? 'Local Vendor';
    final savings = originalPrice > price
        ? ((originalPrice - price) / originalPrice * 100).round() : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade100, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.10),
            blurRadius: 16, offset: const Offset(0, 6)),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8, offset: const Offset(0, 2)),
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.04),
            blurRadius: 4, offset: const Offset(0, 1)),
        ]),
      child: Column(children: [
        // Timer banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: const BoxDecoration(
            color: _red,
            borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
          child: Row(children: [
            const Text('🔥', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            const Text('HOT DEAL',
              style: TextStyle(color: Colors.white, fontSize: 11,
                fontWeight: FontWeight.w800, letterSpacing: 1)),
            const Spacer(),
            Text('Ends in: ',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8),
                fontSize: 11)),
            Text(_timerText,
              style: TextStyle(
                color: _timerColor == _green ? Colors.white : Colors.yellow,
                fontSize: 13, fontWeight: FontWeight.w800,
                letterSpacing: 1)),
          ])),

        // Content
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            // Image
            if (image.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(imageUrl: image,
                  width: 80, height: 80, fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5EE),
                      borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.fastfood_rounded,
                      color: _green, size: 32))))
            else
              Container(width: 80, height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5EE),
                  borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.fastfood_rounded,
                  color: _green, size: 32)),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Text(title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14, fontWeight: FontWeight.w700,
                  color: const Color(0xFF0D1F12))),
              const SizedBox(height: 2),
              Text(merchantName,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, color: _green,
                  fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Row(children: [
                Text('₹${price.toStringAsFixed(0)}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18, fontWeight: FontWeight.w900,
                    color: _red)),
                const SizedBox(width: 8),
                if (originalPrice > price)
                  Text('₹${originalPrice.toStringAsFixed(0)}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12, color: Colors.grey.shade400,
                      decoration: TextDecoration.lineThrough)),
                if (savings > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _red,
                      borderRadius: BorderRadius.circular(20)),
                    child: Text('$savings% OFF',
                      style: const TextStyle(
                        color: Colors.white, fontSize: 10,
                        fontWeight: FontWeight.w800, letterSpacing: 0.5))),
                ],
              ]),
              const SizedBox(height: 4),
              Text('$qty left — grab it fast!',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: qty <= 2 ? _red : Colors.grey.shade500,
                  fontWeight: qty <= 2 ? FontWeight.w700 : FontWeight.w400)),
            ])),
          ])),

        // Grab button
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: GestureDetector(
            onTap: _remaining == Duration.zero ? null : () {
              context.pushNamed(
                CheckoutWidget.routeName,
                queryParameters: {
                  'bagId': serializeParam(widget.docId, ParamType.String)
                }.withoutNulls,
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: _remaining == Duration.zero
                    ? Colors.grey : _red,
                borderRadius: BorderRadius.circular(14),
                boxShadow: _remaining == Duration.zero ? [] : [
                  BoxShadow(
                    color: _red.withValues(alpha: 0.35),
                    blurRadius: 10, offset: const Offset(0, 4)),
                ]),
              alignment: Alignment.center,
              child: Text(
                _remaining == Duration.zero
                    ? 'Deal expired' : '🔥 Grab this deal — ₹${(price + 5).toStringAsFixed(0)} total',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white, fontSize: 14,
                  fontWeight: FontWeight.w800))))),
      ]));
  }
}
