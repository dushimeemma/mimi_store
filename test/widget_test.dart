import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mimi_store/models/product.dart';
import 'package:mimi_store/state/theme_controller.dart';

void main() {
  test('product maps Cloudinary media metadata', () {
    final product = Product.fromJson({
      'id': 'product-1',
      'name': 'Kigali Jacket',
      'category': 'Outerwear',
      'priceRwf': 45000,
      'stock': 8,
      'imageUrl': 'https://res.cloudinary.com/demo/image/upload/jacket.jpg',
      'imagePublicId': 'mimi-store/products/jacket',
    });

    expect(product.imageUrl, contains('cloudinary.com'));
    expect(product.imagePublicId, 'mimi-store/products/jacket');
  });

  test('theme follows the system until the customer chooses a mode', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = ThemeController();
    await controller.restore();
    expect(controller.mode, ThemeMode.system);

    await controller.setMode(ThemeMode.dark);
    expect(controller.mode, ThemeMode.dark);

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('theme_mode'), 'dark');
  });
}
