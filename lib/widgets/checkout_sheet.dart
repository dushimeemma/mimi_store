import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../state/auth_controller.dart';
import '../state/store_controller.dart';

class CheckoutSheet extends StatefulWidget {
  const CheckoutSheet({super.key, required this.store, required this.auth});
  final StoreController store;
  final AuthController auth;

  @override
  State<CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<CheckoutSheet> {
  final email = TextEditingController();
  final phone = TextEditingController();
  final location = TextEditingController();
  bool complete = false;
  bool busy = false;
  bool paymentNoticeSent = false;
  String? error;
  String? orderId;
  String? orderNumber;
  String? paymentStatus;
  String? paymentNumber;
  int amountToPay = 0;
  double? latitude, longitude;

  bool get _isMobileDevice => !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  String get _localPaymentNumber {
    final digits = (paymentNumber ?? widget.store.paymentNumber)
        .replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('250') && digits.length > 3) {
      return '0${digits.substring(3)}';
    }
    if (digits.startsWith('7')) return '0$digits';
    return digits;
  }

  String get _ussdCode => '*182*1*1*$_localPaymentNumber*$amountToPay#';

  @override
  void dispose() {
    email.dispose();
    phone.dispose();
    location.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (complete) return _paymentStep();
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Checkout', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontFamily: 'serif', fontWeight: FontWeight.w700)),
        const SizedBox(height: 22),
        TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email address', hintText: 'you@example.com')),
        const SizedBox(height: 14),
        TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Mobile number', hintText: '+250 7•• ••• •••')),
        const SizedBox(height: 14),
        TextField(controller: location, decoration: InputDecoration(labelText: 'Delivery location', hintText: 'Street, neighbourhood, landmark', suffixIcon: IconButton(tooltip: 'Use my location', onPressed: _useLocation, icon: const Icon(Icons.my_location)))),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFFEEF4FA), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0x33164580))),
          child: Row(children: [const CircleAvatar(backgroundColor: Color(0xFFEFC357), child: Text('MoMo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900))), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Pay with Mobile Money', style: TextStyle(fontWeight: FontWeight.w800)), Text('Send ${formatRwf(widget.store.totalRwf)} to ${widget.store.paymentNumber}')]))]),
        ),
        const SizedBox(height: 18),
        Row(children: [const Text('Total', style: TextStyle(fontSize: 18)), const Spacer(), Text(formatRwf(widget.store.totalRwf), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))]),
        if (error != null) ...[const SizedBox(height: 12), Text(error!, style: const TextStyle(color: Colors.red))],
        const SizedBox(height: 18),
        SizedBox(width: double.infinity, height: 52, child: FilledButton(onPressed: busy ? null : _submit, child: busy ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Confirm order & payment'))),
      ]),
    );
  }

  Widget _paymentStep() => SingleChildScrollView(
    padding: EdgeInsets.only(left: 28, right: 28, top: 28, bottom: MediaQuery.viewInsetsOf(context).bottom + 28),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const CircleAvatar(radius: 34, backgroundColor: Color(0xFFE6F2DF), child: Icon(Icons.check, color: Color(0xFF2E681D), size: 34)),
      const SizedBox(height: 16),
      const Text('Order received', style: TextStyle(fontFamily: 'serif', fontSize: 30, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Text('Order ${orderNumber ?? ''} was created.', textAlign: TextAlign.center),
      const SizedBox(height: 18),
      if (paymentStatus == 'manual') ...[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: const Color(0xFFFFF4CF), borderRadius: BorderRadius.circular(18)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Complete your MTN MoMo payment', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text('Recipient: $_localPaymentNumber'),
            Text('Amount: ${formatRwf(amountToPay)}'),
            const SizedBox(height: 8),
            SelectableText(_ussdCode, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700)),
          ]),
        ),
        const SizedBox(height: 14),
        SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: busy ? null : _openUssd, icon: const Icon(Icons.dialpad), label: Text(_isMobileDevice ? 'Pay with this phone' : 'Show phone payment steps'))),
        const SizedBox(height: 8),
        SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: busy || paymentNoticeSent ? null : _notifyPaid, icon: Icon(paymentNoticeSent ? Icons.mark_email_read_outlined : Icons.notifications_active_outlined), label: Text(paymentNoticeSent ? 'Payment notification sent' : 'I have paid — notify admin'))),
        const SizedBox(height: 10),
        Text(paymentNoticeSent ? 'An administrator will verify the transaction and approve your order.' : 'Only notify the admin after Mobile Money confirms your transfer.', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.black54)),
      ] else ...[
        const Text('Approve the Mobile Money prompt on your phone. The order will update after the payment provider confirms it.', textAlign: TextAlign.center),
      ],
      if (error != null) ...[const SizedBox(height: 12), Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red))],
      const SizedBox(height: 20),
      TextButton(onPressed: () { widget.store.clearCart(); Navigator.pop(context); }, child: const Text('Continue shopping')),
    ]),
  );

  Future<void> _useLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) throw Exception('Location permission was not granted');
      final position = await Geolocator.getCurrentPosition();
      setState(() { latitude = position.latitude; longitude = position.longitude; location.text = 'Pinned location (${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)})'; });
    } catch (e) {
      setState(() => error = e.toString());
    }
  }

  Future<void> _submit() async {
    if (!widget.auth.authenticated) { setState(() => error = 'Please sign in before checkout.'); return; }
    if (location.text.trim().length < 3 || phone.text.trim().length < 8) { setState(() => error = 'Enter a valid delivery location and mobile number.'); return; }
    setState(() { busy = true; error = null; });
    try {
      amountToPay = widget.store.totalRwf;
      final order = await widget.store.submitOrder(address: location.text.trim(), phone: phone.text.trim(), latitude: latitude, longitude: longitude);
      final createdOrderId = order['id'] as String;
      final payment = await widget.store.api.initiatePayment(createdOrderId);
      if (!mounted) return;
      setState(() {
        orderId = createdOrderId;
        orderNumber = (order['order_number'] ?? order['orderNumber'] ?? '').toString();
        paymentStatus = payment['status']?.toString();
        paymentNumber = payment['momoNumber']?.toString() ?? widget.store.paymentNumber;
        complete = true;
      });
      if (paymentStatus == 'manual' && !_isMobileDevice) {
        WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _showPhoneInstructions(); });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _openUssd() async {
    if (!_isMobileDevice) { await _showPhoneInstructions(); return; }
    setState(() { busy = true; error = null; });
    try {
      final opened = await launchUrl(Uri(scheme: 'tel', path: _ussdCode), mode: LaunchMode.externalApplication);
      if (!opened && mounted) await _showPhoneInstructions();
    } catch (_) {
      if (mounted) await _showPhoneInstructions();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _showPhoneInstructions() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Pay using your mobile phone'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('This device could not open the MTN MoMo code. On a phone with an MTN SIM, dial:'),
          const SizedBox(height: 14),
          SelectableText(_ussdCode, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text('Send ${formatRwf(amountToPay)} to $_localPaymentNumber.'),
          const SizedBox(height: 8),
          const Text('After MTN confirms the transfer, tap “I have paid” so an admin can verify it.', style: TextStyle(fontSize: 12, color: Colors.black54)),
        ]),
        actions: [
          TextButton.icon(onPressed: () async { await Clipboard.setData(ClipboardData(text: _ussdCode)); if (dialogContext.mounted) ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('USSD code copied'))); }, icon: const Icon(Icons.copy), label: const Text('Copy code')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Done')),
        ],
      ),
    );
  }

  Future<void> _notifyPaid() async {
    final reference = TextEditingController();
    final note = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Notify admin of payment'),
        content: SizedBox(width: 430, child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Confirm only after MTN has completed the transfer. The admin will check the business MoMo account.'),
          const SizedBox(height: 14),
          TextField(controller: reference, decoration: const InputDecoration(labelText: 'Transaction reference (optional)')),
          const SizedBox(height: 12),
          TextField(controller: note, maxLines: 2, decoration: const InputDecoration(labelText: 'Note (optional)')),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Send notification')),
        ],
      ),
    );
    if (submitted != true || orderId == null) { reference.dispose(); note.dispose(); return; }
    setState(() { busy = true; error = null; });
    try {
      await widget.store.api.notifyManualPayment(orderId!, transactionReference: reference.text.trim(), note: note.text.trim());
      if (mounted) setState(() => paymentNoticeSent = true);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      reference.dispose(); note.dispose();
      if (mounted) setState(() => busy = false);
    }
  }
}
