import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../models/product.dart';

class ApiException implements Exception {
  const ApiException(this.message, [this.statusCode]);
  final String message;
  final int? statusCode;
  @override String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? client, FlutterSecureStorage? storage})
      : _client = client ?? http.Client(), _storage = storage ?? const FlutterSecureStorage();

  static const baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8080/api/v1');
  final http.Client _client;
  final FlutterSecureStorage _storage;
  String? _accessToken;

  Future<void> restoreSession() async { _accessToken = await _storage.read(key: 'access_token'); }
  Future<Map<String, dynamic>?> storedUser() async { final value=await _storage.read(key:'user'); return value==null?null:jsonDecode(value) as Map<String,dynamic>; }
  Future<void> saveSession(Map<String,dynamic> response) async {
    _accessToken=response['accessToken'] as String;
    await _storage.write(key:'access_token',value:_accessToken);
    await _storage.write(key:'refresh_token',value:response['refreshToken'] as String);
    await _storage.write(key:'user',value:jsonEncode(response['user']));
  }
  Future<void> clearSession() async { _accessToken=null; await _storage.deleteAll(); }

  Future<List<Product>> getProducts() async {
    final data=await _request('GET','/products',authenticated:false) as List<dynamic>;
    return data.map((item)=>Product.fromJson(item as Map<String,dynamic>)).toList();
  }
  Future<List<dynamic>> getCategories({bool admin=false}) async => await _request('GET',admin?'/admin/categories':'/categories',authenticated:admin) as List<dynamic>;
  Future<Map<String,dynamic>> getPublicSettings() async => await _request('GET','/settings/public',authenticated:false) as Map<String,dynamic>;
  Future<Map<String,dynamic>> login(String email,String password) async => await _request('POST','/auth/login',authenticated:false,body:{'email':email,'password':password}) as Map<String,dynamic>;
  Future<Map<String,dynamic>> register(String name,String email,String password,String phone) async => await _request('POST','/auth/register',authenticated:false,body:{'fullName':name,'email':email,'password':password,'phone':phone}) as Map<String,dynamic>;
  Future<Map<String,dynamic>> createOrder({required List<Map<String,dynamic>> items,required String address,required String phone,double? latitude,double? longitude}) async => await _request('POST','/orders',body:{'items':items,'deliveryAddress':address,'customerPhone':phone,if(latitude!=null)'latitude':latitude,if(longitude!=null)'longitude':longitude}) as Map<String,dynamic>;
  Future<Map<String,dynamic>> initiatePayment(String orderId) async => await _request('POST','/orders/$orderId/payment') as Map<String,dynamic>;
  Future<void> notifyManualPayment(String orderId,{String? transactionReference,String? note}) async { await _request('POST','/orders/$orderId/payment/notify',body:{if(transactionReference?.isNotEmpty==true)'transactionReference':transactionReference,if(note?.isNotEmpty==true)'note':note}); }
  Future<List<dynamic>> myOrders() async => await _request('GET','/orders/mine') as List<dynamic>;
  Future<List<dynamic>> adminOrders() async => await _request('GET','/admin/orders') as List<dynamic>;
  Future<Map<String,dynamic>> dashboard() async => await _request('GET','/admin/dashboard') as Map<String,dynamic>;
  Future<List<Product>> adminProducts() async { final data=await _request('GET','/admin/products') as List<dynamic>;return data.map((item)=>Product.fromJson(item as Map<String,dynamic>)).toList(); }
  Future<void> saveProduct(Map<String,dynamic> body,{String? id}) async { await _request(id==null?'POST':'PUT',id==null?'/admin/products':'/admin/products/$id',body:body); }
  Future<void> adjustInventory(String id,int delta,String reason) async { await _request('POST','/admin/products/$id/inventory',body:{'quantityDelta':delta,'reason':reason}); }
  Future<void> saveCategory(Map<String,dynamic> body,{String? id}) async { await _request(id==null?'POST':'PUT',id==null?'/admin/categories':'/admin/categories/$id',body:body); }
  Future<List<dynamic>> adminUsers() async => await _request('GET','/admin/users') as List<dynamic>;
  Future<List<dynamic>> adminDrivers() async => await _request('GET','/admin/drivers') as List<dynamic>;
  Future<void> updateUserRole(String id,String role) async { await _request('PATCH','/admin/users/$id/role',body:{'role':role}); }
  Future<void> updateUserStatus(String id,bool active) async { await _request('PATCH','/admin/users/$id/status',body:{'isActive':active}); }
  Future<List<dynamic>> adminPayments() async => await _request('GET','/admin/payments') as List<dynamic>;
  Future<void> reviewManualPayment(String id,bool approved,{String? note}) async { await _request('POST','/admin/payments/$id/${approved?'approve':'reject'}',body:{if(note?.isNotEmpty==true)'note':note}); }
  Future<void> reconcilePayments() async { await _request('POST','/admin/payments/reconcile'); }
  Future<List<dynamic>> deliveries() async => await _request('GET','/deliveries') as List<dynamic>;
  Future<void> assignDriver(String orderId,String driverId) async { await _request('PUT','/admin/orders/$orderId/driver',body:{'driverId':driverId}); }
  Future<void> updateDelivery(String id,String status,{String? notes}) async { await _request('PATCH','/deliveries/$id/status',body:{'status':status,if(notes!=null)'notes':notes}); }
  Future<Map<String,dynamic>> adminSettings() async => await _request('GET','/admin/settings') as Map<String,dynamic>;
  Future<void> updatePaymentSettings(String number,int fee,int threshold,String paymentMode) async { await _request('PUT','/admin/settings/payment',body:{'momoNumber':number,'deliveryFeeRwf':fee,'freeDeliveryThresholdRwf':threshold,'paymentMode':paymentMode}); }
  Future<void> updateStoreSettings(String name,String phone,String email) async { await _request('PUT','/admin/settings/store',body:{'storeName':name,'supportPhone':phone,'supportEmail':email}); }
  Future<List<dynamic>> auditLogs() async => await _request('GET','/admin/audit-logs') as List<dynamic>;
  Future<void> updateOrderStatus(String id,String status) async { await _request('PATCH','/orders/$id/status',body:{'status':status}); }

  Future<dynamic> _request(String method,String path,{Map<String,dynamic>? body,bool authenticated=true,bool retry=true}) async {
    final headers={'Content-Type':'application/json',if(authenticated&&_accessToken!=null)'Authorization':'Bearer $_accessToken'};
    final uri=Uri.parse('$baseUrl$path');
    final response=await switch(method){'GET'=>_client.get(uri,headers:headers),'POST'=>_client.post(uri,headers:headers,body:body==null?null:jsonEncode(body)),'PUT'=>_client.put(uri,headers:headers,body:jsonEncode(body)),'PATCH'=>_client.patch(uri,headers:headers,body:jsonEncode(body)),_=>throw const ApiException('Unsupported request')};
    if(response.statusCode==401&&authenticated&&retry&&await _refresh()) return _request(method,path,body:body,authenticated:authenticated,retry:false);
    final data=response.body.isEmpty?null:jsonDecode(response.body);
    if(response.statusCode<200||response.statusCode>=300){ final message=data is Map<String,dynamic>?data['message']:null; throw ApiException(message is List?message.join(', '):(message?.toString()??'Request failed'),response.statusCode); }
    return data;
  }

  Future<bool> _refresh() async {
    final token=await _storage.read(key:'refresh_token'); if(token==null)return false;
    try { final response=await _request('POST','/auth/refresh',authenticated:false,retry:false,body:{'refreshToken':token}) as Map<String,dynamic>; await saveSession(response); return true; }
    catch(_){ await clearSession(); return false; }
  }
}
