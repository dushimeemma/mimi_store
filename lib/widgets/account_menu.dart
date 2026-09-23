import 'package:flutter/material.dart';

import '../models/user_role.dart';
import '../state/auth_controller.dart';
import '../state/store_controller.dart';

class AccountMenu extends StatelessWidget {
  const AccountMenu({super.key, required this.auth});
  final AuthController auth;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: auth,
      builder: (context, _) => PopupMenuButton<String>(
        tooltip: 'Account',
        onSelected: (value) { if (value=='logout') auth.logout();if(value=='orders')_showOrders(context); },
        itemBuilder: (context)=>[
          PopupMenuItem(enabled:false,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(auth.user?['email']?.toString()??'',style:const TextStyle(fontWeight:FontWeight.w700)),Text(auth.store.role.label,style:const TextStyle(color:Colors.black54))])),
          const PopupMenuDivider(),
          if(auth.store.role==UserRole.customer)const PopupMenuItem(value:'orders',child:ListTile(contentPadding:EdgeInsets.zero,leading:Icon(Icons.receipt_long_outlined),title:Text('My orders'))),
          const PopupMenuItem(value:'logout',child:ListTile(contentPadding:EdgeInsets.zero,leading:Icon(Icons.logout),title:Text('Sign out'))),
        ],
        child: const Padding(padding:EdgeInsets.all(10),child:Icon(Icons.account_circle_outlined)),
      ),
    );
  }

  Future<void> _showOrders(BuildContext context)async{await auth.store.loadRoleData();if(!context.mounted)return;await showDialog<void>(context:context,builder:(context)=>AlertDialog(title:const Text('My orders'),content:SizedBox(width:560,child:auth.store.orders.isEmpty?const Padding(padding:EdgeInsets.all(30),child:Text('You have no orders yet.')):ListView(shrinkWrap:true,children:auth.store.orders.map((order)=>ListTile(title:Text(order['orderNumber']?.toString()??'',style:const TextStyle(fontWeight:FontWeight.w700)),subtitle:Text((order['status']??'').toString().replaceAll('_',' ')),trailing:Text(formatRwf(((order['totalRwf']??0)as num).toInt())))).toList())),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Close'))]));}
}
