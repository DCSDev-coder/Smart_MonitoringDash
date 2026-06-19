import 'package:flutter/material.dart';

import '../models/smart_rack_device_profile.dart';
import '../theme/console_theme.dart';

class ConsoleSidebar extends StatelessWidget {
  const ConsoleSidebar({
    super.key,
    required this.profile,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  final SmartRackDeviceProfile profile;
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  static const _items = <_ConsoleNavItem>[
    _ConsoleNavItem(Icons.home_rounded, 'Home'),
    _ConsoleNavItem(Icons.ac_unit_rounded, 'AC'),
    _ConsoleNavItem(Icons.battery_charging_full_rounded, 'UPS'),
    _ConsoleNavItem(Icons.bolt_rounded, 'Power'),
    _ConsoleNavItem(Icons.power_rounded, 'PDU'),
    _ConsoleNavItem(Icons.computer_rounded, 'IT Device'),
    _ConsoleNavItem(Icons.door_sliding_rounded, 'Door'),
    _ConsoleNavItem(Icons.insights_rounded, 'PUE'),
    _ConsoleNavItem(Icons.settings_rounded, 'Settings'),
    _ConsoleNavItem(Icons.notifications_active_rounded, 'Alarm'),
  ];

  @override
  Widget build(BuildContext context) {
    final dividerColor = ConsoleTheme.divider(context);
    final textSecondary = ConsoleTheme.textSecondary(context);
    final textPrimary = ConsoleTheme.textPrimary(context);

    return Container(
      width: ConsoleTheme.sidebarWidth,
      decoration: BoxDecoration(
        color: ConsoleTheme.panelBg(context),
        border: Border(
          right: BorderSide(
            color: dividerColor,
            width: 1.0,
          ),
        ),
      ),
      child: Column(
        children: [
          // Navigation List starts below a bit of padding
          const SizedBox(height: ConsoleTheme.lg),

          // Navigation List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(
                horizontal: ConsoleTheme.md,
                vertical: ConsoleTheme.sm,
              ),
              itemBuilder: (context, index) {
                final item = _items[index];
                final selected = index == selectedIndex;

                return InkWell(
                  onTap: () => onItemSelected(index),
                  borderRadius: BorderRadius.circular(ConsoleTheme.innerRadius),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: ConsoleTheme.md,
                      vertical: 12.0,
                    ),
                    decoration: BoxDecoration(
                      gradient: selected
                          ? ConsoleTheme.activeAccentGradient(context)
                          : null,
                      color: selected
                          ? null
                          : Colors.transparent,
                      borderRadius:
                          BorderRadius.circular(ConsoleTheme.innerRadius),
                      boxShadow: null,
                      border: Border.all(
                        color: selected ? Colors.transparent : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          item.icon,
                          color: selected
                              ? ConsoleTheme.tealGlow(context)
                              : textSecondary,
                          size: 20,
                        ),
                        const SizedBox(width: ConsoleTheme.md),
                        Expanded(
                          child: Text(
                            item.label,
                            style: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : textSecondary,
                              fontSize: 13,
                              fontWeight:
                                  selected ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              separatorBuilder: (_, __) =>
                  const SizedBox(height: ConsoleTheme.sm),
              itemCount: _items.length,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConsoleNavItem {
  const _ConsoleNavItem(this.icon, this.label);

  final IconData icon;
  final String label;
}
