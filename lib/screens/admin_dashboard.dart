import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

import '../models/product.dart';
import '../models/user_role.dart';
import '../state/auth_controller.dart';
import '../state/store_controller.dart';
import '../state/theme_controller.dart';
import '../widgets/account_menu.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({
    super.key,
    required this.store,
    required this.auth,
    required this.theme,
  });
  final StoreController store;
  final AuthController auth;
  final ThemeController theme;
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int selected = 0;
  List<(String, IconData)> get sections => [
    ('Overview', Icons.dashboard_outlined),
    ('Products', Icons.inventory_2_outlined),
    ('Categories', Icons.category_outlined),
    ('Orders', Icons.shopping_bag_outlined),
    if (widget.store.role == UserRole.superAdmin)
      ('Users', Icons.people_outline),
    ('Payments', Icons.payments_outlined),
    ('Deliveries', Icons.local_shipping_outlined),
    ('Settings', Icons.settings_outlined),
    if (widget.store.role == UserRole.superAdmin)
      ('Audit log', Icons.history_outlined),
  ];

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final desktop = constraints.maxWidth >= 980;
      final current = sections[selected.clamp(0, sections.length - 1)];
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.surface,
          surfaceTintColor: Colors.transparent,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MIMI STORE MANAGEMENT',
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  letterSpacing: 1.3,
                ),
              ),
              Text(
                current.$1,
                style: const TextStyle(
                  fontFamily: 'serif',
                  fontSize: 23,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: widget.store.loading
                  ? null
                  : widget.store.refreshAdmin,
              icon: const Icon(Icons.refresh),
            ),
            AccountMenu(auth: widget.auth, theme: widget.theme),
            const SizedBox(width: 10),
          ],
        ),
        drawer: desktop
            ? null
            : Drawer(
                child: SafeArea(
                  child: _Sidebar(
                    items: sections,
                    selected: selected,
                    onSelect: (value) {
                      setState(() => selected = value);
                      Navigator.pop(context);
                    },
                  ),
                ),
              ),
        body: Row(
          children: [
            if (desktop)
              SizedBox(
                width: 250,
                child: _Sidebar(
                  items: sections,
                  selected: selected,
                  onSelect: (value) => setState(() => selected = value),
                ),
              ),
            Expanded(
              child: AnimatedBuilder(
                animation: widget.store,
                builder: (context, _) {
                  return Stack(
                    children: [
                      SingleChildScrollView(
                        padding: EdgeInsets.all(desktop ? 28 : 16),
                        child: Column(
                          children: [
                            if (widget.store.error != null)
                              _ErrorBanner(message: widget.store.error!),
                            _page(selected),
                            const SizedBox(height: 50),
                          ],
                        ),
                      ),
                      if (widget.store.loading)
                        const Positioned(
                          left: 0,
                          right: 0,
                          top: 0,
                          child: LinearProgressIndicator(),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );

  Widget _page(int index) {
    final title = sections[index].$1;
    return switch (title) {
      'Overview' => _Overview(store: widget.store),
      'Products' => _ProductsPage(store: widget.store),
      'Categories' => _CategoriesPage(store: widget.store),
      'Orders' => _OrdersPage(store: widget.store),
      'Users' => _UsersPage(store: widget.store),
      'Payments' => _PaymentsPage(store: widget.store),
      'Deliveries' => _DeliveriesPage(store: widget.store),
      'Settings' => _SettingsPage(store: widget.store),
      'Audit log' => _AuditPage(store: widget.store),
      _ => const SizedBox(),
    };
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.items,
    required this.selected,
    required this.onSelect,
  });
  final List<(String, IconData)> items;
  final int selected;
  final ValueChanged<int> onSelect;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFF102F58),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(8),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Color(0xFFEFC357),
                  foregroundColor: Colors.black,
                  child: Text(
                    'M',
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  'mimi store',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'serif',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ...List.generate(
            items.length,
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: ListTile(
                selected: selected == i,
                selectedTileColor: Colors.white,
                selectedColor: const Color(0xFF102F58),
                textColor: Colors.white70,
                iconColor: Colors.white70,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                leading: Icon(items[i].$2),
                title: Text(items[i].$1),
                onTap: () => onSelect(i),
              ),
            ),
          ),
          const Spacer(),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Role-based operations console',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Overview extends StatelessWidget {
  const _Overview({required this.store});
  final StoreController store;
  @override
  Widget build(BuildContext context) {
    final m = store.metrics;
    final cards = [
      (
        'Today’s sales',
        formatRwf(((m['todaySalesRwf'] ?? 0) as num).toInt()),
        Icons.trending_up,
      ),
      ('Orders today', '${m['todayOrders'] ?? 0}', Icons.shopping_bag_outlined),
      ('Awaiting payment', '${m['awaitingPayment'] ?? 0}', Icons.schedule),
      (
        'Active products',
        '${m['activeProducts'] ?? 0}',
        Icons.inventory_2_outlined,
      ),
      ('Low stock', '${m['lowStockProducts'] ?? 0}', Icons.warning_amber),
      (
        'Active deliveries',
        '${m['activeDeliveries'] ?? 0}',
        Icons.local_shipping_outlined,
      ),
      (
        'Delivered today',
        '${m['deliveredToday'] ?? 0}',
        Icons.check_circle_outline,
      ),
      ('Active users', '${m['activeUsers'] ?? 0}', Icons.people_outline),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PageHeader(
          title: 'Store overview',
          subtitle: 'Live operational data from PostgreSQL',
          action: FilledButton.icon(
            onPressed: store.refreshAdmin,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ),
        LayoutBuilder(
          builder: (context, c) {
            final count = c.maxWidth > 1100
                ? 4
                : c.maxWidth > 620
                ? 2
                : 1;
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: count,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: count == 1 ? 3 : 1.7,
              children: cards
                  .map((x) => _MetricCard(title: x.$1, value: x.$2, icon: x.$3))
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 20),
        _Panel(
          title: 'Recent orders',
          child: _OrderList(
            store: store,
            orders: store.orders.take(8).toList(),
          ),
        ),
      ],
    );
  }
}

class _ProductsPage extends StatelessWidget {
  const _ProductsPage({required this.store});
  final StoreController store;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      _PageHeader(
        title: 'Products & inventory',
        subtitle: 'Manage catalogue details, prices, visibility and stock',
        action: FilledButton.icon(
          onPressed: () => showDialog(
            context: context,
            builder: (_) => _ProductDialog(store: store),
          ),
          icon: const Icon(Icons.add),
          label: const Text('Add product'),
        ),
      ),
      if (store.products.isEmpty)
        const _EmptyState(
          icon: Icons.inventory_2_outlined,
          text: 'No products found',
        )
      else
        LayoutBuilder(
          builder: (context, c) {
            final width = c.maxWidth > 1100
                ? (c.maxWidth - 32) / 3
                : c.maxWidth > 650
                ? (c.maxWidth - 16) / 2
                : c.maxWidth;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: store.products
                  .map(
                    (p) => SizedBox(
                      width: width,
                      child: Card(
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  _ProductThumbnail(product: p),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        Text(
                                          '${p.category} · ${p.sku ?? 'No SKU'}',
                                          style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _StatusChip(
                                    text: p.active ? 'Active' : 'Hidden',
                                    good: p.active,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                formatRwf(p.priceRwf),
                                style: const TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                '${p.stock} in stock · alert at ${p.lowStockThreshold}',
                                style: TextStyle(
                                  color: p.stock <= p.lowStockThreshold
                                      ? Colors.red
                                      : Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => showDialog(
                                        context: context,
                                        builder: (_) => _InventoryDialog(
                                          store: store,
                                          product: p,
                                        ),
                                      ),
                                      icon: const Icon(Icons.swap_vert),
                                      label: const Text('Stock'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: FilledButton.tonalIcon(
                                      onPressed: () => showDialog(
                                        context: context,
                                        builder: (_) => _ProductDialog(
                                          store: store,
                                          product: p,
                                        ),
                                      ),
                                      icon: const Icon(Icons.edit_outlined),
                                      label: const Text('Edit'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
    ],
  );
}

class _ProductThumbnail extends StatelessWidget {
  const _ProductThumbnail({required this.product});
  final Product product;
  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Icon(Icons.checkroom),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox.square(
        dimension: 48,
        child: product.imageUrl?.isNotEmpty == true
            ? Image.network(
                product.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallback,
              )
            : fallback,
      ),
    );
  }
}

class _CategoriesPage extends StatelessWidget {
  const _CategoriesPage({required this.store});
  final StoreController store;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      _PageHeader(
        title: 'Categories',
        subtitle: 'Organize the catalogue without changing application code',
        action: FilledButton.icon(
          onPressed: () => showDialog(
            context: context,
            builder: (_) => _CategoryDialog(store: store),
          ),
          icon: const Icon(Icons.add),
          label: const Text('Add category'),
        ),
      ),
      _Panel(
        title: 'Catalogue categories',
        child: Column(
          children: store.categories
              .map(
                (c) => ListTile(
                  leading: CircleAvatar(
                    child: Text((c['name'] ?? '?').toString()[0]),
                  ),
                  title: Text(
                    c['name'].toString(),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${c['productCount'] ?? 0} products · /${c['slug']}',
                  ),
                  trailing: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _StatusChip(
                        text: c['active'] == true ? 'Active' : 'Hidden',
                        good: c['active'] == true,
                      ),
                      IconButton(
                        onPressed: () => showDialog(
                          context: context,
                          builder: (_) =>
                              _CategoryDialog(store: store, category: c),
                        ),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ),
    ],
  );
}

class _OrdersPage extends StatelessWidget {
  const _OrdersPage({required this.store});
  final StoreController store;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      _PageHeader(
        title: 'Orders',
        subtitle: 'Payment, fulfilment and cancellation lifecycle',
        action: OutlinedButton.icon(
          onPressed: store.refreshAdmin,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
        ),
      ),
      _Panel(
        title: 'All orders',
        child: _OrderList(store: store, orders: store.orders),
      ),
    ],
  );
}

class _OrderList extends StatelessWidget {
  const _OrderList({required this.store, required this.orders});
  final StoreController store;
  final List<Map<String, dynamic>> orders;
  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty)
      return const _EmptyState(
        icon: Icons.receipt_long_outlined,
        text: 'No orders yet',
      );
    return Column(
      children: orders
          .map(
            (o) => ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 8),
              leading: CircleAvatar(
                backgroundColor: const Color(0xFFEAF2FC),
                child: Text(
                  (o['orderNumber'] ?? 'MS').toString().split('-').last,
                ),
              ),
              title: Text(
                o['orderNumber']?.toString() ?? '',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                '${o['customerName'] ?? 'Customer'} · ${o['deliveryAddress'] ?? ''}',
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatRwf(((o['totalRwf'] ?? 0) as num).toInt()),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    _label(o['status']),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF164580),
                    ),
                  ),
                ],
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...((o['items'] as List?) ?? []).map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${item['quantity']} × ${item['name']}',
                                ),
                              ),
                              Text(
                                formatRwf(
                                  ((item['lineTotalRwf'] ?? 0) as num).toInt(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Divider(),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (o['status'] == 'payment_confirmed')
                            FilledButton.tonal(
                              onPressed: () => _run(
                                context,
                                () => store.changeOrderStatus(
                                  o['id'].toString(),
                                  'ready_for_pickup',
                                ),
                              ),
                              child: const Text('Ready for pickup'),
                            ),
                          if ([
                            'payment_confirmed',
                            'ready_for_pickup',
                            'assigned',
                          ].contains(o['status']))
                            OutlinedButton.icon(
                              onPressed: () => _assign(context, store, o),
                              icon: const Icon(Icons.local_shipping_outlined),
                              label: Text(
                                o['driverName'] == null
                                    ? 'Assign driver'
                                    : 'Reassign driver',
                              ),
                            ),
                          if (!['delivered', 'cancelled'].contains(o['status']))
                            TextButton(
                              onPressed: () => _run(
                                context,
                                () => store.changeOrderStatus(
                                  o['id'].toString(),
                                  'cancelled',
                                ),
                              ),
                              child: const Text(
                                'Cancel order',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
          .toList(),
    );
  }
}

class _UsersPage extends StatelessWidget {
  const _UsersPage({required this.store});
  final StoreController store;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      _PageHeader(
        title: 'Users & access',
        subtitle: 'Super Admin controls staff roles and account status',
        action: OutlinedButton.icon(
          onPressed: store.refreshAdmin,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
        ),
      ),
      _Panel(
        title: 'Accounts',
        child: Column(
          children: store.users
              .map(
                (u) => ListTile(
                  leading: CircleAvatar(
                    child: Text((u['fullName'] ?? '?').toString()[0]),
                  ),
                  title: Text(
                    u['fullName'].toString(),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text('${u['email']} · ${_label(u['role'])}'),
                  trailing: u['role'] == 'super_admin'
                      ? const _StatusChip(text: 'Owner', good: true)
                      : Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            DropdownButton<String>(
                              value: u['role'].toString(),
                              items: ['customer', 'admin', 'driver']
                                  .map(
                                    (r) => DropdownMenuItem(
                                      value: r,
                                      child: Text(_label(r)),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                if (v != null)
                                  _run(
                                    context,
                                    () => store.setUserRole(
                                      u['id'].toString(),
                                      v,
                                    ),
                                  );
                              },
                            ),
                            Switch(
                              value: u['isActive'] == true,
                              onChanged: (v) => _run(
                                context,
                                () =>
                                    store.setUserStatus(u['id'].toString(), v),
                              ),
                            ),
                          ],
                        ),
                ),
              )
              .toList(),
        ),
      ),
    ],
  );
}

class _PaymentsPage extends StatelessWidget {
  const _PaymentsPage({required this.store});
  final StoreController store;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      _PageHeader(
        title: 'Payments',
        subtitle:
            'Verify customer payment notifications before approving orders',
        action: FilledButton.icon(
          onPressed: () => _run(context, store.reconcilePayments),
          icon: const Icon(Icons.sync),
          label: const Text('Reconcile API payments'),
        ),
      ),
      _Panel(
        title: 'Payment ledger',
        child: store.payments.isEmpty
            ? const _EmptyState(
                icon: Icons.payments_outlined,
                text: 'No payments yet',
              )
            : Column(
                children: store.payments.map((p) {
                  final claimed = p['customerNotifiedAt'] != null;
                  final reviewable =
                      p['status'] == 'pending' &&
                      p['provider'] == 'manual_momo' &&
                      claimed;
                  final reference = p['customerReference']?.toString();
                  return Card(
                    elevation: 0,
                    color: claimed && p['status'] == 'pending'
                        ? const Color(0xFFFFF8E3)
                        : const Color(0xFFF8F9FB),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const CircleAvatar(
                            backgroundColor: Color(0xFFFFE59A),
                            child: Text(
                              'MoMo',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p['orderNumber'].toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  '${p['customerName']} · ${p['payerPhone']}',
                                ),
                                Text(
                                  '${_label(p['provider'])} · ${p['reference']}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                                if (claimed)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 7),
                                    child: Text(
                                      'Customer reported payment${reference?.isNotEmpty == true ? ' · Ref: $reference' : ''}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF7A5800),
                                      ),
                                    ),
                                  ),
                                if (p['customerNote']?.toString().isNotEmpty ==
                                    true)
                                  Text(
                                    'Note: ${p['customerNote']}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                formatRwf(
                                  ((p['amountRwf'] ?? 0) as num).toInt(),
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              _StatusChip(
                                text: claimed && p['status'] == 'pending'
                                    ? 'Awaiting review'
                                    : _label(p['status']),
                                good: p['status'] == 'successful',
                              ),
                              if (reviewable)
                                Wrap(
                                  spacing: 4,
                                  children: [
                                    TextButton(
                                      onPressed: () => _reviewPayment(
                                        context,
                                        store,
                                        p,
                                        false,
                                      ),
                                      child: const Text(
                                        'Reject',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                    FilledButton.tonal(
                                      onPressed: () => _reviewPayment(
                                        context,
                                        store,
                                        p,
                                        true,
                                      ),
                                      child: const Text('Approve'),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
      ),
    ],
  );
}

Future<void> _reviewPayment(
  BuildContext context,
  StoreController store,
  Map<String, dynamic> payment,
  bool approved,
) async {
  final note = TextEditingController();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(approved ? 'Approve payment' : 'Reject payment'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              approved
                  ? 'Confirm that ${formatRwf(((payment['amountRwf'] ?? 0) as num).toInt())} is visible in the business Mobile Money account.'
                  : 'Reject this notification if the payment is missing or does not match.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: note,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: approved
                    ? 'Review note (optional)'
                    : 'Reason (recommended)',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(approved ? 'Approve order' : 'Reject notification'),
        ),
      ],
    ),
  );
  if (confirmed == true && context.mounted)
    await _run(
      context,
      () => store.reviewManualPayment(
        payment['id'].toString(),
        approved,
        note: note.text.trim(),
      ),
    );
  note.dispose();
}

class _DeliveriesPage extends StatelessWidget {
  const _DeliveriesPage({required this.store});
  final StoreController store;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      _PageHeader(
        title: 'Deliveries',
        subtitle: 'Assign drivers and monitor fulfilment',
        action: OutlinedButton.icon(
          onPressed: store.refreshAdmin,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
        ),
      ),
      _Panel(
        title: 'Delivery board',
        child: store.deliveryRecords.isEmpty
            ? const _EmptyState(
                icon: Icons.local_shipping_outlined,
                text: 'No delivery records',
              )
            : Column(
                children: store.deliveryRecords
                    .map(
                      (d) => ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.local_shipping_outlined),
                        ),
                        title: Text(
                          '${d['orderNumber']} · ${d['customerName']}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${d['deliveryAddress']}\nDriver: ${d['driverName'] ?? 'Unassigned'}',
                        ),
                        isThreeLine: true,
                        trailing: PopupMenuButton<String>(
                          initialValue: d['status']?.toString(),
                          onSelected: (v) => _run(
                            context,
                            () => store.changeDeliveryStatus(
                              d['id'].toString(),
                              v,
                            ),
                          ),
                          itemBuilder: (_) =>
                              [
                                    'assigned',
                                    'picked_up',
                                    'out_for_delivery',
                                    'delivered',
                                    'failed',
                                  ]
                                  .map(
                                    (s) => PopupMenuItem(
                                      value: s,
                                      child: Text(_label(s)),
                                    ),
                                  )
                                  .toList(),
                          child: _StatusChip(
                            text: _label(d['status']),
                            good: d['status'] == 'delivered',
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
      ),
    ],
  );
}

class _SettingsPage extends StatefulWidget {
  const _SettingsPage({required this.store});
  final StoreController store;
  @override
  State<_SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<_SettingsPage> {
  late final TextEditingController fee, threshold, name, email;
  late String mode, momoNumber, supportPhone;
  @override
  void initState() {
    super.initState();
    final s = (widget.store.settings['store'] as Map?) ?? {};
    momoNumber = widget.store.paymentNumber;
    supportPhone = (s['supportPhone'] ?? widget.store.paymentNumber).toString();
    fee = TextEditingController(
      text: '${widget.store.configuredDeliveryFeeRwf}',
    );
    threshold = TextEditingController(
      text: '${widget.store.freeDeliveryThresholdRwf}',
    );
    mode = widget.store.paymentMode;
    name = TextEditingController(
      text: (s['storeName'] ?? 'Mimi Store').toString(),
    );
    email = TextEditingController(
      text: (s['supportEmail'] ?? 'support@mimistore.rw').toString(),
    );
  }

  @override
  void dispose() {
    for (final c in [fee, threshold, name, email]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const _PageHeader(
        title: 'Store settings',
        subtitle: 'Public business information, checkout and delivery rules',
      ),
      LayoutBuilder(
        builder: (context, c) {
          final payment = _Panel(
            title: 'Payment & delivery',
            child: Column(
              children: [
                IntlPhoneField(
                  initialCountryCode: 'RW',
                  initialValue: _national(momoNumber),
                  decoration: const InputDecoration(
                    labelText: 'Mobile Money number',
                  ),
                  onChanged: (value) => momoNumber = value.completeNumber,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: mode,
                  decoration: const InputDecoration(labelText: 'Payment mode'),
                  items: const [
                    DropdownMenuItem(
                      value: 'manual',
                      child: Text('Manual confirmation'),
                    ),
                    DropdownMenuItem(
                      value: 'momo_api',
                      child: Text('MTN MoMo API'),
                    ),
                  ],
                  onChanged: (v) => setState(() => mode = v ?? mode),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: fee,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Delivery fee (RWF)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: threshold,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Free delivery threshold (RWF)',
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: widget.store.role != UserRole.superAdmin
                        ? null
                        : () => _run(
                            context,
                            () => widget.store.updatePaymentSettings(
                              momoNumber,
                              int.tryParse(fee.text) ?? 0,
                              int.tryParse(threshold.text) ?? 0,
                              mode,
                            ),
                          ),
                    child: const Text('Save checkout settings'),
                  ),
                ),
              ],
            ),
          );
          final business = _Panel(
            title: 'Business details',
            child: Column(
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Store name'),
                ),
                const SizedBox(height: 12),
                IntlPhoneField(
                  initialCountryCode: 'RW',
                  initialValue: _national(supportPhone),
                  decoration: const InputDecoration(labelText: 'Support phone'),
                  onChanged: (value) => supportPhone = value.completeNumber,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: email,
                  decoration: const InputDecoration(labelText: 'Support email'),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    onPressed: widget.store.role != UserRole.superAdmin
                        ? null
                        : () => _run(
                            context,
                            () => widget.store.updateStoreSettings(
                              name.text,
                              supportPhone,
                              email.text,
                            ),
                          ),
                    child: const Text('Save business details'),
                  ),
                ),
              ],
            ),
          );
          return c.maxWidth > 850
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: payment),
                    const SizedBox(width: 16),
                    Expanded(child: business),
                  ],
                )
              : Column(
                  children: [payment, const SizedBox(height: 16), business],
                );
        },
      ),
    ],
  );
  String _national(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('250')) return digits.substring(3);
    if (digits.startsWith('0')) return digits.substring(1);
    return digits;
  }
}

class _AuditPage extends StatelessWidget {
  const _AuditPage({required this.store});
  final StoreController store;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      const _PageHeader(
        title: 'Audit history',
        subtitle: 'Trace sensitive administrative changes',
      ),
      _Panel(
        title: 'Latest activity',
        child: store.auditRecords.isEmpty
            ? const _EmptyState(
                icon: Icons.history,
                text: 'No activity recorded',
              )
            : Column(
                children: store.auditRecords
                    .map(
                      (a) => ListTile(
                        leading: const Icon(Icons.history),
                        title: Text(
                          _label(a['action']),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${a['actorName'] ?? 'System'} · ${a['entityType']} · ${a['createdAt']}',
                        ),
                      ),
                    )
                    .toList(),
              ),
      ),
    ],
  );
}

class _ProductDialog extends StatefulWidget {
  const _ProductDialog({required this.store, this.product});
  final StoreController store;
  final Product? product;
  @override
  State<_ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<_ProductDialog> {
  late final TextEditingController name,
      sku,
      description,
      price,
      stock,
      badge,
      low;
  String? categoryId, selectedImageName, selectedImageMime;
  Uint8List? selectedImageBytes;
  bool active = true, busy = false;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    name = TextEditingController(text: p?.name);
    sku = TextEditingController(text: p?.sku);
    description = TextEditingController(text: p?.description);
    price = TextEditingController(text: p == null ? '' : '${p.priceRwf}');
    stock = TextEditingController(text: p == null ? '0' : '${p.stock}');
    badge = TextEditingController(text: p?.badge);
    low = TextEditingController(text: '${p?.lowStockThreshold ?? 5}');
    categoryId =
        p?.categoryId ??
        (widget.store.categories.isEmpty
            ? null
            : widget.store.categories.first['id']?.toString());
    active = p?.active ?? true;
  }

  @override
  void dispose() {
    for (final c in [name, sku, description, price, stock, badge, low]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.product == null ? 'Add product' : 'Edit product'),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Column(
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Product name'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: categoryId,
              decoration: const InputDecoration(labelText: 'Category'),
              items: widget.store.categories
                  .where((c) => c['active'] == true)
                  .map(
                    (c) => DropdownMenuItem(
                      value: c['id'].toString(),
                      child: Text(c['name'].toString()),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => categoryId = v),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: price,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Price (RWF)'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: stock,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Stock'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: sku,
                    decoration: const InputDecoration(labelText: 'SKU'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: low,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Low stock alert',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: description,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 12),
            _imagePreview(),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: busy ? null : _pickImage,
                icon: const Icon(Icons.cloud_upload_outlined),
                label: Text(
                  widget.product?.imageUrl == null && selectedImageBytes == null
                      ? 'Upload product image'
                      : 'Change product image',
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'JPG, PNG or WebP · maximum 8 MB',
                style: TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: badge,
              decoration: const InputDecoration(labelText: 'Badge (optional)'),
            ),
            SwitchListTile(
              value: active,
              onChanged: (v) => setState(() => active = v),
              title: const Text('Visible in storefront'),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: busy ? null : _save,
        child: Text(busy ? 'Saving…' : 'Save'),
      ),
    ],
  );

  Widget _imagePreview() {
    final child = selectedImageBytes != null
        ? Image.memory(selectedImageBytes!, fit: BoxFit.cover)
        : widget.product?.imageUrl != null
        ? Image.network(
            widget.product!.imageUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Center(
              child: Icon(Icons.broken_image_outlined, size: 42),
            ),
          )
        : const Center(child: Icon(Icons.image_outlined, size: 42));
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: child,
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
      maxWidth: 1800,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (bytes.length > 8 * 1024 * 1024) {
      if (mounted) _toast(context, 'Product image must be 8 MB or smaller');
      return;
    }
    if (mounted)
      setState(() {
        selectedImageBytes = bytes;
        selectedImageName = picked.name;
        selectedImageMime = picked.mimeType;
      });
  }

  Future<void> _save() async {
    final category = widget.store.categories
        .where((c) => c['id'].toString() == categoryId)
        .firstOrNull;
    if (name.text.trim().length < 2 ||
        category == null ||
        int.tryParse(price.text) == null) {
      _toast(context, 'Complete the required product fields');
      return;
    }
    setState(() => busy = true);
    String? uploadedPublicId;
    try {
      String? imageUrl = widget.product?.imageUrl;
      String? imagePublicId = widget.product?.imagePublicId;
      if (selectedImageBytes != null) {
        final upload = await widget.store.api.uploadProductImage(
          selectedImageBytes!,
          selectedImageName ?? 'product.jpg',
          selectedImageMime,
        );
        imageUrl = upload['imageUrl']?.toString();
        imagePublicId = upload['imagePublicId']?.toString();
        uploadedPublicId = imagePublicId;
      }
      await widget.store.saveProduct({
        'name': name.text.trim(),
        'category': category['name'],
        'categoryId': categoryId,
        'description': description.text.trim(),
        'priceRwf': int.parse(price.text),
        'stock': int.tryParse(stock.text) ?? 0,
        'lowStockThreshold': int.tryParse(low.text) ?? 5,
        'active': active,
        if (sku.text.trim().isNotEmpty) 'sku': sku.text.trim(),
        if (imageUrl?.isNotEmpty == true) 'imageUrl': imageUrl,
        if (imagePublicId?.isNotEmpty == true) 'imagePublicId': imagePublicId,
        if (badge.text.trim().isNotEmpty) 'badge': badge.text.trim(),
      }, id: widget.product?.id);
      uploadedPublicId = null;
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (uploadedPublicId != null) {
        try {
          await widget.store.api.deleteProductImage(uploadedPublicId);
        } catch (_) {}
      }
      if (mounted) _toast(context, e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

class _InventoryDialog extends StatefulWidget {
  const _InventoryDialog({required this.store, required this.product});
  final StoreController store;
  final Product product;
  @override
  State<_InventoryDialog> createState() => _InventoryDialogState();
}

class _InventoryDialogState extends State<_InventoryDialog> {
  final quantity = TextEditingController(), reason = TextEditingController();
  bool busy = false;
  @override
  void dispose() {
    quantity.dispose();
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Adjust ${widget.product.name}'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Current stock: ${widget.product.stock}'),
        const SizedBox(height: 12),
        TextField(
          controller: quantity,
          keyboardType: const TextInputType.numberWithOptions(signed: true),
          decoration: const InputDecoration(
            labelText: 'Quantity change',
            hintText: 'Example: 10 or -2',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: reason,
          decoration: const InputDecoration(labelText: 'Reason'),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: busy
            ? null
            : () async {
                final delta = int.tryParse(quantity.text);
                if (delta == null ||
                    delta == 0 ||
                    reason.text.trim().length < 3) {
                  _toast(context, 'Enter a non-zero quantity and reason');
                  return;
                }
                setState(() => busy = true);
                try {
                  await widget.store.adjustStock(
                    widget.product.id,
                    delta,
                    reason.text.trim(),
                  );
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) _toast(context, e.toString());
                }
              },
        child: const Text('Apply'),
      ),
    ],
  );
}

class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog({required this.store, this.category});
  final StoreController store;
  final Map<String, dynamic>? category;
  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  late final TextEditingController name, description, sort;
  bool active = true, busy = false;
  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.category?['name']?.toString());
    description = TextEditingController(
      text: widget.category?['description']?.toString(),
    );
    sort = TextEditingController(text: '${widget.category?['sortOrder'] ?? 0}');
    active = widget.category?['active'] as bool? ?? true;
  }

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    sort.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.category == null ? 'Add category' : 'Edit category'),
    content: SizedBox(
      width: 440,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Category name'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: description,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: sort,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Sort order'),
          ),
          SwitchListTile(
            value: active,
            onChanged: (v) => setState(() => active = v),
            title: const Text('Active'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: busy
            ? null
            : () async {
                setState(() => busy = true);
                try {
                  await widget.store.saveCategory({
                    'name': name.text.trim(),
                    'description': description.text.trim(),
                    'sortOrder': int.tryParse(sort.text) ?? 0,
                    'active': active,
                  }, id: widget.category?['id']?.toString());
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) _toast(context, e.toString());
                }
              },
        child: const Text('Save'),
      ),
    ],
  );
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.title, required this.subtitle, this.action});
  final String title, subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'serif',
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(subtitle, style: const TextStyle(color: Colors.black54)),
            ],
          ),
        ),
        if (action != null) action!,
      ],
    ),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'serif',
              fontSize: 21,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    ),
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
  });
  final String title, value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: const TextStyle(color: Colors.black54)),
              const Spacer(),
              CircleAvatar(
                backgroundColor: const Color(0xFFEAF2FC),
                child: Icon(icon, color: const Color(0xFF164580), size: 19),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    ),
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.text, required this.good});
  final String text;
  final bool good;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: good ? const Color(0xFFE5F4DF) : const Color(0xFFFFECE7),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: good ? const Color(0xFF356526) : const Color(0xFFA43E28),
      ),
    ),
  );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFFECE7),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline, color: Colors.red),
        const SizedBox(width: 10),
        Expanded(child: Text(message)),
      ],
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(34),
    child: Center(
      child: Column(
        children: [
          Icon(icon, size: 44, color: Colors.black26),
          const SizedBox(height: 10),
          Text(text, style: const TextStyle(color: Colors.black54)),
        ],
      ),
    ),
  );
}

