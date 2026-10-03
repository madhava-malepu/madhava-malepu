import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/services/community_service.dart';
import '/components/community_forms.dart';

class LoyalCustomersPage extends StatefulWidget {
  const LoyalCustomersPage({super.key,required this.vendorId});
  final String vendorId;
  @override State<LoyalCustomersPage> createState()=>_LoyalCustomersPageState();
}
class _LoyalCustomersPageState extends State<LoyalCustomersPage> {
  late Future<Map<String,dynamic>> _customers;
  final Set<String> _redeeming={};
  @override void initState(){super.initState();_load();}
  void _load(){_customers=CommunityService.call('getLoyalCustomers',{});}
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Loyal customers')),
    body:ListView(padding:const EdgeInsets.all(16),children:[
      const Text('Regulars with 5 or more completed pickups. Split items count as one pickup; refunded orders do not count.'),
      FutureBuilder<Map<String,dynamic>>(future:_customers,builder:(context,snap){
        if(snap.hasError)return Column(children:[Text(CommunityService.error(snap.error!)),TextButton(onPressed:()=>setState(_load),child:const Text('Retry'))]);
        if(!snap.hasData)return const LinearProgressIndicator();
        final customers=(snap.data!['customers'] as List).cast<Map>();
        if(customers.isEmpty)return const Padding(padding:EdgeInsets.all(20),child:Text('Your regulars will appear here after 5 completed pickups.'));
        return Column(children:customers.map((c)=>Card(child:ListTile(title:Text('${c['name']}'),subtitle:Text('${c['count']} completed pickups'),
          trailing:TextButton(onPressed:()=>showLoyalSurpriseForm(context,c['customerId'] as String),child:const Text('Send gift'))))).toList());
      }),
      const SizedBox(height:20),const Text('Gifts awaiting collection',style:TextStyle(fontWeight:FontWeight.bold,fontSize:17)),
      StreamBuilder<QuerySnapshot>(stream:FirebaseFirestore.instance.collection('vendorSurprises').where('vendorId',isEqualTo:widget.vendorId).snapshots(),builder:(context,snap){
        if(snap.hasError)return const Text('Could not load gifts. Please reopen to retry.');
        if(!snap.hasData)return const LinearProgressIndicator();
        final docs=snap.data!.docs.where((d)=>(d.data() as Map)['redeemed']!=true).toList();
        if(docs.isEmpty)return const Text('No outstanding gifts.');
        return Column(children:docs.map((doc){final d=doc.data() as Map;return Card(child:ListTile(
          title:Text('${d['message'] ?? 'Gift'}'),subtitle:Text('Gift code: ${doc.id.substring(0,doc.id.length<8?doc.id.length:8).toUpperCase()}'),
          trailing:TextButton(onPressed:_redeeming.contains(doc.id)?null:()async{
            final confirm=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Confirm gift collected?'),
              content:const Text('Confirm only after handing this gift to the customer.'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Not yet')),
                TextButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Collected'))]));
            if(confirm!=true||!mounted)return;
            setState(()=>_redeeming.add(doc.id));
            try{await CommunityService.call('redeemSurprise',{'surpriseId':doc.id});}
            catch(e){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(CommunityService.error(e))));}
            finally{if(mounted)setState(()=>_redeeming.remove(doc.id));}
          },child:const Text('Collected'))));}).toList());
      }),
    ]));
}

class CustomerSurprisesPage extends StatelessWidget {
  const CustomerSurprisesPage({super.key});
  @override Widget build(BuildContext context){
    final uid=FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(appBar:AppBar(title:const Text('My gifts')),body:uid==null?const Center(child:Text('Sign in to see your gifts.')):
      StreamBuilder<QuerySnapshot>(stream:FirebaseFirestore.instance.collection('vendorSurprises').where('customerId',isEqualTo:uid).snapshots(),builder:(context,snap){
        if(snap.hasError)return const Center(child:Text('Could not load gifts. Please reopen to retry.'));
        if(!snap.hasData)return const Center(child:CircularProgressIndicator());
        if(snap.data!.docs.isEmpty)return const Center(child:Text('Gifts from your regular shops will appear here.'));
        return ListView(padding:const EdgeInsets.all(16),children:snap.data!.docs.map((doc){final d=doc.data() as Map;
          return Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('${d['vendorName'] ?? 'Your vendor'}',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:17)),
            Text('${d['message'] ?? 'A gift for you'}'),const SizedBox(height:8),
            Text(d['redeemed']==true?'Collected':'Show your vendor this code: ${doc.id.substring(0,doc.id.length<8?doc.id.length:8).toUpperCase()}'),
            if(d['redeemed']!=true)const Text('Viewing this gift does not redeem it. The vendor confirms collection.'),
          ])));
        }).toList());
      }));
  }
}
