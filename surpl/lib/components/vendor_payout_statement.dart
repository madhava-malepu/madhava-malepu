import 'package:flutter/material.dart';
import '/services/community_service.dart';
class VendorPayoutStatement extends StatefulWidget {
  final String vendorId;
  const VendorPayoutStatement({super.key,required this.vendorId});
  @override State<VendorPayoutStatement> createState()=>_VendorPayoutStatementState();
}
class _VendorPayoutStatementState extends State<VendorPayoutStatement>{
  int _week=0; late Future<Map<String,dynamic>> _data;
  @override void initState(){super.initState();_load();}
  void _load(){_data=CommunityService.call('getVendorPayoutStatement',{'vendorId':widget.vendorId,'weekOffset':_week});}
  String money(dynamic v)=>'₹${((v as num? ?? 0)/100).toStringAsFixed(2)}';
  @override Widget build(BuildContext context)=>Column(children:[
    Padding(padding:const EdgeInsets.all(12),child:Row(children:[Expanded(child:DropdownButton<int>(value:_week,isExpanded:true,items:List.generate(104,(i)=>DropdownMenuItem(value:-i,child:Text(i==0?'Current week':i==1?'Last completed week':'$i weeks ago'))),onChanged:(v){if(v!=null)setState((){_week=v;_load();});})),IconButton(onPressed:()=>setState(_load),icon:const Icon(Icons.refresh))])),
    Expanded(child:FutureBuilder<Map<String,dynamic>>(future:_data,builder:(context,snap){if(snap.hasError)return Center(child:TextButton(onPressed:()=>setState(_load),child:const Text('Could not load statement. Retry')));if(!snap.hasData)return const Center(child:CircularProgressIndicator());final s=snap.data!;final p=Map<String,dynamic>.from(s['period'] as Map);final lines=List<Map<String,dynamic>>.from((s['lines'] as List).map((x)=>Map<String,dynamic>.from(x)));final payments=List<Map<String,dynamic>>.from((s['payments'] as List).map((x)=>Map<String,dynamic>.from(x)));return ListView(padding:const EdgeInsets.all(16),children:[
      Text('Friday payout: ${p['payoutDate']}',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:18)),const Text('Same recorded statement as Surpl admin. Friday preparation at 9 a.m. India time; transfers are recorded separately.'),
      for(final pair in [['Opening balance','opening'],['Vendor earnings','earnings'],['Commission','commission'],['Platform fees','fees'],['GST recorded','gst'],['Refunds (already excluded)','refunds'],['Approved adjustments','adjustments'],['Paid this week','paid'],['Closing balance','closing'],['Remaining due','due'],['Credit / overpayment','credit']])ListTile(dense:true,title:Text(pair[0]),trailing:Text(money(s[pair[1]]))),
      if((s['duplicates'] as List).isNotEmpty||(s['reviewCount'] as num)>0)const Text('Some payment records need review. Contact Surpl before treating this balance as final.',style:TextStyle(color:Colors.red)),
      const Text('Orders',style:TextStyle(fontWeight:FontWeight.bold)),for(final o in lines)ExpansionTile(title:Text('${o['title']} · ${money(o['earning'])}'),subtitle:Text('${o['id']} · ${o['status']}'),children:[Text('Paid ${money(o['sales'])} · Fee ${money(o['fee'])} · Commission ${money(o['commission'])} · Refund ${money(o['refund'])}')]),
      const Text('Payment history',style:TextStyle(fontWeight:FontWeight.bold)),for(final p in payments)ListTile(title:Text('${money(p['amount'])} · ${p['status']}'),subtitle:Text('${p['category']} · ${p['reference']}')),
      const Text('Adjustments',style:TextStyle(fontWeight:FontWeight.bold)),for(final a in (s['adjustmentLines'] as List))ListTile(title:Text('${money(a['amount'])} · ${a['reason']}'),subtitle:Text('${a['orderId']}')),
      Text(s['note'] as String),
    ]);})),
  ]);
}
