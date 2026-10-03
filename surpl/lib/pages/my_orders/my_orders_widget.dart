import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '/auth/firebase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '/services/order_expiry_service.dart';
import 'package:google_fonts/google_fonts.dart';

const _kGreen = Color(0xFF1A4731);
const _kAmber = Color(0xFFF5A623);
const _kBgLight = Color(0xFFF4F7F4);
const _kMintBg = Color(0xFFE6F4ED);
const _kBorder = Color(0xFFD4E8D4);
const _kTextDark = Color(0xFF0D1F12);
const _kTextSecondary = Color(0xFF4D6B57);

class MyOrdersWidget extends StatefulWidget {
  const MyOrdersWidget({super.key});
  static String get routeName => 'MyOrders';
  static String get routePath => '/myOrders';

  @override
  State<MyOrdersWidget> createState() => _MyOrdersWidgetState();
}

class _MyOrdersWidgetState extends State<MyOrdersWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    final uid = currentUserUid;
    if (uid.isNotEmpty) OrderExpiryService.expireForCustomer(uid);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = currentUserUid;
    return Scaffold(
      backgroundColor: _kBgLight,
      body: Column(children: [
        Container(
          color: _kGreen,
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 14,
            left: 16, right: 16, bottom: 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              GestureDetector(
                onTap: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.goNamed('HomeFeed');
                  }
                },
                child: Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.arrow_back_rounded,
                    color: Colors.white, size: 18))),
              const SizedBox(width: 12),
              Text('My Orders', style: GoogleFonts.plusJakartaSans(
                fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white,
                letterSpacing: -0.3)),
            ]),
            const SizedBox(height: 14),
            TabBar(
              controller: _tabCtrl,
              indicatorColor: _kAmber,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              labelStyle: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700, fontSize: 13),
              tabs: const [
                Tab(text: 'Active'),
                Tab(text: 'Past'),
                Tab(text: 'Refunds'),
              ]),
          ])),
        Expanded(child: TabBarView(controller: _tabCtrl, children: [
          _OrderList(uid: uid, filter: 'active'),
          _OrderList(uid: uid, filter: 'past'),
          _RefundList(uid: uid),
        ])),
      ]));
  }
}

class _OrderList extends StatelessWidget {
  final String uid;
  final String filter; // 'active' or 'past'
  const _OrderList({required this.uid, required this.filter});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('customerId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _kGreen));
        }
        final all = snap.data?.docs ?? [];
        // BUG FIX: 'preparing' and 'ready' (Skip the Queue's real prep
        // stages, set by the vendor app) were in neither list, so an
        // order in either state matched NEITHER 'active' nor 'past' and
        // silently vanished from both tabs the moment a vendor started
        // preparing it - reappearing only once marked completed.
        final activeStatuses = ['pending', 'confirmed', 'preparing', 'ready'];
        final pastStatuses = ['completed', 'cancelled', 'missed'];

        final filtered = all.where((doc) {
          final d = doc.data() as Map<String, dynamic>;
          final status = d['status'] as String? ?? '';
          // FIX: a "cancelled" order the customer never actually paid
          // for (a declined card, wrong PIN, timeout, or simply
          // abandoning checkout) was showing up identically to a real
          // order that got cancelled after genuinely being paid - the
          // two are completely different events, and lumping a failed
          // payment attempt in with real order history is confusing
          // clutter, not a real order. A cancellation only belongs in
          // history if it has a real paymentId - meaning a payment
          // truly succeeded and was later reversed - which the vendor
          // and customer both still need to know about.
          if (status == 'cancelled') {
            final hasRealPayment = ((d['paymentId'] as String?) ?? '').isNotEmpty
                || ((d['razorpayPaymentId'] as String?) ?? '').isNotEmpty;
            if (!hasRealPayment) return false;
          }
          if (filter == 'active') return activeStatuses.contains(status);
          return pastStatuses.contains(status);
        }).toList();

        filtered.sort((a, b) {
          final at = ((a.data() as Map)['timestamp'] as int?) ?? 0;
          final bt = ((b.data() as Map)['timestamp'] as int?) ?? 0;
          return bt.compareTo(at);
        });

