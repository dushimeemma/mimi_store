import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../state/auth_controller.dart';
import '../state/store_controller.dart';
import '../state/theme_controller.dart';
import '../widgets/account_menu.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({
    super.key,
    required this.store,
    required this.auth,
    required this.theme,
  });
  final StoreController store;
  final AuthController auth;
  final ThemeController theme;
  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  String filter = 'active';
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    appBar: AppBar(
      backgroundColor: Theme.of(context).colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DRIVER WORKSPACE',
            style: TextStyle(
              fontSize: 10,
              color: Colors.black45,
              letterSpacing: 1.3,
            ),
          ),
          Text(
            'My deliveries',
            style: TextStyle(fontFamily: 'serif', fontWeight: FontWeight.w700),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: widget.store.loadRoleData,
          icon: const Icon(Icons.refresh),
        ),
        AccountMenu(auth: widget.auth, theme: widget.theme),
        const SizedBox(width: 12),
      ],
    ),
    body: AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final records = widget.store.deliveryRecords
            .where(
              (d) =>
                  filter == 'all' ||
                  (filter == 'completed'
                      ? d['status'] == 'delivered'
                      : d['status'] != 'delivered'),
            )
            .toList();
        return Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${records.length} deliveries',
                        style: const TextStyle(
                          fontFamily: 'serif',
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      DropdownButton<String>(
                        value: filter,
                        items: const [
                          DropdownMenuItem(
                            value: 'active',
                            child: Text('Active'),
                          ),
                          DropdownMenuItem(
                            value: 'completed',
                            child: Text('Completed'),
                          ),
                          DropdownMenuItem(value: 'all', child: Text('All')),
                        ],
                        onChanged: (v) => setState(() => filter = v ?? filter),
                      ),
                    ],
                  ),
                  if (widget.store.error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        widget.store.error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  if (records.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(60),
                      child: Center(child: Text('No deliveries assigned.')),
                    )
                  else
                    ...records.map(
                      (d) => _DeliveryCard(store: widget.store, data: d),
                    ),
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
  );
}

class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({required this.store, required this.data});
  final StoreController store;
  final Map<String, dynamic> data;
  @override
  Widget build(BuildContext context) {
    final status = data['status']?.toString() ?? 'assigned';
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: status == 'delivered'
                      ? const Color(0xFFE4F3DE)
                      : const Color(0xFF102F58),
                  foregroundColor: status == 'delivered'
                      ? const Color(0xFF356526)
                      : Colors.white,
                  child: Icon(
                    status == 'delivered'
                        ? Icons.check
                        : Icons.local_shipping_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${data['orderNumber']} · ${data['customerName']}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        data['deliveryAddress']?.toString() ?? '',
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                Text(
                  formatRwf(((data['totalRwf'] ?? 0) as num).toInt()),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  avatar: const Icon(Icons.phone_outlined, size: 16),
                  label: Text(data['customerPhone']?.toString() ?? ''),
                ),
                Chip(label: Text(_label(status))),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _directions(data),
                    icon: const Icon(Icons.directions_outlined),
                    label: const Text('Directions'),
                  ),
                ),
                const SizedBox(width: 8),
                if (status != 'delivered')
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _advance(context, status),
                      child: Text(switch (status) {
                        'assigned' => 'Picked up',
                        'picked_up' => 'Start delivery',
                        'out_for_delivery' => 'Mark delivered',
                        _ => 'Update',
                      }),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _directions(Map<String, dynamic> value) async {
    final lat = value['latitude'], lng = value['longitude'];
    final query = lat != null && lng != null
        ? '$lat,$lng'
        : Uri.encodeComponent(value['deliveryAddress']?.toString() ?? '');
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$query',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _advance(BuildContext context, String current) async {
    final next = switch (current) {
      'assigned' => 'picked_up',
      'picked_up' => 'out_for_delivery',
      'out_for_delivery' => 'delivered',
      _ => 'out_for_delivery',
    };
    try {
      await store.changeDeliveryStatus(data['id'].toString(), next);
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delivery marked ${_label(next)}')),
        );
    } catch (e) {
      if (context.mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}

String _label(String value) => value
    .replaceAll('_', ' ')
    .split(' ')
    .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
    .join(' ');
