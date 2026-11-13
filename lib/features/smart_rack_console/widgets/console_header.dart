import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/network/cpanel_api_service.dart';
import '../../../shared/widgets/safe_network_image.dart';
import '../models/smart_rack_device_profile.dart';
import '../models/smart_rack_console_snapshot.dart';
import '../services/rack_console_preferences.dart';
import '../services/smart_rack_console_repository.dart';
import '../theme/console_theme.dart';

class ConsoleHeaderTabItem {
  final String label;
  final IconData icon;

  const ConsoleHeaderTabItem({
    required this.label,
    required this.icon,
  });
}

class ConsoleHeader extends StatelessWidget {
  const ConsoleHeader({
    super.key,
    required this.profile,
    required this.currentPageTitle,
    this.leading,
    this.onNotificationTap,
    this.onProfileTap,
    this.menuKey,
    this.selectedIndex,
    this.onSelectTab,
    this.tabs,
  });

  final SmartRackDeviceProfile profile;
  final String currentPageTitle;
  final Widget? leading;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onProfileTap;
  final GlobalKey? menuKey;
  final int? selectedIndex;
  final ValueChanged<int>? onSelectTab;
  final List<ConsoleHeaderTabItem>? tabs;

  String? _companyLogoUrl() {
    return CpanelApiService.instance.currentCompanyLogoUrl();
  }

  Widget _buildHeaderLogo(BuildContext context, String? logoUrl) {
    if (logoUrl != null && logoUrl.isNotEmpty) {
      return SafeNetworkImage(
        logoUrl,
        height: 38,
        fit: BoxFit.contain,
        errorBuilder: (context) => Image.asset(
          'assets/DCS_Logo/DCS Logo.png',
          height: 38,
          fit: BoxFit.contain,
        ),
      );
    }
    return Image.asset(
      'assets/DCS_Logo/DCS Logo.png',
      height: 38,
      fit: BoxFit.contain,
    );
  }