        if (filtered.isEmpty) {
          return Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(width: 72, height: 72,
              decoration: const BoxDecoration(
                color: _kMintBg, shape: BoxShape.circle),
              child: const Icon(Icons.receipt_long_outlined,
                color: _kGreen, size: 36)),
            const SizedBox(height: 16),
            Text(filter == 'active' ? 'No active orders' : 'No past orders',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17, fontWeight: FontWeight.w700, color: _kTextDark)),
            const SizedBox(height: 8),
            Text(filter == 'active'
              ? 'Your current orders will appear here'
              : 'Completed orders will appear here',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13, color: _kTextSecondary)),
          ]));
        }

        // Group by orderGroupId - this was already being saved on every
        // order at checkout time but never used here, so a customer who
        // bought 2 bags in one checkout saw two disconnected-looking
        // order cards instead of one combined order.
        final Map<String, List<QueryDocumentSnapshot>> byGroup = {};
        for (final doc in filtered) {
          final d = doc.data() as Map<String, dynamic>;
          final groupId = (d['orderGroupId'] as String?) ?? doc.id;
          byGroup.putIfAbsent(groupId, () => []).add(doc);
        }
        final groupedList = byGroup.values.toList();
        groupedList.sort((a, b) {
          final at = ((a.first.data() as Map)['timestamp'] as int?) ?? 0;
          final bt = ((b.first.data() as Map)['timestamp'] as int?) ?? 0;
          return bt.compareTo(at);
        });

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
          itemCount: groupedList.length,
          itemBuilder: (_, i) {
            final group = groupedList[i];
            if (group.length == 1) return _OrderCard(doc: group.first);
            return _GroupedOrderCard(docs: group);
          });
      });
  }
}

class _GroupedOrderCard extends StatelessWidget {
  final List<QueryDocumentSnapshot> docs;
  const _GroupedOrderCard({required this.docs});

  @override
  Widget build(BuildContext context) {
    final first = docs.first.data() as Map<String, dynamic>;
    final groupId = (first['orderGroupId'] as String?) ?? docs.first.id;
    final totalPaid = docs.fold<double>(0, (sum, d) =>
      sum + ((d.data() as Map<String, dynamic>)['amountPaid'] as num? ?? 0).toDouble());
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F3EC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Order #${groupId.substring(0, 6).toUpperCase()}', style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800, fontSize: 13, color: _kTextDark)),
          const SizedBox(width: 8),
          Text('· ${docs.length} items · ₹${totalPaid.toStringAsFixed(0)} total', style: GoogleFonts.plusJakartaSans(
            fontSize: 12, color: _kTextSecondary)),
        ]),
        const SizedBox(height: 8),
        ...docs.map((d) => Padding(
          padding: const EdgeInsets.only(top: 4),
          child: _OrderCard(doc: d))),
      ]),
    );
  }
}

class _RefundList extends StatelessWidget {
  final String uid;
  const _RefundList({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('refundRequests')
          .where('customerId', isEqualTo: uid)
          .snapshots(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _kGreen));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(width: 72, height: 72,
              decoration: const BoxDecoration(color: _kMintBg, shape: BoxShape.circle),
              child: const Icon(Icons.receipt_outlined, color: _kGreen, size: 36)),
            const SizedBox(height: 16),
            Text('No refund requests', style: GoogleFonts.plusJakartaSans(
              fontSize: 17, fontWeight: FontWeight.w700, color: _kTextDark)),
            const SizedBox(height: 8),
            Text('Approved refunds go to your Surpl Wallet',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13, color: _kTextSecondary)),
          ]));
        }

        docs.sort((a, b) {
          final at = ((a.data() as Map)['submittedAt'] as int?) ?? 0;
          final bt = ((b.data() as Map)['submittedAt'] as int?) ?? 0;
          return bt.compareTo(at);
        });

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
          itemCount: docs.length,
          itemBuilder: (_, i) => _RefundCard(doc: docs[i]));
      });
  }
}

