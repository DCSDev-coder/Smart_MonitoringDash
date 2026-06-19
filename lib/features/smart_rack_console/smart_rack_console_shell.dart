import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'models/smart_rack_device_profile.dart';
import 'smart_rack_console_screen.dart';
import 'widgets/console_sidebar.dart';

class SmartRackConsoleShell extends StatelessWidget {
  const SmartRackConsoleShell({
    super.key,
    this.profile = SmartRackDeviceProfiles.androidOperator,
  });

  final SmartRackDeviceProfile profile;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 980;
            if (wide) {
              return Row(
                children: [
                  ConsoleSidebar(profile: profile),
                  Expanded(
                    child: SmartRackConsoleScreen(profile: profile),
                  ),
                ],
              );
            }

            return Column(
              children: [
                _CompactHeader(profile: profile),
                Expanded(
                  child: SmartRackConsoleScreen(
                    profile: profile,
                    compact: true,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CompactHeader extends StatelessWidget {
  const _CompactHeader({required this.profile});

  final SmartRackDeviceProfile profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          const Icon(Icons.dashboard_rounded, color: AppTheme.accentBlue),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              profile.label,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Icon(Icons.circle, color: AppTheme.accentGreen, size: 10),
          const SizedBox(width: 8),
          const Text(
            'Live',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
