import 'dart:ui';
import 'package:flutter/material.dart';
import 'dashboard_glass.dart';
import 'safe_network_image.dart';

class DashboardHeader extends StatelessWidget {
  final String? logoUrl;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onMenuTap;
  final VoidCallback? onLogoTap;
  final GlobalKey? settingsIconKey;
  final int notificationCount;
  final bool? notificationCriticalGlow;
  final Widget? trailing;

  const DashboardHeader({
    super.key,
    required this.logoUrl,
    required this.onNotificationTap,
    required this.onMenuTap,
    this.onLogoTap,
    this.settingsIconKey,
    this.notificationCount = 0,
    this.notificationCriticalGlow,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    const activeColor = Color(0xFF00A3FF); // Vibrant Cyan Blue
    final hasNotifications = notificationCount > 0;

    return LayoutBuilder(
      builder: (context, c) {
        // Keep enough room for the right-side buttons on narrow screens.
        // Prevents RenderFlex overflow in web layouts.
        final reservedRight = 48.0 + 12.0 + 48.0 + 12.0 + (trailing != null ? 60.0 : 0.0);
        final maxLogo = (c.maxWidth - reservedRight).clamp(96.0, 220.0);

        return Row(
          children: [
            Flexible(
              fit: FlexFit.loose,
              child: GestureDetector(
                onTap: onLogoTap,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (logoUrl != null)
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxLogo),
                          child: SafeNetworkImage(
                            logoUrl!,
                            height: 54,
                            fit: BoxFit.contain,
                            errorBuilder: (_) => Icon(
                              Icons.business_rounded,
                              color:
                                  isLight ? Colors.black26 : Colors.white24,
                              size: 36,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const Spacer(),
        
        // Notification Button (no count badge; bell itself reflects alert state)
        _HeaderIconButton(
          icon: Icons.notifications_none_rounded,
          onTap: onNotificationTap,
          isLight: isLight,
          activeColor: activeColor,
          isAlert: hasNotifications,
        ),
        
        if (trailing != null) ...[
          const SizedBox(width: 12),
          trailing!,
        ],
        const SizedBox(width: 12),
        
        // Settings Button
        _HeaderIconButton(
          key: settingsIconKey,
          icon: Icons.menu_rounded,
          onTap: onMenuTap,
          isLight: isLight,
          activeColor: activeColor,
          isAlert: false,
        ),
          ],
        );
      },
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool isLight;
  final Color activeColor;
  final bool isAlert;

  const _HeaderIconButton({
    super.key,
    required this.icon,
    this.onTap,
    required this.isLight,
    required this.activeColor,
    required this.isAlert,
  });

  @override
  Widget build(BuildContext context) {
    if (!isLight) {
      // In dark mode, keep using the original glass button style
      return Stack(
        alignment: Alignment.center,
        children: [
          DashboardGlassIconButton(
            icon: icon,
            onTap: onTap,
            hitSize: 50,
            iconSize: 24,
          ),
          if (isAlert)
            const Positioned.fill(
              child: IgnorePointer(
                child: _BreathingOutlineGlow(
                  color: Color(0xFFFF3B30),
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
              ),
            ),
        ],
      );
    }

    // In light mode, use the new solid cyan/red background style
    final bgColor = isAlert ? const Color(0xFFFF4D4D) : activeColor;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: bgColor.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}

class _BreathingOutlineGlow extends StatefulWidget {
  final Color color;
  final BorderRadius borderRadius;

  const _BreathingOutlineGlow({
    required this.color,
    required this.borderRadius,
  });

  @override
  State<_BreathingOutlineGlow> createState() => _BreathingOutlineGlowState();
}

class _BreathingOutlineGlowState extends State<_BreathingOutlineGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine);
    return AnimatedBuilder(
      animation: curved,
      builder: (context, _) {
        final t = curved.value; // 0..1
        // Keep it subtle: never disappear, just "breathe".
        final k = lerpDouble(0.70, 1.0, t)!;

        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            border: Border.all(
              color: widget.color.withValues(alpha: 0.55 + 0.25 * t),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.22 * k),
                blurRadius: 14 + 10 * t,
                spreadRadius: 1,
              ),
              BoxShadow(
                color: widget.color.withValues(alpha: 0.12 * k),
                blurRadius: 36 + 18 * t,
                spreadRadius: 10,
              ),
            ],
          ),
        );
      },
    );
  }
}



