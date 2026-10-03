import '/components/community_forms.dart';
import '/services/community_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/flutter_flow/flutter_flow_util.dart';

// "Bring My Restaurant" - a customer requests a restaurant not yet on
// Surpl, others can co-sign to show demand, and once that vendor joins
// and completes real orders, everyone who co-signed gets rewarded.
// This deliberately holds no money and makes no promise to the
// customer - it's a lead-generation tool, same spirit as vendorLeads,
// just customer-initiated instead of vendor-initiated.
class RestaurantRequestsWidget extends StatefulWidget {
  const RestaurantRequestsWidget({Key? key}) : super(key: key);
  static String get routeName => 'RestaurantRequests';
  static String get routePath => '/restaurantRequests';

  @override
  State<RestaurantRequestsWidget> createState() => _RestaurantRequestsWidgetState();
}

class _RestaurantRequestsWidgetState extends State<RestaurantRequestsWidget> {
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
        title: const Text('Bring Your Restaurant', style: TextStyle(
          color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _amber,
        foregroundColor: _greenDark,
        icon: const Icon(Icons.add),
        label: const Text('Request one'),
        onPressed: () => _showRequestSheet(context, uid),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Want a specific restaurant on Surpl? Ask for it - and if enough people want the same thing, we\'ll go ask them.',
            style: TextStyle(fontSize: 13, color: _sage)),
        ),
        Expanded(child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('restaurantRequests')
              .orderBy('createdAt', descending: true)
              .limit(50)
              .snapshots(),
          builder: (context, snap) {
            // FIX: this never checked for errors, so any failure left
            // the screen stuck on the loading spinner forever with no
            // way out - the exact "stuck loading" bug reported.
            if (snap.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('Could not load requests right now.',
                      style: TextStyle(color: _sage, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text('Your requests are saved. Please retry.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _sage, fontSize: 11)),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => setState(() {}),
                      child: const Text('Try again'),
                    ),
                  ]),
                ),
              );
            }
            if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: _green));
            final docs = snap.data!.docs.where((d) => (d.data() as Map)['referredByVendor'] != true).toList();
            if (docs.isEmpty) {
              return Center(child: Text('No requests yet - be the first!', style: TextStyle(color: _sage)));
            }
            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: docs.length,
              itemBuilder: (context, i) => _RequestRow(doc: docs[i], currentUid: uid),
            );
          },
        )),
      ]),
    );
  }

  void _showRequestSheet(BuildContext context, String? uid) {
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in first.')));
      return;
    }
    showRestaurantRequestForm(context);
  }

}

class _RequestRow extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final String? currentUid;
  const _RequestRow({required this.doc, required this.currentUid});

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final name = data['restaurantName'] as String? ?? '';
    final area = data['area'] as String? ?? '';
    final supporters = (data['supporterUids'] as List?)?.cast<String>() ?? [];
    final status = data['status'] as String? ?? 'open';
    final alreadySupported = currentUid != null && (supporters.contains(currentUid) || data['requesterUid'] == currentUid);
    final isFulfilled = status == 'fulfilled';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8E8E8))),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: Color(0xFF0D1F12))),
          if (area.isNotEmpty) Text(area, style: const TextStyle(fontSize: 12, color: Color(0xFF4D6B57))),
          const SizedBox(height: 4),
          Text(isFulfilled ? '🎉 Now on Surpl!' : '${{...supporters, if (data['requesterUid'] is String) data['requesterUid'] as String}.length} people want this',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
              color: isFulfilled ? const Color(0xFF1A8A3E) : const Color(0xFF4D6B57))),
        ])),
        if (status == 'open')
          OutlinedButton(
            onPressed: (alreadySupported || currentUid == null) ? null : () async {
              try { await CommunityService.call('supportRestaurant', {'requestId': doc.id}); }
              catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(CommunityService.error(e)))); }
            },
            child: Text(alreadySupported ? 'Requested ✓' : 'Me too'),
          ),
      ]),
    );
  }
}
