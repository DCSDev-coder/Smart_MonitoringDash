import 'package:flutter/material.dart';
import 'dashboard_typography.dart';

class CriticalAlertBanner extends StatefulWidget {
  final List<String> alerts;

  const CriticalAlertBanner({
    super.key,
    required this.alerts,
  });

  @override
  State<CriticalAlertBanner> createState() => _CriticalAlertBannerState();
}

class _CriticalAlertBannerState extends State<CriticalAlertBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.alerts.isEmpty) return const SizedBox.shrink();

    final alertText = widget.alerts.join('  |  ').toUpperCase();

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final glowOpacity = 0.4 + (0.6 * _controller.value);
        
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFB30000), // Industrial Alert Red
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF3B30).withValues(alpha: 0.6 * _controller.value),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.white.withValues(alpha: glowOpacity),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      alertText,
                      style: bitcount(
                        context,
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
