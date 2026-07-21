import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/network/cpanel_api_service.dart';
import '../../../shared/widgets/safe_network_image.dart';
import '../models/smart_rack_device_profile.dart';
import '../services/rack_console_preferences.dart';
import '../services/smart_rack_console_repository.dart';
import '../theme/console_theme.dart';

class ConsoleHeader extends StatelessWidget {
  const ConsoleHeader({
    super.key,
    required this.profile,
    required this.currentPageTitle,
    this.leading,
    this.onNotificationTap,
    this.onProfileTap,
  });

  final SmartRackDeviceProfile profile;
  final String currentPageTitle;
  final Widget? leading;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onProfileTap;

  String? _companyLogoUrl() {
    return CpanelApiService.instance.currentCompanyLogoUrl();
  }

  @override
  Widget build(BuildContext context) {
    final logoUrl = _companyLogoUrl();

    return AnimatedBuilder(
      animation: SmartRackConsoleRepository.instance,
      builder: (context, _) {
        final snapshot = SmartRackConsoleRepository.instance.currentSnapshot();

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
                  // ── Left Section: Logo (centered inside the sidebar width box) ──
                  Row(
                    children: [
                      Container(
                        width: ConsoleTheme.sidebarWidth - ConsoleTheme.xl,
                        alignment: Alignment.centerLeft, // Pushes it left
                        padding: const EdgeInsets.only(
                            top: 7.0,
                            left:
                                40), // 'top' moves it down. 'left' pushes it right.
                        child: Row(
                          children: [
                            if (leading != null) ...[
                              leading!,
                              const SizedBox(width: ConsoleTheme.sm),
                            ],
                            Expanded(
                              child: logoUrl != null && logoUrl.isNotEmpty
                                  ? SizedBox(
                                      height: 85, // Enlarged logo even more
                                      child: SafeNetworkImage(
                                        logoUrl,
                                        fit: BoxFit
                                            .contain, // Fit and not stretch
                                        errorBuilder: (context) =>
                                            _buildDefaultProfileIcon(context),
                                      ),
                                    )
                                  : _buildDefaultProfileIcon(context),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // ── Right Utility Section ──────────────────────────────────
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Time display
                      const _LiveTimeDisplay(),
                      const SizedBox(
                          width: 24), // Expanded gap from time to notification

                      // Notification Icon with Badge (Alert)
                      _HeaderIconBadge(
                        icon: Icons.notifications_rounded,
                        count: snapshot.issueCount,
                        onTap: onNotificationTap,
                      ),
                      const SizedBox(
                          width:
                              20), // Expanded gap from notification to setting

                      // Settings/Hamburger Menu Icon Button (3 slice icon)
                      InkWell(
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
                            size: 24, // Expanded icon size
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // ── Centered Title & Status ────────────────────────────────────
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
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
                              color:
                                  snapshot.healthColor.withValues(alpha: 0.5),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: ConsoleTheme.sm),
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
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDefaultProfileIcon(BuildContext context) {
    return SizedBox(
      width: 75,
      height: 75,
      child: Icon(
        Icons.person_rounded,
        color: ConsoleTheme.textSecondary(context),
        size: 48, // Enlarged icon size to match logo height
      ),
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