class _RefundCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  const _RefundCard({required this.doc});

  @override
  Widget build(BuildContext context) {
    final d = doc.data() as Map<String, dynamic>;
    final status = d['status'] as String? ?? 'pending';
    final reason = d['issueType'] as String? ?? '';
    final adminNote = d['adminNote'] as String? ?? '';
    final amount = (d['amountPaid'] as num?)?.toDouble() ?? 0;
    final ts = d['submittedAt'] as int? ?? 0;
    final dt = ts > 0 ? DateTime.fromMillisecondsSinceEpoch(ts) : null;
    final dateStr = dt != null ? '${dt.day}/${dt.month}/${dt.year}' : '—';

    Color statusColor;
    String statusLabel;
    switch (status) {
      case 'approved_wallet':
        statusColor = _kGreen; statusLabel = '✅ Refunded to Wallet'; break;
      case 'approved_bank':
        statusColor = _kGreen; statusLabel = '✅ Refunded to Bank'; break;
      case 'rejected':
        statusColor = Colors.red; statusLabel = '❌ Rejected'; break;
      default:
        statusColor = _kAmber; statusLabel = '⏳ Under Review';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('Refund Request',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14, fontWeight: FontWeight.w700, color: _kTextDark))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20)),
            child: Text(statusLabel, style: GoogleFonts.plusJakartaSans(
              fontSize: 11, fontWeight: FontWeight.w700, color: statusColor))),
        ]),
        const SizedBox(height: 8),
        Text(reason, style: GoogleFonts.plusJakartaSans(
          fontSize: 13, color: _kTextSecondary)),
        const SizedBox(height: 4),
        Row(children: [
          Text('Rs.${amount.toStringAsFixed(0)}',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15, fontWeight: FontWeight.w800, color: _kGreen)),
          const SizedBox(width: 12),
          Text(dateStr, style: GoogleFonts.plusJakartaSans(
            fontSize: 12, color: _kTextSecondary)),
        ]),
        if (adminNote.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: status == 'rejected'
                  ? Colors.red.shade50 : _kMintBg,
              borderRadius: BorderRadius.circular(8)),
            child: Text('Surpl: $adminNote',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12, color: status == 'rejected'
                  ? Colors.red.shade700 : _kGreen))),
        ],
      ]));
  }
}

