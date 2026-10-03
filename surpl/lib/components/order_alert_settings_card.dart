import 'package:flutter/material.dart';
import '/services/notification_service.dart';

class OrderAlertSettingsCard extends StatefulWidget {
  const OrderAlertSettingsCard({super.key});
  @override State<OrderAlertSettingsCard> createState()=>_OrderAlertSettingsCardState();
}
class _OrderAlertSettingsCardState extends State<OrderAlertSettingsCard> with WidgetsBindingObserver {
  late Future<Map<String,dynamic>> _status;
  @override void initState(){super.initState();WidgetsBinding.instance.addObserver(this);_status=NotificationService.alertStatus();}
  @override void dispose(){WidgetsBinding.instance.removeObserver(this);super.dispose();}
  @override void didChangeAppLifecycleState(AppLifecycleState state){if(state==AppLifecycleState.resumed&&mounted)setState(()=>_status=NotificationService.alertStatus());}
  Future<void> _test()async{
    try{await NotificationService.testOrderSound();}
    catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Could not play the test. Check notification settings.')));}
  }
  @override Widget build(BuildContext context)=>Card(margin:const EdgeInsets.fromLTRB(16,10,16,0),child:Padding(padding:const EdgeInsets.all(14),
    child:FutureBuilder<Map<String,dynamic>>(future:_status,builder:(context,snap){final d=snap.data??{};
      final ready=d['enabled']==true&&d['channelEnabled']==true&&d['soundEnabled']==true&&(d['volume'] as num? ?? 0)>0&&d['doNotDisturb']==false;
      return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(ready?'Order alerts enabled':'Check your order alerts',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:16)),
        if(d['available']==true)Text('Notifications: ${d['enabled']==true?'on':'off'} · Sound: ${d['volume']}/${d['maxVolume']} · Do Not Disturb: ${d['doNotDisturb']==true?'on':'off'}'),
        const Text('Keep notifications and incoming-order sound enabled. Increase notification volume in Android settings. Force-stopping SURPL blocks alerts until you reopen it.'),
        Wrap(spacing:8,children:[TextButton(onPressed:_test,child:const Text('Test order sound')),
          TextButton(onPressed:()async{try{await NotificationService.openAlertSettings();}catch(_){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Open Android Settings → Apps → SURPL → Notifications.')));}},child:const Text('Alert settings'))]),
      ]);
    })));
}
