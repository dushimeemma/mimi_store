import 'package:flutter/material.dart';

import '../models/user_role.dart';
import '../services/api_client.dart';
import 'store_controller.dart';

class AuthController extends ChangeNotifier {
  AuthController(this.api, this.store);
  final ApiClient api;
  final StoreController store;
  Map<String, dynamic>? user;
  bool busy = false;
  String? error;
  bool get authenticated => user != null;

  Future<void> restore() async {
    try {
      await api.restoreSession();
      user = await api.storedUser();
      _applyRole();
      if (user != null) await store.loadRoleData();
    } catch (_) {
      user = null;
      store.setRole(UserRole.customer);
    }
    notifyListeners();
  }

  Future<bool> login(String email, String password) async =>
      _authenticate(() => api.login(email, password));
  Future<bool> register(
    String name,
    String email,
    String password,
    String phone,
  ) async => _authenticate(() => api.register(name, email, password, phone));
  Future<bool> _authenticate(
    Future<Map<String, dynamic>> Function() action,
  ) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      final response = await action();
      await api.saveSession(response);
      user = response['user'] as Map<String, dynamic>;
      _applyRole();
      await store.loadRoleData();
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await api.clearSession();
    user = null;
    store.setRole(UserRole.customer);
    notifyListeners();
  }

  void _applyRole() {
    final value = user?['role'] as String?;
    store.setRole(switch (value) {
      'super_admin' => UserRole.superAdmin,
      'admin' => UserRole.admin,
      'driver' => UserRole.driver,
      _ => UserRole.customer,
    });
  }
}