class _OrderCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  const _OrderCard({required this.doc});

  Color _statusColor(String s) {
    switch (s) {
      case 'confirmed': return const Color(0xFF4CAF50);
      case 'preparing': return const Color(0xFFB45309);
      case 'ready': return const Color(0xFF0369A1);
      case 'completed': return const Color(0xFF4CAF50);
      case 'cancelled': return Colors.red;
      case 'missed': return Colors.orange;
      default: return Colors.grey;
    }
  }

  // 'confirmed' means two different real-world things depending on the
  // listing type: a pre-packed Surprise Bag / Happy Hour is physically
  // ready the instant it's confirmed, while a Skip the Queue order still
  // needs the vendor to prepare it - the label now says which is true.
  String _statusLabel(String s, {bool isFreshFood = false}) {
    switch (s) {
      case 'confirmed':
        return isFreshFood ? '📝 Order placed' : '✅ Ready for pickup!';
      case 'preparing': return '🍳 Being prepared';
      case 'ready': return '✅ Ready for pickup!';
      case 'completed': return '🎉 Completed';
      case 'cancelled': return '❌ Cancelled';
      case 'missed': return '⏰ Missed';
      default: return s;
    }
  }

  bool _canReport(Map<String, dynamic> d) {
    final status = d['status'] as String? ?? '';
    if (!['confirmed', 'preparing', 'ready', 'completed', 'missed'].contains(status)) return false;
    // Allow report within 2 hours of pickup end
    final pickupEndMillis = (d['pickupEndMillis'] as num?)?.toInt() ?? 0;
    if (pickupEndMillis == 0) return status == 'completed';
    final deadline = pickupEndMillis + (2 * 60 * 60 * 1000); // +2 hours
    return DateTime.now().millisecondsSinceEpoch < deadline;
  }

  bool _canRate(Map<String, dynamic> d) {
    final status = d['status'] as String? ?? '';
    final alreadyRated = d['ratedAt'] != null;
    return status == 'completed' && !alreadyRated;
  }

  @override
  Widget build(BuildContext context) {
    final d = doc.data() as Map<String, dynamic>;
    final status = d['status'] as String? ?? 'confirmed';
    final isFreshFood = d['listingType'] == 'freshFood';
    final amountPaid = (d['amountPaid'] as num?)?.toDouble() ?? 0;
    final platformFee = (d['platformFee'] as num?)?.toDouble() ?? 0;
    final completedAtTs = d['completedAt'] as Timestamp?;
    final completedAtStr = completedAtTs != null
        ? '${completedAtTs.toDate().day}/${completedAtTs.toDate().month} at ${completedAtTs.toDate().hour.toString().padLeft(2,'0')}:${completedAtTs.toDate().minute.toString().padLeft(2,'0')}'
        : null;
    final bagId = d['bagId'] as String? ?? '';
    final pickupCode = d['pickupCode'] as String? ?? '';
    final ts = d['timestamp'] as int? ?? 0;
    // timestamp is stored in SECONDS, not milliseconds
    final dt = ts > 0 ? DateTime.fromMillisecondsSinceEpoch(ts * 1000) : null;
    final dateStr = dt != null ? '${dt.day}/${dt.month}/${dt.year}' : '—';
    final orderId = doc.id;
    final showCode = pickupCode.isNotEmpty && (status == 'confirmed' || status == 'preparing' || status == 'ready');
    // FIX: a customer whose payment succeeded but whose order hasn't
    // caught up to 'confirmed' status yet (still being verified
    // server-side) would see nothing here at all - easily mistaken for
    // "my payment failed" when it actually succeeded and their code is
    // already sitting on the order, just not flagged as confirmed yet.
    // This gives an honest "verifying" state instead of nothing, so
    // they know their order exists and just needs a moment.
    final verifyingCode = pickupCode.isNotEmpty && status == 'pending';
    final canReport = _canReport(d);
    final canRate = _canRate(d);

    return GestureDetector(
      onTap: () => context.pushNamed(
        OrderConfirmationWidget.routeName,
        queryParameters: {'orderId': serializeParam(orderId, ParamType.String)}.withoutNulls),
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 14, offset: const Offset(0, 4)),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4, offset: const Offset(0, 1)),
        ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: _kMintBg, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.shopping_bag, color: _kGreen, size: 22)),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Order #${orderId.substring(0, orderId.length >= 6 ? 6 : orderId.length).toUpperCase()}',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700, fontSize: 15, color: _kTextDark,
                  letterSpacing: -0.3)),
              const SizedBox(height: 2),
              // FIX: merchantName was already stored on this order
              // document (used elsewhere in this file for the rating
              // dialog) but never actually shown here - the one screen a
              // customer looks at while trying to figure out which shop
              // to go to. No extra fetch needed, the data was already in
              // hand.
              if ((d['merchantName'] as String?)?.isNotEmpty == true)
                Text('📍 ${d['merchantName']}', style: GoogleFonts.plusJakartaSans(
                  color: _kGreen, fontWeight: FontWeight.w700, fontSize: 12)),
              if (bagId.isNotEmpty)
                FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('bags').doc(bagId).get(),
                  builder: (_, snap) {
                    final title = (snap.data?.data()
                      as Map<String, dynamic>?)?['title'] as String?
                      ?? 'Surprise Bag';
                    return Text(title, style: GoogleFonts.plusJakartaSans(
                      color: _kTextSecondary, fontSize: 13));
                  })
              else Text('Surprise Bag', style: GoogleFonts.plusJakartaSans(
                color: _kTextSecondary, fontSize: 13)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _statusColor(status).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20)),
              child: Text(_statusLabel(status, isFreshFood: isFreshFood), style: GoogleFonts.plusJakartaSans(
                color: _statusColor(status),
                fontWeight: FontWeight.w700, fontSize: 11))),
          ])),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: Column(children: [
            Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Amount', style: GoogleFonts.plusJakartaSans(
                  color: _kTextSecondary, fontSize: 11)),
                const SizedBox(height: 2),
                Text('Rs.${amountPaid.toStringAsFixed(0)}',
                  style: GoogleFonts.plusJakartaSans(
                    color: _kGreen, fontWeight: FontWeight.w800, fontSize: 16)),
                if (platformFee > 0)
                  Text('incl. Rs.${platformFee.toStringAsFixed(0)} platform fee',
                    style: GoogleFonts.plusJakartaSans(
                      color: _kTextSecondary, fontSize: 9.5)),
              ]),
              const SizedBox(width: 24),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Date', style: GoogleFonts.plusJakartaSans(
                  color: _kTextSecondary, fontSize: 11)),
                const SizedBox(height: 2),
                Text(dateStr, style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600, fontSize: 14)),
                if (completedAtStr != null)
                  Text('Collected $completedAtStr',
                    style: GoogleFonts.plusJakartaSans(
                      color: _kTextSecondary, fontSize: 9.5)),
              ]),
              const Spacer(),
              if (showCode)
                GestureDetector(
                  onTap: () => _showCode(context, pickupCode),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _kAmber,
                      borderRadius: BorderRadius.circular(10)),
                    child: Text('Show Code', style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w700, fontSize: 12))))
              else if (verifyingCode)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _kAmber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    SizedBox(width: 10, height: 10,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5, color: _kAmber)),
                    const SizedBox(width: 6),
                    Text('Verifying...', style: GoogleFonts.plusJakartaSans(
                      color: _kAmber,
                      fontWeight: FontWeight.w700, fontSize: 12)),
                  ]))
              else
                const Icon(Icons.chevron_right_rounded,
                  color: Colors.grey, size: 20),
            ]),
            if (canRate) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => _showRatingSheet(context, doc, d),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3DC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF5A623))),
                  alignment: Alignment.center,
                  child: Row(mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                    const Icon(Icons.star_rounded,
                      size: 16, color: Color(0xFFF5A623)),
                    const SizedBox(width: 6),
                    Text('Rate This Vendor',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: const Color(0xFF8A5A00))),
                  ]))),
            ],
            if (canReport) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => _showReportSheet(context, doc),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade200)),
                  alignment: Alignment.center,
                  child: Row(mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                    Icon(Icons.report_problem_outlined,
                      size: 14, color: Colors.red.shade600),
                    const SizedBox(width: 6),
                    Text('Report an Issue',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: Colors.red.shade600)),
                  ]))),
            ],
          ])),
      ])));
  }

  void _showCode(BuildContext context, String code) {
    showDialog(context: context, builder: (_) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('🎁', style: TextStyle(fontSize: 40)),
        const SizedBox(height: 12),
        Text('Your Pickup Code', style: GoogleFonts.plusJakartaSans(
          fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text('Show this to the vendor', style: GoogleFonts.plusJakartaSans(
          color: _kTextSecondary, fontSize: 13)),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: _kMintBg, borderRadius: BorderRadius.circular(14)),
          child: Text(code, style: const TextStyle(
            fontSize: 36, fontWeight: FontWeight.w900,
            color: _kGreen, letterSpacing: 8))),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: double.infinity, height: 46,
            decoration: BoxDecoration(
              color: _kGreen, borderRadius: BorderRadius.circular(12)),
            child: Center(child: Text('Done', style: GoogleFonts.plusJakartaSans(
              color: Colors.white, fontWeight: FontWeight.w700))))),
      ]))));
  }

  void _showReportSheet(BuildContext context, QueryDocumentSnapshot doc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReportSheet(doc: doc));
  }

  void _showRatingSheet(BuildContext context, QueryDocumentSnapshot doc, Map<String, dynamic> orderData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RatingSheet(doc: doc, orderData: orderData));
  }
}

