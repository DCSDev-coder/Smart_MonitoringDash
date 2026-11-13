import 'package:flutter/material.dart';

import '../../core/network/cpanel_api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../features/smart_rack_console/theme/console_theme.dart';
import 'safe_network_image.dart';

class DesktopNavTabItem {
  final String label;
  final IconData icon;

  const DesktopNavTabItem({
    required this.label,
    required this.icon,
  });
}

class DesktopSideNavRail extends StatelessWidget {
  final int selectedIndex;
  final List<DesktopNavTabItem> tabs;
  final ValueChanged<int> onSelectTab;
  final double width;

  const DesktopSideNavRail({
    super.key,
    required this.selectedIndex,
    required this.tabs,
    required this.onSelectTab,
    this.width = 84.0,
  });

  String? _companyLogoUrl() {
    return CpanelApiService.instance.currentCompanyLogoUrl();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF090E15) : Colors.white;
    final borderColor = isDark ? const Color(0xFF1B2330) : const Color(0xFFE2E8F0);
    final logoUrl = _companyLogoUrl();

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          right: BorderSide(color: borderColor, width: 1.2),
        ),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            const SizedBox(height: 18),

            // ── DCS Brand Logo at Top ──
            SizedBox(
              height: 40,
              width: width - 20,
              child: Center(
                child: logoUrl != null && logoUrl.isNotEmpty
                    ? SafeNetworkImage(
                        logoUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (_) => Image.asset(
                          'assets/DCS_Logo/DCS Logo.png',
                          fit: BoxFit.contain,
                        ),
                      )
                    : Image.asset(
                        'assets/DCS_Logo/DCS Logo.png',
                        fit: BoxFit.contain,
                      ),
              ),
            ),

            const SizedBox(height: 24),
            Container(
              width: width - 36,
              height: 1,
              color: borderColor,
            ),
            const SizedBox(height: 20),

            // ── Vertical Nav Items (Fixed width, No expansion, No slide-out) ──
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: tabs.asMap().entries.map((entry) {
                    final index = entry.key;
                    final tab = entry.value;
                    final isSelected = selectedIndex == index;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _SideRailButton(
                        label: tab.label,
                        icon: tab.icon,
                        isSelected: isSelected,
                        onTap: () => onSelectTab(index),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SideRailButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _SideRailButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_SideRailButton> createState() => _SideRailButtonState();
}

class _SideRailButtonState extends State<_SideRailButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cyan = ConsoleTheme.cyan(context);
    final primaryBlue = ConsoleTheme.primaryBlue(context);
    final textSecondary = ConsoleTheme.textSecondary(context);

    // Matching the glowing rounded pill style in the reference image
    final Color bg = widget.isSelected
        ? primaryBlue.withValues(alpha: 0.18)
        : (_isHovered
            ? (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04))
            : Colors.transparent);

    final Border border = widget.isSelected
        ? Border.all(color: cyan, width: 1.5)
        : Border.all(
            color: _isHovered
                ? (isDark ? Colors.white.withValues(alpha: 0.16) : const Color(0xFFCBD5E1))
                : (isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE2E8F0)),
            width: 1.0,
          );

    final List<BoxShadow>? shadows = widget.isSelected
        ? [
            BoxShadow(
              color: cyan.withValues(alpha: 0.30),
              blurRadius: 10,
              spreadRadius: 0.5,
              offset: const Offset(0, 2),
            ),
          ]
        : null;

    final Color contentColor = widget.isSelected
        ? cyan
        : (_isHovered
            ? (isDark ? Colors.white : AppTheme.lightTextPrimary)
            : textSecondary);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 66,
          height: 60,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: border,
            boxShadow: shadows,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.icon,
                color: contentColor,
                size: 20,
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      color: contentColor,
                      fontSize: 10.5,
                      fontWeight: widget.isSelected ? FontWeight.bold : FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
