import '/services/community_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

// Party Mode - real vendor matching, not surplus. A customer describes
// an occasion (people, budget, area, pickup time), and this queries
// vendors who've genuinely declared bulk capacity (built on the
// vendor dashboard) and can fit that group size. The customer picks a
// vendor, the vendor accepts, and actual payment happens through the
// existing order-creation flow once a specific vendor and price are
// confirmed - this page is the matching layer, not the payment layer.
class PartyModeWidget extends StatefulWidget {
  const PartyModeWidget({Key? key}) : super(key: key);
  static String get routeName => 'PartyMode';
  static String get routePath => '/partyMode';

  @override
  State<PartyModeWidget> createState() => _PartyModeWidgetState();
}

class _PartyModeWidgetState extends State<PartyModeWidget> {
  static const _green = Color(0xFF1A4731);
  static const _greenDark = Color(0xFF0D1F12);
  static const _amber = Color(0xFFF5A623);
  static const _sage = Color(0xFF4D6B57);

  final _peopleCtrl = TextEditingController(text: '10');
  final _budgetCtrl = TextEditingController(text: '2000');
  final _areaCtrl = TextEditingController();
  String _occasionType = 'Birthday';
  bool _searching = false;
  bool _sending = false;
  DateTime? _pickup;
  int _searchEpoch = 0;
  final Map<String, String> _requestIds = {};
  @override void initState() { super.initState(); for (final c in [_peopleCtrl, _budgetCtrl, _areaCtrl]) { c.addListener(_invalidate); } }
  void _invalidate() { if (mounted) setState(() { _searchEpoch++; _matches = null; _searching = false; _requestIds.clear(); }); }
  @override void dispose() { _peopleCtrl.dispose(); _budgetCtrl.dispose(); _areaCtrl.dispose(); super.dispose(); }
  Future<void> _choosePickup() async {
    final now = DateTime.now();
    final day = await showDatePicker(context: context, initialDate: now, firstDate: DateTime(now.year,now.month,now.day), lastDate: now.add(const Duration(days:365)));
    if(day == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours:2))));
    if(time == null || !mounted) return;
    final date = DateTime(day.year, day.month, day.day, time.hour, time.minute);
    if(!date.isAfter(DateTime.now())) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Choose a future pickup time.'))); return; }
    setState(() => _pickup = date); _invalidate();
  }
  List<Map<String, dynamic>>? _matches;

  final _occasionTypes = ['Birthday', 'College Party', 'Office Celebration',
    'Farewell', 'Wedding Function', 'Cricket Night', 'Housewarming', 'Festival Party'];

  Future<void> _findVendors() async {
    final people = int.tryParse(_peopleCtrl.text.trim());
    final budget = double.tryParse(_budgetCtrl.text.trim());
    final area = _areaCtrl.text.trim();
    if (people == null || people < 1 || people > 10000 || _areaCtrl.text.trim().isEmpty || _areaCtrl.text.trim().length > 100 ||
        (_budgetCtrl.text.trim().isNotEmpty && (budget == null || !budget.isFinite || budget < 0 || budget > 10000000))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid number of people and budget.')));
      return;
    }
    final epoch = ++_searchEpoch;
    setState(() { _searching = true; _matches = null; });

    // FIX: a direct client query against `users` would fail entirely -
    // a customer has no read permission on any vendor's document, let
    // alone a multi-document query across all of them. This now runs
    // server-side via findPartyVendors, which returns only safe fields
    // per match.
    try {
      final result = await FirebaseFunctions.instanceFor(region: 'asia-south1')
          .httpsCallable('findPartyVendors')
          .call({'people': people, if (budget != null) 'budget': budget, 'area': area});
      final matches = (result.data['matches'] as List)
          .map((m) => Map<String, dynamic>.from(m as Map))
          .toList();
      if (mounted && epoch == _searchEpoch) setState(() { _searching = false; _matches = matches; });
    } catch (e) {
      if (mounted) {
        if (epoch != _searchEpoch) return;
        setState(() { _searching = false; _matches = null; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(CommunityService.error(e))));
      }
    }
  }

  Future<void> _requestVendor(Map<String, dynamic> vendorMap) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in first.')));
      return;
    }
    final people = int.tryParse(_peopleCtrl.text.trim());
    final budget = double.tryParse(_budgetCtrl.text.trim());
    if (people == null || people < 1 || people > 10000 || _areaCtrl.text.trim().isEmpty || _areaCtrl.text.trim().length > 100 ||
        (_budgetCtrl.text.trim().isNotEmpty && (budget == null || !budget.isFinite || budget < 0 || budget > 10000000))) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Check the people count and optional budget.')));
      return;
    }
    // FIX: this write had no error handling at all - unlike _findVendors
    // above, a failure here (network blip, expired session, a security
    // rule rejection) was completely silent: no message, nothing visible,
    // the button just did nothing. A customer describing this as "getting
    // an error" with no detail is exactly what that looks like from the
    // outside. Matches the same try/catch + SnackBar pattern already used
    // in _findVendors, so a failure is now visible instead of invisible.
    if (_sending) return;
    if (_pickup == null || !_pickup!.isAfter(DateTime.now())) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choose a future pickup date and time.'))); return; }
    setState(() => _sending = true);
    try {
      await CommunityService.call('createPartyRequest', {
        'customerId': uid,
        'occasionType': _occasionType,
        'people': people,
        if (budget != null) 'budget': budget,
        'area': _areaCtrl.text.trim(),
        'vendorId': vendorMap['vendorId'],
        'requestId': _requestIds.putIfAbsent(vendorMap['vendorId'] as String, () => FirebaseFirestore.instance.collection('occasionRequests').doc().id),
        'pickupAtMillis': _pickup!.millisecondsSinceEpoch,
        'status': 'open',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request sent - the vendor will confirm shortly.')));
        setState(() => _matches?.removeWhere((v) => v['vendorId'] == vendorMap['vendorId']));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(CommunityService.error(e))));
      }
    } finally { if (mounted) setState(() => _sending = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F3EC),
      appBar: AppBar(backgroundColor: _green,
        title: const Text('Party Mode', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
        iconTheme: const IconThemeData(color: Colors.white)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Planning something bigger than a solo meal?',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: _greenDark)),
        const SizedBox(height: 4),
        Text('Send a pickup enquiry. Confirm the menu, final price and pickup with the vendor; this is not a paid booking.',
          style: TextStyle(fontSize: 12.5, color: _sage)),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _occasionType,
          decoration: const InputDecoration(labelText: 'Occasion', border: OutlineInputBorder()),
          items: _occasionTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
          onChanged: (v) { setState(() => _occasionType = v ?? _occasionType); _invalidate(); },
        ),
        const SizedBox(height: 10),
        TextField(controller: _peopleCtrl, keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'How many people', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(controller: _budgetCtrl, keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Total budget (₹, optional)', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(controller: _areaCtrl,
          decoration: const InputDecoration(labelText: 'Area / locality', border: OutlineInputBorder())),
        const SizedBox(height: 16),
        OutlinedButton.icon(onPressed: _choosePickup, icon: const Icon(Icons.event), label: Text(_pickup == null ? 'Choose pickup date and time' : _pickup!.toLocal().toString().substring(0,16))),
        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: _searching ? null : _findVendors,
          style: ElevatedButton.styleFrom(backgroundColor: _amber, foregroundColor: _greenDark),
          child: Padding(padding: const EdgeInsets.symmetric(vertical: 12),
            child: _searching ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Find vendors', style: TextStyle(fontWeight: FontWeight.w700))),
        )),
        const SizedBox(height: 20),
        if (_matches != null) ...[
          Text(_matches!.isEmpty ? 'No vendors currently match this - try a wider budget or different area.' : '${_matches!.length} vendors can handle this',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: _matches!.isEmpty ? _sage : _greenDark)),
          const SizedBox(height: 10),
          ..._matches!.map((data) {
            final people = int.tryParse(_peopleCtrl.text.trim()) ?? 1;
            final pricePerPerson = (data['bulkPricePerPerson'] as num?)?.toDouble() ?? 0;
            final total = pricePerPerson * people;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE8E8E8))),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(data['shopName'] as String? ?? 'Vendor', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  Text('₹${pricePerPerson.toStringAsFixed(0)}/person · ~₹${total.toStringAsFixed(0)} total',
                    style: TextStyle(fontSize: 12, color: _sage)),
                ])),
                ElevatedButton(onPressed: _sending ? null : () => _requestVendor(data), child: Text(_sending ? 'Sending…' : 'Request')),
              ]),
            );
          }),
        ],
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 12),
        const Text('Your requests', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: _greenDark)),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseAuth.instance.currentUser == null ? null :
            FirebaseFirestore.instance.collection('occasionRequests')
              .where('customerId', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
              .snapshots(),
          builder: (context, snap) {
            if (FirebaseAuth.instance.currentUser == null) {
              return const Text('Sign in to see your requests.', style: TextStyle(color: _sage, fontSize: 12.5));
            }
            if (snap.hasError) return const Text('Could not load request history. Please reopen to retry.');
            if (!snap.hasData) return const LinearProgressIndicator();
            if (snap.data!.docs.isEmpty) {
              return const Text('No requests yet.', style: TextStyle(color: _sage, fontSize: 12.5));
            }
            return Column(children: snap.data!.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final status = data['status'] as String? ?? 'open';
              final isAccepted = status == 'accepted';
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isAccepted ? const Color(0xFFEAF7EE) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isAccepted ? const Color(0xFF1A8A3E) : const Color(0xFFE8E8E8))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${data['occasionType']} · ${data['people']} people',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  Text(isAccepted ? 'Accepted for discussion — confirm menu, price and pickup' : status == 'declined' ? 'Vendor could not take this request' : status == 'cancelled' ? 'Cancelled' : 'Waiting for vendor to respond',
                    style: TextStyle(fontSize: 12, color: isAccepted ? const Color(0xFF1A8A3E) : _sage)),
                  if (data['pickupAtMillis'] is num) Text('Pickup: ${DateTime.fromMillisecondsSinceEpoch((data['pickupAtMillis'] as num).toInt()).toLocal().toString().substring(0,16)}'),
                  if (status == 'open') TextButton(onPressed: () async {
                    try { await CommunityService.call('respondPartyRequest', {'requestId': doc.id, 'status': 'cancelled'}); }
                    catch(e) { if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(CommunityService.error(e)))); }
                  }, child: const Text('Cancel request')),
                  if (isAccepted) FutureBuilder<Map<String, dynamic>?>(
                    future: FirebaseFunctions.instanceFor(region: 'asia-south1')
                        .httpsCallable('getPublicVendorInfo')
                        .call({'vendorId': data['acceptedVendorId']})
                        .then<Map<String, dynamic>?>((result) => Map<String, dynamic>.from(result.data as Map))
                        .catchError((_) => null),
                    builder: (context, vSnap) {
                      final vData = vSnap.data;
                      if (vData == null) return const SizedBox.shrink();
                      return Padding(padding: const EdgeInsets.only(top: 6),
                        child: Text('${vData['shopName'] ?? 'Vendor'} · ${vData['phoneNumber'] ?? ''}',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)));
                    },
                  ),
                ]),
              );
            }).toList());
          },
        ),
      ]),
    );
  }
}