// ── Vendor Rating Sheet ──────────────────────────────────────────────
// Writes to a separate `vendorRatings` collection rather than directly
// updating the vendor's average rating from the client — the average is
// recalculated server-side by a Cloud Function instead, so a vendor (or
// anyone with a compromised session) can't directly manipulate their own
// rating by writing to their own profile document.
class _RatingSheet extends StatefulWidget {
  final QueryDocumentSnapshot doc;
  final Map<String, dynamic> orderData;
  const _RatingSheet({required this.doc, required this.orderData});
  @override
  State<_RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends State<_RatingSheet> {
  int _stars = 0;
  final _commentCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_stars == 0) {
      setState(() => _error = 'Please select a star rating');
      return;
    }
    setState(() { _submitting = true; _error = null; });
    try {
      final uid = currentUserUid;
      final merchantId = widget.orderData['merchantId'] as String? ?? '';
      final merchantName = widget.orderData['merchantName'] as String? ?? '';
      final bagTitle = widget.orderData['bagTitle'] as String? ?? '';

      // Write the rating itself — this is what the Cloud Function
      // listens for to recalculate the vendor's server-side average.
      await FirebaseFirestore.instance.collection('vendorRatings').add({
        'orderId': widget.doc.id,
        'customerId': uid,
        'merchantId': merchantId,
        'merchantName': merchantName,
        'bagTitle': bagTitle,
        'stars': _stars,
        'comment': _commentCtrl.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Mark this order as rated so the prompt doesn't show again.
      await widget.doc.reference.update({
        'ratedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      // FIX: this previously discarded the actual error entirely,
      // showing only a generic message - masking the underlying cause
      // rather than surfacing it, which is exactly what made the
      // earlier "Could not submit rating" failure so hard to diagnose.
      debugPrint('Rating submission failed: $e');
      if (mounted) setState(() {
        _submitting = false;
        _error = 'Could not submit rating. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bagTitle = widget.orderData['bagTitle'] as String? ?? 'your order';
    final merchantName = widget.orderData['merchantName'] as String? ?? 'this vendor';
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Text('Rate $merchantName', style: GoogleFonts.plusJakartaSans(
            fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF0D1F12))),
          const SizedBox(height: 4),
          Text(bagTitle, style: GoogleFonts.plusJakartaSans(
            fontSize: 13, color: const Color(0xFF4D6B57))),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final starIndex = i + 1;
              final filled = starIndex <= _stars;
              return GestureDetector(
                onTap: () => setState(() { _stars = starIndex; _error = null; }),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(filled ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 40, color: const Color(0xFFF5A623))));
            })),
          const SizedBox(height: 16),
          TextField(
            controller: _commentCtrl,
            maxLines: 3,
            style: GoogleFonts.plusJakartaSans(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Optional — tell others what you thought',
              hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.grey.shade400),
              filled: true,
              fillColor: const Color(0xFFF4F7F4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.all(14)),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: GoogleFonts.plusJakartaSans(
              fontSize: 12, color: Colors.red.shade600)),
          ],
          const SizedBox(height: 18),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: _submitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A4731),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: _submitting
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text('Submit Rating', style: GoogleFonts.plusJakartaSans(
                  fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)))),
        ]),
      ),
    );
  }
}

