import 'package:flutter/material.dart';

import '../state/store_controller.dart';
import '../state/auth_controller.dart';
import 'checkout_sheet.dart';

class CartSheet extends StatelessWidget {
  const CartSheet({super.key, required this.store, required this.auth});
  final StoreController store;
  final AuthController auth;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: AnimatedBuilder(
          animation: store,
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Text(
                    'Your bag',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontFamily: 'serif',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Chip(label: Text('${store.cartCount} items')),
                ],
              ),
              const SizedBox(height: 10),
              if (store.cartItems.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Column(
                    children: [
                      Icon(
                        Icons.shopping_bag_outlined,
                        size: 48,
                        color: Colors.black26,
                      ),
                      SizedBox(height: 14),
                      Text(
                        'Your bag is empty',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: store.cartItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = store.cartItems.entries.elementAt(index);
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F4EC),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 62,
                              height: 72,
                              decoration: BoxDecoration(
                                color: item.key.color,
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.key.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    formatRwf(item.key.priceRwf),
                                    style: const TextStyle(
                                      color: Color(0xFF164580),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      IconButton.filledTonal(
                                        onPressed: () =>
                                            store.changeQuantity(item.key, -1),
                                        icon: const Icon(
                                          Icons.remove,
                                          size: 16,
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                        ),
                                        child: Text('${item.value}'),
                                      ),
                                      IconButton.filledTonal(
                                        onPressed: () =>
                                            store.changeQuantity(item.key, 1),
                                        icon: const Icon(Icons.add, size: 16),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Text('Subtotal'),
                    const Spacer(),
                    Text(
                      formatRwf(store.subtotalRwf),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Text(
                      'Delivery',
                      style: TextStyle(color: Colors.black54),
                    ),
                    const Spacer(),
                    Text(
                      formatRwf(store.deliveryRwf),
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(context);
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        useSafeArea: true,
                        builder: (_) => CheckoutSheet(store: store, auth: auth),
                      );
                    },
                    child: Text('Checkout · ${formatRwf(store.totalRwf)}'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
