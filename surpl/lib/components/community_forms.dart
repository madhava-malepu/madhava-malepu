import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '/services/community_service.dart';

Future<void> showRestaurantRequestForm(BuildContext context, {bool referral = false}) async {
  final name = TextEditingController(), area = TextEditingController(), city = TextEditingController();
  var sending = false;
  String? error;
  try {
    await showModalBottomSheet<void>(context: context, isScrollControlled: true,
      builder: (sheet) => StatefulBuilder(builder: (ctx, update) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(referral ? 'Refer another shop' : 'Bring your restaurant', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(referral ? '₹200 for one eligible referring vendor after the new shop is approved and completes 5 genuine pickups. Self-referrals do not qualify.'
            : 'Tell us the shop and location. Matching requests are combined so every supporter counts once.'),
          const SizedBox(height: 12),
          for (final field in [(name, 'Restaurant name'), (area, 'Area / locality'), (city, 'City')])
            Padding(padding: const EdgeInsets.only(bottom: 10), child: TextField(controller: field.$1,
              enabled: !sending, maxLength: 100, decoration: InputDecoration(labelText: field.$2, border: const OutlineInputBorder()))),
          if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: sending ? null : () async {
              if ([name, area, city].any((c) => c.text.trim().isEmpty)) { update(() => error = 'Enter the restaurant, area and city.'); return; }
              update(() { sending = true; error = null; });
              try {
                final result = await CommunityService.call('requestRestaurant', {'restaurantName': name.text.trim(),
                  'area': area.text.trim(), 'city': city.text.trim(), 'referredByVendor': referral});
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
                  result['existing'] == true ? 'This request is already recorded. Your support is saved.' : referral ? 'Referral recorded. Track its progress here.' : 'Restaurant request saved.')));
              } catch (e) { if (ctx.mounted) update(() { sending = false; error = CommunityService.error(e); }); }
            }, child: Text(sending ? 'Saving…' : referral ? 'Submit referral' : 'Submit request'))),
        ])),
      )));
  } finally { name.dispose(); area.dispose(); city.dispose(); }
}

Future<void> showLoyalSurpriseForm(BuildContext context, String customerId) async {
  final message = TextEditingController(text: 'A free item on your next visit, just to say thanks!');
  final requestId = FirebaseFirestore.instance.collection('vendorSurprises').doc().id;
  var sending = false;
  String? error;
  try {
    await showModalBottomSheet<void>(context: context, isScrollControlled: true,
      builder: (sheet) => StatefulBuilder(builder: (ctx, update) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('A surprise for your regular', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Text('The gift is provided by you. It stays available until you confirm collection.'),
          const SizedBox(height: 12),
          TextField(controller: message, enabled: !sending, maxLength: 300, maxLines: 3,
            decoration: const InputDecoration(labelText: 'Describe the gift and any conditions', border: OutlineInputBorder())),
          if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
          ElevatedButton(onPressed: sending ? null : () async {
            if (message.text.trim().isEmpty) { update(() => error = 'Describe the gift first.'); return; }
            update(() { sending = true; error = null; });
            try {
              final result = await CommunityService.call('sendLoyalSurprise', {'customerId': customerId, 'message': message.text.trim(), 'requestId': requestId});
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
                result['existing'] == true ? 'This customer already has a saved surprise.' : 'Surprise saved in the customer’s gifts.')));
            } catch(e) { if (ctx.mounted) update(() { sending = false; error = CommunityService.error(e); }); }
          }, child: Text(sending ? 'Saving…' : 'Send surprise')),
        ]),
      )));
  } finally { message.dispose(); }
}

class VendorReferralsCard extends StatelessWidget {
  const VendorReferralsCard({super.key, required this.uid});
  final String uid;
  @override
  Widget build(BuildContext context) => Card(margin: const EdgeInsets.fromLTRB(16,10,16,0), child: Padding(
    padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Refer another vendor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      const Text('Earn ₹200 after approval and 5 genuine completed pickups. One reward per new vendor.'),
      TextButton(onPressed: () => showRestaurantRequestForm(context, referral:true), child: const Text('Refer a shop')),
      StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('restaurantRequests').where('requesterUid',isEqualTo:uid).snapshots(),
        builder: (context,snap) {
          if(snap.hasError) return const Text('Referral history unavailable. Please reopen to retry.');
          if(!snap.hasData) return const LinearProgressIndicator();
          final docs=snap.data!.docs.where((d)=>(d.data() as Map)['referredByVendor']==true).toList()
            ..sort((a,b)=> (((b.data() as Map)['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0)
              .compareTo(((a.data() as Map)['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0));
          return Column(children: docs.take(5).map((doc) {
            final d=doc.data() as Map;
            final status=d['rewardStatus']=='credited' ? '₹200 credited' : d['rewardStatus']=='already_attributed'
              ? 'Already attributed to an earlier referral' : d['status']=='fulfilled' ? 'Joined · reward qualification pending' : 'Submitted · awaiting review';
            return ListTile(contentPadding: EdgeInsets.zero,title:Text('${d['restaurantName'] ?? 'Shop'}'),subtitle:Text(status));
          }).toList());
        }),
    ])));
}