// ── Report Issue Sheet ───────────────────────────────────────────────
class _ReportSheet extends StatefulWidget {
  final QueryDocumentSnapshot doc;
  const _ReportSheet({required this.doc});
  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  String? _selectedIssue;
  final List<XFile> _photos = [];
  bool _submitting = false;
  String? _error;

  // Policy: taste preference and portion size are not refund grounds -
  // a Surprise Bag's contents are a surprise by design, so "not what I
  // expected" isn't a service failure the way a closed shop or a food
  // safety problem is. That feedback belongs in a rating instead (see
  // the explanatory text below the list) - it genuinely helps a vendor
  // improve, where a refund on a delivered, safe bag does not.
  static const _issues = [
    ('vendor_closed', '🚫 Vendor was closed / Did not show up', true),
    ('wrong_item', '📦 Wrong item given', true),
    ('food_safety', '🦠 Food safety issue (hair, foreign object, contamination)', true),
    ('payment_issue', '💳 Payment deducted but order not confirmed', false),
    ('other', '❓ Other issue', true),
  ];

  bool get _needsPhoto {
    if (_selectedIssue == null) return false;
    final issue = _issues.firstWhere((i) => i.$1 == _selectedIssue,
      orElse: () => ('', '', false));
    return issue.$3;
  }

  bool get _autoApprove =>
      _selectedIssue == 'vendor_closed' ||
      _selectedIssue == 'payment_issue';