  Widget _buildNavTab({
    required BuildContext context,
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final primaryCyan = ConsoleTheme.cyan(context);
    final primaryBlue = ConsoleTheme.primaryBlue(context);
    final textSecondary = ConsoleTheme.textSecondary(context);

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected
                ? primaryBlue.withValues(alpha: 0.16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? primaryCyan.withValues(alpha: 0.45)
                  : Colors.white.withValues(alpha: 0.05),
              width: 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: primaryCyan.withValues(alpha: 0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? primaryCyan : textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? primaryCyan : textSecondary,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusPill(BuildContext context, SmartRackConsoleSnapshot snapshot) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: ConsoleTheme.innerSurface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: ConsoleTheme.cardBorder(context),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: snapshot.healthColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: snapshot.healthColor.withValues(alpha: 0.55),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            snapshot.healthLabel,
            style: TextStyle(
              color: ConsoleTheme.textSecondary(context),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation:
          Listenable.merge([SmartRackConsoleRepository.instance, CpanelApiService.instance]),
      builder: (context, _) {
        final logoUrl = _companyLogoUrl();
        final snapshot = SmartRackConsoleRepository.instance.currentSnapshot();
        final hasNavTabs = tabs != null && tabs!.isNotEmpty;

        if (!hasNavTabs) {
          return Container(
            height: ConsoleTheme.headerHeight,
            padding: const EdgeInsets.symmetric(
              horizontal: ConsoleTheme.xl,
            ),
            decoration: const BoxDecoration(
              color: Colors.transparent,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (leading != null) leading! else const SizedBox.shrink(),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const _LiveTimeDisplay(),
                        const SizedBox(width: 20),
                        _HeaderIconBadge(
                          icon: Icons.notifications_rounded,
                          count: snapshot.issueCount,
                          onTap: onNotificationTap,
                        ),
                        const SizedBox(width: 14),
                        InkWell(
                          key: menuKey,
                          onTap: onProfileTap,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: ConsoleTheme.innerSurface(context),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: ConsoleTheme.cardBorder(context),
                              ),
                            ),
                            child: Icon(
                              Icons.menu_rounded,
                              color: ConsoleTheme.textSecondary(context),
                              size: 24,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      currentPageTitle,
                      style: TextStyle(
                        color: ConsoleTheme.textPrimary(context),
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildStatusPill(context, snapshot),
                  ],
                ),
              ],
            ),
          );
        }

        return Container(
          height: ConsoleTheme.headerHeight,
          padding: const EdgeInsets.symmetric(
            horizontal: ConsoleTheme.xl,
          ),
          decoration: const BoxDecoration(
            color: Colors.transparent,
          ),
          child: Row(
            children: [
              // ── Left: Logo + Vertical Divider + Nav Tabs ──────────────────
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(width: ConsoleTheme.sm),
                  ],
                  _buildHeaderLogo(context, logoUrl),
                  if (hasNavTabs) ...[
                    const SizedBox(width: 16),
                    Container(
                      width: 1,
                      height: 24,
                      color: ConsoleTheme.cardBorder(context),
                    ),
                    const SizedBox(width: 12),
                    ...tabs!.asMap().entries.map((entry) {
                      final i = entry.key;
                      final tab = entry.value;
                      final isSelected = selectedIndex == i;
                      return _buildNavTab(
                        context: context,
                        label: tab.label,
                        icon: tab.icon,
                        isSelected: isSelected,
                        onTap: () => onSelectTab?.call(i),
                      );
                    }),
                  ],
                ],
              ),

              const Spacer(),

              // ── Center / Status ──────────────────────────────────────────
              _buildStatusPill(context, snapshot),

              const SizedBox(width: 24),

              // ── Right Utility Section ───────────────────────────────────
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Time display
                  const _LiveTimeDisplay(),
                  const SizedBox(width: 20),

                  // Notification Icon with Badge
                  _HeaderIconBadge(
                    icon: Icons.notifications_rounded,
                    count: snapshot.issueCount,
                    onTap: onNotificationTap,
                  ),
                  const SizedBox(width: 14),

                  // Settings/Hamburger Menu Icon Button
                  InkWell(
                    key: menuKey,
                    onTap: onProfileTap,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: ConsoleTheme.innerSurface(context),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: ConsoleTheme.cardBorder(context),
                        ),
                      ),
                      child: Icon(
                        Icons.menu_rounded,
                        color: ConsoleTheme.textSecondary(context),
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeaderIconBadge extends StatelessWidget {
  const _HeaderIconBadge({
    required this.icon,
    required this.count,
    this.onTap,
  });

  final IconData icon;
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isAlert = count > 0;
    final badgeColor = ConsoleTheme.danger(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: ConsoleTheme.innerSurface(context),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: ConsoleTheme.cardBorder(context),
              ),
            ),
            child: Icon(
              icon,
              color: isAlert
                  ? ConsoleTheme.primaryBlue(context)
                  : ConsoleTheme.textSecondary(context),
              size: 24,
            ),
          ),
          if (isAlert)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: badgeColor.withValues(alpha: 0.4),
                      blurRadius: 6,
                    ),
                  ],
                ),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LiveTimeDisplay extends StatefulWidget {
  const _LiveTimeDisplay();

  @override
  State<_LiveTimeDisplay> createState() => _LiveTimeDisplayState();
}

class _LiveTimeDisplayState extends State<_LiveTimeDisplay> {
  late Timer _timer;
  late DateTime _currentTime;

  void _handlePreferenceChange() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _currentTime = DateTime.now();
    RackConsolePreferences.instance.addListener(_handlePreferenceChange);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    RackConsolePreferences.instance.removeListener(_handlePreferenceChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formatDate = DateFormat('yyyy-MM-dd');
    final prefs = RackConsolePreferences.instance;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          prefs.formatClock(_currentTime),
          style: TextStyle(
            color: ConsoleTheme.textPrimary(context),
            fontSize: 14,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          formatDate.format(_currentTime),
          style: TextStyle(
            color: ConsoleTheme.textMuted(context),
            fontSize: 11,
            fontWeight: FontWeight.w500,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