Future<void> _run(BuildContext context, Future<void> Function() action) async {
  try {
    await action();
    if (context.mounted) _toast(context, 'Saved successfully');
  } catch (e) {
    if (context.mounted) _toast(context, e.toString());
  }
}

Future<void> _assign(
  BuildContext context,
  StoreController store,
  Map<String, dynamic> order,
) async {
  String? selected =
      order['driverId']?.toString() ??
      (store.drivers.isEmpty ? null : store.drivers.first['id'].toString());
  await showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text('Assign ${order['orderNumber']}'),
        content: DropdownButtonFormField<String>(
          value: selected,
          decoration: const InputDecoration(labelText: 'Motor driver'),
          items: store.drivers
              .map(
                (d) => DropdownMenuItem(
                  value: d['id'].toString(),
                  child: Text(d['fullName'].toString()),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => selected = v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: selected == null
                ? null
                : () async {
                    try {
                      await store.assignDriver(
                        order['id'].toString(),
                        selected!,
                      );
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      if (context.mounted) _toast(context, e.toString());
                    }
                  },
            child: const Text('Assign'),
          ),
        ],
      ),
    ),
  );
}

void _toast(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
String _label(dynamic value) =>
    value
        ?.toString()
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (word) =>
              word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1),
        )
        .join(' ') ??
    '';

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
