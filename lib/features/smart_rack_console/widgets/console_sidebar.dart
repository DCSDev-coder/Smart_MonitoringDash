import 'package:flutter/material.dart';

import '../models/smart_rack_device_profile.dart';
import '../theme/console_theme.dart';

class ConsoleSidebar extends StatefulWidget {
  const ConsoleSidebar({
    super.key,
    required this.profile,
    required this.selectedIndex,
    required this.onItemSelected,
    this.isCollapsed = false,
  });

  final SmartRackDeviceProfile profile;
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final bool isCollapsed;

  @override
  State<ConsoleSidebar> createState() => _ConsoleSidebarState();
}

class _ConsoleSidebarState extends State<ConsoleSidebar> {
  bool _showLabels = true;
  late final ScrollController _scrollController;
  bool _canScrollUp = false;
  bool _canScrollDown = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _showLabels = !widget.isCollapsed;
    _scrollController.addListener(_updateScrollIndicators);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateScrollIndicators();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateScrollIndicators);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ConsoleSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCollapsed != oldWidget.isCollapsed) {
      if (widget.isCollapsed) {
        setState(() => _showLabels = false);
      } else {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted && !widget.isCollapsed) {
            setState(() => _showLabels = true);
          }
        });
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateScrollIndicators();
      });
    }
  }

  void _updateScrollIndicators() {
    if (!mounted || !_scrollController.hasClients) return;
    
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    
    final canScrollUp = currentScroll > 1.0;
    final canScrollDown = maxScroll > 0 && currentScroll < maxScroll - 1.0;

    if (canScrollUp != _canScrollUp || canScrollDown != _canScrollDown) {
      setState(() {
        _canScrollUp = canScrollUp;
        _canScrollDown = canScrollDown;
      });
    }
  }

  static const _items = <_ConsoleNavItem>[
    _ConsoleNavItem(Icons.home_rounded, 'Home'),
    _ConsoleNavItem(Icons.ac_unit_rounded, 'AC'),
    _ConsoleNavItem(Icons.battery_charging_full_rounded, 'UPS'),
    _ConsoleNavItem(Icons.bolt_rounded, 'Power'),
    _ConsoleNavItem(Icons.power_rounded, 'PDU'),
    _ConsoleNavItem(Icons.computer_rounded, 'IT Device'),
    _ConsoleNavItem(Icons.door_front_door_rounded, 'Door'),
    _ConsoleNavItem(Icons.insights_rounded, 'PUE'),
    _ConsoleNavItem(Icons.settings_rounded, 'Settings'),
    _ConsoleNavItem(Icons.notifications_active_rounded, 'Alarm'),
  ];

  @override
  Widget build(BuildContext context) {
    final dividerColor = ConsoleTheme.divider(context);
    final textSecondary = ConsoleTheme.textSecondary(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: widget.isCollapsed ? 80 : ConsoleTheme.sidebarWidth,
      margin: const EdgeInsets.only(left: ConsoleTheme.xl, bottom: ConsoleTheme.xl, right: ConsoleTheme.xl),
      decoration: BoxDecoration(
        color: ConsoleTheme.panelBg(context).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(ConsoleTheme.cardRadius),
        border: Border.all(
          color: dividerColor,
          width: 1.0,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Navigation List starts below a bit of padding
          const SizedBox(height: ConsoleTheme.lg),

          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            height: _canScrollUp ? 26.0 : 0.0,
            curve: Curves.easeInOut,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _canScrollUp ? 1.0 : 0.0,
              child: Center(
                child: Icon(
                  Icons.keyboard_arrow_up_rounded,
                  color: ConsoleTheme.tealGlow(context),
                  size: 22,
                ),
              ),
            ),
          ),

          // Navigation List
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                _updateScrollIndicators();
                return false;
              },
              child: ListView.separated(
                controller: _scrollController,
                padding: EdgeInsets.symmetric(
                  horizontal: widget.isCollapsed ? 8.0 : ConsoleTheme.md,
                  vertical: ConsoleTheme.sm,
                ),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  final selected = index == widget.selectedIndex;

                  return InkWell(
                    onTap: () => widget.onItemSelected(index),
                    borderRadius: BorderRadius.circular(ConsoleTheme.innerRadius),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: EdgeInsets.symmetric(
                        horizontal: widget.isCollapsed ? 8.0 : ConsoleTheme.md,
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
                        mainAxisAlignment: widget.isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
                        children: [
                          Icon(
                            item.icon,
                            color: selected
                                ? ConsoleTheme.tealGlow(context)
                                : textSecondary,
                            size: 20,
                          ),
                          if (_showLabels) ...[
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
          ),

          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            height: _canScrollDown ? 26.0 : 0.0,
            curve: Curves.easeInOut,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _canScrollDown ? 1.0 : 0.0,
              child: Center(
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: ConsoleTheme.tealGlow(context),
                  size: 22,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: ConsoleTheme.sm),
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
