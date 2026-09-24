import 'package:flutter/material.dart';

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.category,
    required this.priceRwf,
    required this.color,
    required this.stock,
    this.description = '',
    this.categoryId,
    this.sku,
    this.lowStockThreshold = 5,
    this.active = true,
    this.badge,
    this.imageUrl,
    this.imagePublicId,
  });

  final String id;
  final String name;
  final String category;
  final int priceRwf;
  final Color color;
  final int stock;
  final String description;
  final String? categoryId;
  final String? sku;
  final int lowStockThreshold;
  final bool active;
  final String? badge;
  final String? imageUrl;
  final String? imagePublicId;

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['id'] as String,
    name: json['name'] as String,
    category: json['category'] as String,
    priceRwf: (json['priceRwf'] as num).toInt(),
    color: const Color(0xFF164580),
    stock: (json['stock'] as num).toInt(),
    description: (json['description'] ?? '').toString(),
    categoryId: json['categoryId']?.toString(),
    sku: json['sku']?.toString(),
    lowStockThreshold: ((json['lowStockThreshold'] ?? 5) as num).toInt(),
    active: json['active'] as bool? ?? true,
    badge: json['badge'] as String?,
    imageUrl: json['imageUrl'] as String?,
    imagePublicId: json['imagePublicId'] as String?,
  );
}