  // Per policy: vendor cancellations, out-of-stock, and technical errors
  // refund to the customer's original payment method (processed manually
  // via the Razorpay dashboard — no automated refund API is wired up yet).
  // Only serious verified complaints (e.g. food safety) go to the Wallet,
  // and only after manual review — never auto-credited.
  bool get _refundsToOriginalMethod =>
      _selectedIssue == 'vendor_closed' ||
      _selectedIssue == 'payment_issue';

  Future<void> _pickPhoto() async {
    if (_photos.length >= 2) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery, imageQuality: 70, maxWidth: 1280);
    if (picked != null) setState(() => _photos.add(picked));
  }

  Future<List<String>> _uploadPhotos(String orderId) async {
    final urls = <String>[];
    for (int i = 0; i < _photos.length; i++) {
      final ref = FirebaseStorage.instance
          .ref('refund_evidence/$orderId/photo_$i.jpg');
      await ref.putFile(File(_photos[i].path));
      urls.add(await ref.getDownloadURL());
    }
    return urls;
  }

  Future<void> _submit() async {
    if (_selectedIssue == null) {
      setState(() => _error = 'Please select an issue type');
      return;
    }
    if (_needsPhoto && _photos.isEmpty && !_autoApprove) {
      setState(() => _error = 'Please add at least one photo as evidence');
      return;
    }
    setState(() { _submitting = true; _error = null; });

    try {
      final d = widget.doc.data() as Map<String, dynamic>;
      final orderId = widget.doc.id;
      final customerId = currentUserUid;
      final amountPaid = (d['amountPaid'] as num?)?.toDouble() ?? 0;
      final merchantId = d['merchantId'] as String? ?? '';

      // Check how many previous refund requests this customer has made
      final prevClaims = await FirebaseFirestore.instance
          .collection('refundRequests')
          .where('customerId', isEqualTo: customerId)
          .get();
      final claimCount = prevClaims.docs.length;

      // Upload photos
      final photoUrls = await _uploadPhotos(orderId);

      // Auto-approve for vendor_closed and payment_issue — both refund to
      // the customer's original payment method, processed manually via
      // Razorpay (no refund API integration yet).
      String initialStatus = _autoApprove ? 'approved_bank' : 'pending';
      String adminNote = '';

      if (_autoApprove) {
        adminNote = _selectedIssue == 'vendor_closed'
          ? 'Auto-approved: Vendor closed/no-show. Refund to original payment method via Razorpay dashboard.'
          : 'Auto-approved: Payment issue. Please process via Razorpay dashboard.';
      }

      // Create refund request
      await FirebaseFirestore.instance.collection('refundRequests').add({
        'orderId': orderId,
        'customerId': customerId,
        'merchantId': merchantId,
        'issueType': _selectedIssue,
        'issueLabel': _issues.firstWhere((i) => i.$1 == _selectedIssue).$2,
        'amountPaid': amountPaid,
        'photoUrls': photoUrls,
        'status': initialStatus,
        'adminNote': adminNote,
        'submittedAt': DateTime.now().millisecondsSinceEpoch,
        'previousClaimsCount': claimCount,
        'isSerialClaimer': claimCount >= 2,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_autoApprove
            ? 'Refund approved! We\'ll process it to your original payment method within 5-7 business days.'
            : 'Issue reported. We\'ll review within 24 hours.'),
          backgroundColor: _kGreen));
      }
    } catch (e) {
      setState(() {
        _submitting = false;
        _error = 'Could not submit. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4,
            decoration: BoxDecoration(
              color: _kBorder, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              const Icon(Icons.report_problem_rounded,
                color: Colors.red, size: 22),
              const SizedBox(width: 10),
              Text('Report an Issue', style: GoogleFonts.plusJakartaSans(
                fontSize: 18, fontWeight: FontWeight.w800, color: _kTextDark)),
            ])),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Reports must be submitted within 2 hours of pickup time. '
              'Photo evidence is required for food safety and wrong item claims.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12, color: _kTextSecondary))),
          const SizedBox(height: 16),
          Expanded(child: ListView(
            controller: ctrl,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
            // Issue type selector
            Text('What went wrong?', style: GoogleFonts.plusJakartaSans(
              fontSize: 13, fontWeight: FontWeight.w700, color: _kTextDark)),
            const SizedBox(height: 8),
            ..._issues.map((issue) {
              final sel = _selectedIssue == issue.$1;
              return GestureDetector(
                onTap: () => setState(() => _selectedIssue = issue.$1),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: sel ? _kMintBg : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: sel ? _kGreen : _kBorder,
                      width: sel ? 2 : 1)),
                  child: Row(children: [
                    Expanded(child: Text(issue.$2,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                        color: sel ? _kGreen : _kTextDark))),
                    if (sel)
                      const Icon(Icons.check_circle_rounded,
                        color: _kGreen, size: 18),
                  ])));
            }),

            // Redirects taste/portion feedback to a rating instead of a refund
            // claim - genuinely useful to the vendor, a refund isn't.
            Container(
              margin: const EdgeInsets.only(bottom: 4, top: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _kMintBg.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10)),
              child: Text(
                'Wasn\'t quite to your taste, or a bit less than you hoped for? '
                'That\'s not something we refund, since every Surprise Bag is a genuine surprise - '
                'but please close this and tap \u2b50 Rate on your order instead. '
                'The vendor sees every rating and it genuinely helps them improve.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, color: _kTextSecondary, height: 1.4))),

            // Auto-approve notice
            if (_autoApprove) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _kMintBg, borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  const Icon(Icons.bolt_rounded, color: _kGreen, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    _selectedIssue == 'vendor_closed'
                      ? 'Wallet will be credited immediately upon submission.'
                      : 'We will process this within 5-7 working days via Razorpay.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12, color: _kGreen, fontWeight: FontWeight.w600))),
                ])),
            ],

            // Photo evidence
            if (_needsPhoto && !_autoApprove) ...[
              const SizedBox(height: 16),
              Text('Photo Evidence ${_photos.isEmpty ? "(Required)" : "(${_photos.length}/2)"}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13, fontWeight: FontWeight.w700, color: _kTextDark)),
              const SizedBox(height: 4),
              Text('Clear photos of the issue help us resolve faster.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, color: _kTextSecondary)),
              const SizedBox(height: 8),
              Row(children: [
                ..._photos.map((p) => Container(
                  width: 80, height: 80,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _kBorder)),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: Image.file(File(p.path), fit: BoxFit.cover)))),
                if (_photos.length < 2)
                  GestureDetector(
                    onTap: _pickPhoto,
                    child: Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        color: _kMintBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _kBorder)),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                        const Icon(Icons.add_a_photo_outlined,
                          color: _kGreen, size: 24),
                        const SizedBox(height: 4),
                        Text('Add Photo', style: GoogleFonts.plusJakartaSans(
                          fontSize: 10, color: _kGreen, fontWeight: FontWeight.w600)),
                      ]))),
              ]),
            ],

            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8)),
                child: Text(_error!, style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, color: Colors.red.shade700))),
            ],

            const SizedBox(height: 20),

            // Refund policy note
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFE082))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Refund Policy', style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: const Color(0xFF856404))),
                const SizedBox(height: 4),
                Text(
                  '• Missed pickup = no refund (food was prepared for you)\n'
                  '• Vendor no-show / payment issue = refund to your original payment method (card/UPI), processed within 5-7 business days\n'
                  '• Food safety/wrong item = reviewed with photo evidence — approved refunds may go to your Surpl Wallet at Surpl\'s discretion\n'
                  '• Repeat false claims may result in account suspension',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11, color: const Color(0xFF856404), height: 1.6)),
              ])),

            const SizedBox(height: 20),

            GestureDetector(
              onTap: _submitting ? null : _submit,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: _submitting ? _kGreen.withValues(alpha: 0.6) : _kGreen,
                  borderRadius: BorderRadius.circular(14)),
                alignment: Alignment.center,
                child: _submitting
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                  : Text('Submit Report', style: GoogleFonts.plusJakartaSans(
                      fontSize: 15, fontWeight: FontWeight.w700,
                      color: Colors.white)))),

            const SizedBox(height: 30),
          ])),
        ])));
  }
}