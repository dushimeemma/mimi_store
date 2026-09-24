import 'package:flutter/material.dart';

import '../models/order.dart';
import '../models/product.dart';
import '../models/user_role.dart';
import '../services/api_client.dart';

class StoreController extends ChangeNotifier {
  StoreController(this.api);
  final ApiClient api;

  UserRole role = UserRole.customer;
  String paymentNumber = '+250 788 440 177';
  String paymentMode = 'manual';
  int configuredDeliveryFeeRwf = 2500;
  int freeDeliveryThresholdRwf = 100000;
  String selectedCategory = 'All';
  String searchQuery = '';
  final Map<String, int> _cart = {};

  List<Product> products = [];
  List<Map<String, dynamic>> categories = [];
  List<Map<String, dynamic>> orders = [];
  List<Map<String, dynamic>> users = [];
  List<Map<String, dynamic>> payments = [];
  List<Map<String, dynamic>> deliveryRecords = [];
  List<Map<String, dynamic>> auditRecords = [];
  Map<String, dynamic> metrics = {};
  Map<String, dynamic> settings = {};
  bool loading = false;
  String? error;

  List<Product> get visibleProducts => products
      .where(
        (item) =>
            (selectedCategory == 'All' || item.category == selectedCategory) &&
            (searchQuery.isEmpty ||
                item.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
                item.description.toLowerCase().contains(
                  searchQuery.toLowerCase(),
                )),
      )
      .toList();
  Map<Product, int> get cartItems => {
    for (final product in products)
      if ((_cart[product.id] ?? 0) > 0) product: _cart[product.id]!,
  };
  int get cartCount => _cart.values.fold(0, (sum, quantity) => sum + quantity);
  int get subtotalRwf => cartItems.entries.fold(
    0,
    (sum, item) => sum + item.key.priceRwf * item.value,
  );
  int get deliveryRwf =>
      subtotalRwf == 0 || subtotalRwf >= freeDeliveryThresholdRwf
      ? 0
      : configuredDeliveryFeeRwf;
  int get totalRwf => subtotalRwf + deliveryRwf;
  List<Map<String, dynamic>> get drivers => users
      .where((user) => user['role'] == 'driver' && user['isActive'] == true)
      .toList();

  Future<void> initialize() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      products = await api.getProducts();
      categories = (await api.getCategories()).cast<Map<String, dynamic>>();
      final publicSettings = await api.getPublicSettings();
      _applyPaymentSettings(publicSettings);
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> loadRoleData() async {
    if (role == UserRole.admin || role == UserRole.superAdmin) {
      await refreshAdmin();
      return;
    }
    loading = true;
    notifyListeners();
    try {
      orders = (await api.myOrders()).cast<Map<String, dynamic>>();
      if (role == UserRole.driver)
        deliveryRecords = (await api.deliveries()).cast<Map<String, dynamic>>();
      error = null;
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> refreshAdmin() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      metrics = await api.dashboard();
      products = await api.adminProducts();
      categories = (await api.getCategories(admin: true))
          .cast<Map<String, dynamic>>();
      orders = (await api.adminOrders()).cast<Map<String, dynamic>>();
      payments = (await api.adminPayments()).cast<Map<String, dynamic>>();
      deliveryRecords = (await api.deliveries()).cast<Map<String, dynamic>>();
      settings = await api.adminSettings();
      users = (await api.adminDrivers()).cast<Map<String, dynamic>>();
      _applyPaymentSettings(
        (settings['payment'] as Map?)?.cast<String, dynamic>() ?? {},
      );
      if (role == UserRole.superAdmin) {
        users = (await api.adminUsers()).cast<Map<String, dynamic>>();
        auditRecords = (await api.auditLogs()).cast<Map<String, dynamic>>();
      }
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void setRole(UserRole next) {
    role = next;
    notifyListeners();
  }

  void setCategory(String value) {
    selectedCategory = value;
    notifyListeners();
  }

  void setSearch(String value) {
    searchQuery = value.trim();
    notifyListeners();
  }

  void addToCart(Product product) {
    if (product.stock <= (_cart[product.id] ?? 0)) return;
    _cart[product.id] = (_cart[product.id] ?? 0) + 1;
    notifyListeners();
  }

  void changeQuantity(Product product, int delta) {
    final quantity = (_cart[product.id] ?? 0) + delta;
    if (quantity <= 0) {
      _cart.remove(product.id);
    } else if (quantity <= product.stock) {
      _cart[product.id] = quantity;
    }
    notifyListeners();
  }

  void clearCart() {
    _cart.clear();
    notifyListeners();
  }

  Future<void> saveProduct(Map<String, dynamic> data, {String? id}) async {
    await api.saveProduct(data, id: id);
    await refreshAdmin();
  }

  Future<void> adjustStock(String id, int delta, String reason) async {
    await api.adjustInventory(id, delta, reason);
    await refreshAdmin();
  }

  Future<void> saveCategory(Map<String, dynamic> data, {String? id}) async {
    await api.saveCategory(data, id: id);
    await refreshAdmin();
  }

  Future<void> setUserRole(String id, String value) async {
    await api.updateUserRole(id, value);
    await refreshAdmin();
  }

  Future<void> setUserStatus(String id, bool active) async {
    await api.updateUserStatus(id, active);
    await refreshAdmin();
  }

  Future<void> assignDriver(String orderId, String driverId) async {
    await api.assignDriver(orderId, driverId);
    await refreshAdmin();
  }

  Future<void> changeOrderStatus(String id, String status) async {
    await api.updateOrderStatus(id, status);
    await refreshAdmin();
  }

  Future<void> changeDeliveryStatus(
    String id,
    String status, {
    String? notes,
  }) async {
    await api.updateDelivery(id, status, notes: notes);
    if (role == UserRole.driver)
      await loadRoleData();
    else
      await refreshAdmin();
  }

  Future<void> reviewManualPayment(
    String id,
    bool approved, {
    String? note,
  }) async {
    await api.reviewManualPayment(id, approved, note: note);
    await refreshAdmin();
  }

  Future<void> reconcilePayments() async {
    await api.reconcilePayments();
    await refreshAdmin();
  }

  Future<void> updatePaymentSettings(
    String number,
    int fee,
    int threshold,
    String mode,
  ) async {
    await api.updatePaymentSettings(number, fee, threshold, mode);
    await refreshAdmin();
  }

  Future<void> updateStoreSettings(
    String name,
    String phone,
    String email,
  ) async {
    await api.updateStoreSettings(name, phone, email);
    await refreshAdmin();
  }

  Future<Map<String, dynamic>> submitOrder({
    required String address,
    required String phone,
    double? latitude,
    double? longitude,
  }) => api.createOrder(
    items: cartItems.entries
        .map((item) => {'productId': item.key.id, 'quantity': item.value})
        .toList(),
    address: address,
    phone: phone,
    latitude: latitude,
    longitude: longitude,
  );

  void _applyPaymentSettings(Map<String, dynamic> value) {
    paymentNumber = value['momoNumber']?.toString() ?? paymentNumber;
    paymentMode = value['paymentMode']?.toString() ?? paymentMode;
    configuredDeliveryFeeRwf =
        ((value['deliveryFeeRwf'] ?? configuredDeliveryFeeRwf) as num).toInt();
    freeDeliveryThresholdRwf =
        ((value['freeDeliveryThresholdRwf'] ?? freeDeliveryThresholdRwf) as num)
            .toInt();
  }
}

String formatRwf(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
    buffer.write(digits[index]);
  }
  return '${buffer.toString()} RWF';
}
