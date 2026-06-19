import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/smart_rack_device_profile.dart';

class ConsoleSidebar extends StatelessWidget {
  const ConsoleSidebar({
    super.key,
    required this.profile,
  });

  final SmartRackDeviceProfile profile;

  static const _items = <_ConsoleNavItem>[
    _ConsoleNavItem(Icons.home_rounded, 'Home'),
    _ConsoleNavItem(Icons.ac_unit_rounded, 'AC'),
    _ConsoleNavItem(Icons.battery_full_rounded, 'UPS'),
    _ConsoleNavItem(Icons.flash_on_rounded, 'Power'),
    _ConsoleNavItem(Icons.computer_rounded, 'IT Device'),
    _ConsoleNavItem(Icons.meeting_room_rounded, 'Door'),
    _ConsoleNavItem(Icons.insights_rounded, 'PUE'),
    _ConsoleNavItem(Icons.notifications_active_rounded, 'Alarm'),
    _ConsoleNavItem(Icons.settings_rounded, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      margin: const EdgeInsets.fromLTRB(16, 16, 12, 16),
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Column(
              children: [
                const Icon(Icons.corporate_fare_rounded,
                    color: AppTheme.accentBlue, size: 30),
                const SizedBox(height: 8),
                Text(
                  profile.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: AppTheme.dividerColor, height: 1),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemBuilder: (_, index) {
                final item = _items[index];
                final selected = index == 0;
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppTheme.accentBlue.withValues(alpha: 0.18)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected
                          ? AppTheme.accentBlue.withValues(alpha: 0.35)
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(item.icon,
                          color: selected
                              ? AppTheme.accentBlue
                              : AppTheme.textSecondary,
                          size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.label,
                          style: TextStyle(
                            color: selected
                                ? AppTheme.textPrimary
                                : AppTheme.textSecondary,
                            fontSize: 13,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(height: 8),
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
