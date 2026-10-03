import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import '/flutter_flow/flutter_flow_util.dart';
import 'activity_feed_model.dart';
export 'activity_feed_model.dart';

const _kGreen = Color(0xFF1A4731);
const _kAmber = Color(0xFFF5A623);
const _kBgLight = Color(0xFFF4F7F4);
const _kBorder = Color(0xFFD4E8D4);
const _kTextDark = Color(0xFF0D1F12);
const _kTextSecondary = Color(0xFF4D6B57);
const _kMintBg = Color(0xFFE6F4ED);

/// A live, auto-generated feed of real rescues — built entirely from
/// existing order data. Deliberately has NO user-generated content (no
/// photos, no text posts) so there is nothing to moderate: every card is
/// generated from a real confirmed order, fully anonymous (no customer
/// name/identity shown), pulled with a single-field query so it needs no
/// extra Firestore index setup.
class ActivityFeedWidget extends StatefulWidget {
  const ActivityFeedWidget({super.key});
  static String routeName = 'ActivityFeed';
  static String routePath = '/activityFeed';
  @override
  State<ActivityFeedWidget> createState() => _ActivityFeedWidgetState();
}

class _ActivityFeedWidgetState extends State<ActivityFeedWidget> {
  late ActivityFeedModel _model;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ActivityFeedModel());
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
        title: Text('Rescue Feed 🌱',
            style: GoogleFonts.plusJakartaSans(
                color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Text('🏆', style: TextStyle(fontSize: 18)),
            tooltip: 'City Leaderboard',
            onPressed: () => context.pushNamed('CityLeaderboard'),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Single-field ordering — no composite index required.
        stream: FirebaseFirestore.instance
            .collection('orders')
            .orderBy('timestamp', descending: true)
            .limit(60)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(_kGreen)));
          }
          final docs = snapshot.data!.docs.where((d) {
            final status = (d.data() as Map<String, dynamic>)['status'] as String? ?? '';
            return status == 'confirmed' || status == 'completed';
          }).take(30).toList();

          if (docs.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.eco_outlined, size: 56, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text('No rescues yet — be the first!',
                    style: GoogleFonts.plusJakartaSans(color: _kTextSecondary)),
              ]),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, i) => _RescueCard(data: docs[i].data() as Map<String, dynamic>),
          );
        },
      ),
    );
  }
}

class _RescueCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _RescueCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final merchantName = data['merchantName'] as String? ?? 'a local vendor';
    final shopArea = data['shopArea'] as String? ?? '';
    final quantity = (data['quantity'] as num?)?.toInt() ?? 1;
    final ts = data['timestamp'] as int? ?? 0;
    final when = ts > 0
        ? timeago.format(DateTime.fromMillisecondsSinceEpoch(ts * 1000), allowFromNow: true)
        : '';

    final areaText = shopArea.isNotEmpty ? ' in $shopArea' : '';
    final bagsWord = quantity > 1 ? '$quantity bags' : 'a bag';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorder)),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: const BoxDecoration(color: _kMintBg, shape: BoxShape.circle),
          child: const Center(child: Text('🎉', style: TextStyle(fontSize: 18))),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text.rich(
              TextSpan(
                style: GoogleFonts.plusJakartaSans(fontSize: 13, color: _kTextDark, height: 1.4),
                children: [
                  const TextSpan(text: 'Someone'),
                  TextSpan(text: areaText, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const TextSpan(text: ' just rescued '),
                  TextSpan(text: bagsWord, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const TextSpan(text: ' from '),
                  TextSpan(text: merchantName, style: const TextStyle(fontWeight: FontWeight.w700, color: _kGreen)),
                ],
              ),
            ),
            if (when.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(when, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: _kTextSecondary)),
            ],
          ]),
        ),
      ]),
    );
  }
}
