import 'package:flutter/material.dart';

import 'models/user_role.dart';
import 'screens/admin_dashboard.dart';
import 'screens/driver_dashboard.dart';
import 'screens/storefront_screen.dart';
import 'state/store_controller.dart';
import 'state/auth_controller.dart';
import 'services/api_client.dart';

class MimiStoreApp extends StatefulWidget {
  const MimiStoreApp({super.key});

  @override
  State<MimiStoreApp> createState() => _MimiStoreAppState();
}

class _MimiStoreAppState extends State<MimiStoreApp> {
  late final ApiClient api;
  late final StoreController store;
  late final AuthController auth;

  @override
  void initState() {
    super.initState();
    api=ApiClient(); store=StoreController(api); auth=AuthController(api,store);
    auth.restore(); store.initialize();
  }

  @override
  void dispose() { auth.dispose(); store.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mimi Store',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8F4EC),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF164580),
          primary: const Color(0xFF164580),
          secondary: const Color(0xFFEFC357),
          surface: Colors.white,
        ),
        fontFamily: 'sans-serif',
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFDED9CF))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFDED9CF))),
        ),
      ),
      home: AnimatedBuilder(
        animation: Listenable.merge([store,auth]),
        builder: (context, _) => switch (store.role) {
          UserRole.customer => StorefrontScreen(store: store, auth: auth),
          UserRole.driver => DriverDashboard(store: store, auth: auth),
          UserRole.admin || UserRole.superAdmin => AdminDashboard(store: store, auth: auth),
        },
      ),
    );
  }
}
