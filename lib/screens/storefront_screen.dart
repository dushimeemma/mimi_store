import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

import '../state/auth_controller.dart';
import '../state/store_controller.dart';
import '../state/theme_controller.dart';
import '../widgets/cart_sheet.dart';
import '../widgets/product_card.dart';
import '../widgets/account_menu.dart';
import '../widgets/theme_selector.dart';

class StorefrontScreen extends StatelessWidget {
  const StorefrontScreen({
    super.key,
    required this.store,
    required this.auth,
    required this.theme,
  });
  final StoreController store;
  final AuthController auth;
  final ThemeController theme;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 72,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              backgroundColor: Color(0xFF164580),
              foregroundColor: Colors.white,
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
                fontFamily: 'serif',
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Search products',
            onPressed: () => _showSearch(context),
            icon: const Icon(Icons.search),
          ),
          if (auth.authenticated)
            AccountMenu(auth: auth, theme: theme)
          else ...[
            ThemeSelector(controller: theme),
            IconButton(
              tooltip: 'Sign in',
              onPressed: () => _showSignIn(context),
              icon: const Icon(Icons.account_circle_outlined),
            ),
          ],
          Badge(
            label: Text('${store.cartCount}'),
            isLabelVisible: store.cartCount > 0,
            child: IconButton(
              tooltip: 'Shopping bag',
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => CartSheet(store: store, auth: auth),
              ),
              icon: const Icon(Icons.shopping_bag_outlined),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AnimatedBuilder(
        animation: store,
        builder: (context, _) => CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _Hero(store: store)),
            SliverToBoxAdapter(child: _CategoryBar(store: store)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: SliverLayoutBuilder(
                builder: (context, constraints) {
                  final count = constraints.crossAxisExtent >= 1100
                      ? 4
                      : constraints.crossAxisExtent >= 650
                      ? 3
                      : 2;
                  return SliverGrid.builder(
                    itemCount: store.visibleProducts.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: count,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: .63,
                    ),
                    itemBuilder: (context, index) {
                      final product = store.visibleProducts[index];
                      return ProductCard(
                        product: product,
                        onAdd: () => store.addToCart(product),
                      );
                    },
                  );
                },
              ),
            ),
            if (store.visibleProducts.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(48),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.search_off,
                        size: 48,
                        color: Colors.black26,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        store.error ?? 'No products match your selection.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: _DeliveryBanner()),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  '© 2026 Mimi Store · Kigali, Rwanda',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSignIn(BuildContext context) => showDialog<void>(
    context: context,
    builder: (_) => _AuthDialog(auth: auth),
  );
  Future<void> _showSearch(BuildContext context) async {
    final controller = TextEditingController(text: store.searchQuery);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Search products'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Dress, shirt, set…'),
          onSubmitted: (value) {
            store.setSearch(value);
            Navigator.pop(dialogContext);
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              store.setSearch('');
              Navigator.pop(dialogContext);
            },
            child: const Text('Clear'),
          ),
          FilledButton(
            onPressed: () {
              store.setSearch(controller.text);
              Navigator.pop(dialogContext);
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
    controller.dispose();
  }
}

class _AuthDialog extends StatefulWidget {
  const _AuthDialog({required this.auth});
  final AuthController auth;
  @override
  State<_AuthDialog> createState() => _AuthDialogState();
}

class _AuthDialogState extends State<_AuthDialog> {
  final name = TextEditingController(),
      email = TextEditingController(),
      password = TextEditingController();
  String phone = '';
  bool register = false;
  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      register ? 'Create account' : 'Welcome back',
      style: const TextStyle(
        fontFamily: 'serif',
        fontSize: 28,
        fontWeight: FontWeight.w700,
      ),
    ),
    content: AnimatedBuilder(
      animation: widget.auth,
      builder: (context, _) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (register) ...[
                TextField(
                  controller: name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Full name'),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'Email address'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: password,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              if (register) ...[
                const SizedBox(height: 12),
                IntlPhoneField(
                  initialCountryCode: 'RW',
                  decoration: const InputDecoration(labelText: 'Mobile number'),
                  onChanged: (value) => phone = value.completeNumber,
                ),
              ],
              if (widget.auth.error != null) ...[
                const SizedBox(height: 10),
                Text(
                  widget.auth.error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: widget.auth.busy
            ? null
            : () => setState(() => register = !register),
        child: Text(register ? 'I already have an account' : 'Create account'),
      ),
      FilledButton(
        onPressed: widget.auth.busy
            ? null
            : () async {
                if (register && phone.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Enter a valid mobile number'),
                    ),
                  );
                  return;
                }
                final ok = register
                    ? await widget.auth.register(
                        name.text,
                        email.text,
                        password.text,
                        phone,
                      )
                    : await widget.auth.login(email.text, password.text);
                if (ok && context.mounted) Navigator.pop(context);
              },
        child: widget.auth.busy
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(register ? 'Register' : 'Sign in'),
      ),
    ],
  );
}

