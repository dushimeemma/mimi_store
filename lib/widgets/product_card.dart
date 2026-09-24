import 'package:flutter/material.dart';

import '../models/product.dart';
import '../state/store_controller.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product, required this.onAdd});
  final Product product;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: product.color),
                  ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      product.color.withOpacity(.28),
                      BlendMode.color,
                    ),
                    child: product.imageUrl == null
                        ? Image.asset(
                            'assets/images/mimi_hero.png',
                            fit: BoxFit.cover,
                          )
                        : Image.network(
                            product.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Image.asset(
                              'assets/images/mimi_hero.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                  ),
                  if (product.badge != null)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Chip(
                        label: Text(product.badge!),
                        backgroundColor: const Color(0xFFF8F4EC),
                        side: BorderSide.none,
                      ),
                    ),
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: FloatingActionButton.small(
                      heroTag: 'add-${product.id}',
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      foregroundColor: Colors.black,
                      onPressed: product.stock > 0 ? onAdd : null,
                      child: Icon(product.stock > 0 ? Icons.add : Icons.block),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.category,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    formatRwf(product.priceRwf),
                    style: const TextStyle(
                      color: Color(0xFF164580),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (product.stock <= 0)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'Out of stock',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
