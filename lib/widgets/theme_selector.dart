import 'package:flutter/material.dart';

import '../state/theme_controller.dart';

class ThemeSelector extends StatelessWidget {
  const ThemeSelector({super.key, required this.controller});
  final ThemeController controller;

  @override
  Widget build(BuildContext context) => PopupMenuButton<ThemeMode>(
    tooltip: 'Theme',
    initialValue: controller.mode,
    onSelected: controller.setMode,
    itemBuilder: (_) => const [
      PopupMenuItem(
        value: ThemeMode.system,
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.brightness_auto_outlined),
          title: Text('System theme'),
        ),
      ),
      PopupMenuItem(
        value: ThemeMode.light,
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.light_mode_outlined),
          title: Text('Light theme'),
        ),
      ),
      PopupMenuItem(
        value: ThemeMode.dark,
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.dark_mode_outlined),
          title: Text('Dark theme'),
        ),
      ),
    ],
    icon: Icon(switch (controller.mode) {
      ThemeMode.light => Icons.light_mode_outlined,
      ThemeMode.dark => Icons.dark_mode_outlined,
      ThemeMode.system => Icons.brightness_auto_outlined,
    }),
  );
}