class _Hero extends StatelessWidget {
  const _Hero({required this.store});
  final StoreController store;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 34),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth > 820;
          final hero = Container(
            constraints: BoxConstraints(minHeight: wide ? 620 : 520),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              image: const DecorationImage(
                image: AssetImage('assets/images/mimi_hero.png'),
                fit: BoxFit.cover,
              ),
            ),
            child: Container(
              padding: EdgeInsets.all(wide ? 48 : 26),
              alignment: Alignment.bottomLeft,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xCC0B1E3C)],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Chip(
                    label: Text('The Atelier Edit · 2026'),
                    backgroundColor: Color(0x33FFFFFF),
                    labelStyle: TextStyle(color: Colors.white),
                    side: BorderSide(color: Color(0x55FFFFFF)),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Made to move\nwith you.',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'serif',
                      height: .9,
                      fontSize: wide ? 70 : 48,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Modern pieces designed in Kigali for the rhythm of every day.',
                    style: TextStyle(color: Colors.white, fontSize: 17),
                  ),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFEFC357),
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () {},
                    iconAlignment: IconAlignment.end,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Shop the edit'),
                  ),
                ],
              ),
            ),
          );
          if (!wide) return SizedBox(height: 520, child: hero);
          return SizedBox(
            height: 620,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 6, child: hero),
                const SizedBox(width: 18),
                Expanded(
                  flex: 4,
                  child: Column(
                    children: [
                      Expanded(
                        child: _FeatureBlock(
                          color: const Color(0xFFEFC357),
                          icon: Icons.auto_awesome,
                          eyebrow: 'DESIGNED LOCALLY',
                          title: 'Small runs.\nConsidered details.',
                          dark: true,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Expanded(
                        child: _FeatureBlock(
                          color: Color(0xFFC45537),
                          icon: Icons.new_releases_outlined,
                          eyebrow: 'NEW THIS WEEK',
                          title: '04\nFresh silhouettes.',
                          dark: false,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FeatureBlock extends StatelessWidget {
  const _FeatureBlock({
    required this.color,
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.dark,
  });
  final Color color;
  final IconData icon;
  final String eyebrow;
  final String title;
  final bool dark;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(30),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(32),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: dark ? Colors.black : Colors.white),
        const Spacer(),
        Text(
          eyebrow,
          style: TextStyle(
            color: dark ? Colors.black : Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: TextStyle(
            color: dark ? Colors.black : Colors.white,
            fontFamily: 'serif',
            fontSize: 34,
            height: .95,
          ),
        ),
      ],
    ),
  );
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({required this.store});
  final StoreController store;
  @override
  Widget build(BuildContext context) {
    final names = [
      'All',
      ...store.categories
          .where((item) => item['active'] != false)
          .map((item) => item['name'].toString()),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'FRESH FROM THE STUDIO',
            style: TextStyle(
              color: Color(0xFFA7442C),
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'The latest pieces',
            style: TextStyle(
              fontFamily: 'serif',
              fontSize: 38,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: names
                  .map(
                    (category) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(category),
                        selected: store.selectedCategory == category,
                        onSelected: (_) => store.setCategory(category),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryBanner extends StatelessWidget {
  const _DeliveryBanner();
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.all(16),
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      color: const Color(0xFF171811),
      borderRadius: BorderRadius.circular(30),
    ),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SHOPPING MADE SIMPLE',
          style: TextStyle(
            color: Color(0xFFEFC357),
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        SizedBox(height: 10),
        Text(
          'From our rack to your door.',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'serif',
            fontSize: 34,
          ),
        ),
        SizedBox(height: 24),
        _DeliveryRow(
          icon: Icons.verified_user_outlined,
          text: 'Pay securely with Mobile Money.',
        ),
        _DeliveryRow(
          icon: Icons.location_on_outlined,
          text: 'Share your pin or enter the delivery address.',
        ),
        _DeliveryRow(
          icon: Icons.local_shipping_outlined,
          text: 'Track your order through delivery.',
        ),
      ],
    ),
  );
}

class _DeliveryRow extends StatelessWidget {
  const _DeliveryRow({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Icon(icon, color: const Color(0xFFEFC357)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: const TextStyle(color: Colors.white70)),
        ),
      ],
    ),
  );
}
