import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/navigation/app_navigator.dart';
import '../../features/dashboard/widgets/dashboard_typography.dart';
import '../../core/network/cpanel_api_service.dart';
import '../../core/network/adapter_api_service.dart';
import 'set_pin_dialog.dart';
import '../utils/app_toast.dart';

class NotificationsOverlay {
  static Future<void> show(
    BuildContext context, {
    required List<dynamic> alarms,
    void Function()? onNavigateToReport,
  }) {
    return Navigator.of(context).push<void>(
      _NotificationsOverlayRoute(alarms: alarms, onNavigateToReport: onNavigateToReport),
    );
  }
}

class _NotificationsOverlayRoute extends PopupRoute<void> {
  final List<dynamic> alarms;
  final void Function()? onNavigateToReport;
  
  _NotificationsOverlayRoute({required this.alarms, this.onNavigateToReport});

  @override
  Color get barrierColor => Colors.black.withValues(alpha: 0.55);

  @override
  bool get barrierDismissible => true;

  @override
  String get barrierLabel => 'Notifications';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 150);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return _NotificationsOverlayPage(alarms: alarms, onNavigateToReport: onNavigateToReport);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
    final slide = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(curved);

    return SlideTransition(
      position: slide,
      child: child,
    );
  }
}

class _NotificationsOverlayPage extends StatelessWidget {
  final List<dynamic> alarms;
  final void Function()? onNavigateToReport;
  
  const _NotificationsOverlayPage({required this.alarms, this.onNavigateToReport});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Material(
      type: MaterialType.transparency,
      child: SizedBox(
        width: size.width,
        height: double.infinity,
        child: _NotificationsPanel(alarms: alarms, onNavigateToReport: onNavigateToReport),
      ),
    );
  }
}

class _NotificationsPanel extends StatefulWidget {
  final List<dynamic> alarms;
  final void Function()? onNavigateToReport;
  
  const _NotificationsPanel({required this.alarms, this.onNavigateToReport});

  @override
  State<_NotificationsPanel> createState() => _NotificationsPanelState();
}

class _NotificationsPanelState extends State<_NotificationsPanel> {
  static Color _levelColor(String level) {
    final s = level.trim().toLowerCase();
    if (s.isEmpty) return const Color.fromARGB(255, 28, 78, 159);
    if (s.contains('info')) return const Color.fromARGB(255, 34, 94, 190);
    if (s.contains('good') || s.contains('normal') || s.contains('ok')) return const Color.fromARGB(255, 0, 153, 36);
    if (s.contains('moderate') || s.contains('warning') || s.contains('minor')) return const Color.fromARGB(255, 146, 122, 42);
    if (s.contains('critical') || s.contains('major')) return const Color.fromARGB(255, 145, 79, 25);
    if (s.contains('red') || s.contains('emergency') || s.contains('severe')) return const Color.fromARGB(255, 155, 33, 26);
    return const Color(0xFF2D7DFF);
  }

  static IconData _alarmIcon(String itemOrTitle) {
    final t = itemOrTitle.toUpperCase();
    if (t.contains('TEMP')) return Icons.thermostat_rounded;
    if (t.contains('HUM')) return Icons.water_drop_rounded;
    if (t.contains('SMOKE') || t.contains('FIRE')) return Icons.local_fire_department_rounded;
    if (t.contains('FLOOD') || t.contains('LEAK') || t.contains('WATER')) return Icons.water_damage_rounded;
    if (t.contains('UPS') || t.contains('BAT')) return Icons.battery_alert_rounded;
    if (t.contains('PDU') || t.contains('POWER')) return Icons.bolt_rounded;
    if (t.contains('AC')) return Icons.ac_unit_rounded;
    return Icons.notifications_rounded;
  }

  static String _title(Map a) {
    final alarmItem = (a['alarmItem'] ?? '').toString().trim();
    final content = (a['content'] ?? '').toString().trim();
    final node = (a['collectControlNodeName'] ?? '').toString().trim();
    
    final candidate = alarmItem.isNotEmpty ? alarmItem : (node.isNotEmpty ? node : content);
    if (candidate.isEmpty) return 'ALARM';

    final upper = candidate.toUpperCase();
    if (upper.contains('TEMP') && upper.contains('HUM')) return 'TEMP/HUM ISSUE';
    if (upper.contains('TEMP')) return 'TEMP ISSUE';
    if (upper.contains('HUM')) return 'HUMIDITY ISSUE';
    if (upper.contains('SMOKE')) return 'SMOKE ALERT';
    if (upper.contains('FLOOD') || upper.contains('LEAK')) return 'LEAK ALERT';
    if (upper.contains('UPS')) return 'UPS ISSUE';
    if (upper.contains('PDU')) return 'PDU ISSUE';
    
    return candidate.length > 40 ? '${candidate.substring(0, 40)}...' : candidate;
  }

  static String _subtitle(Map a) {
    final cabinet = (a['deviceCabinetName'] ?? a['locationName'] ?? '').toString().trim();
    final device = (a['deviceCabinetItemName'] ?? a['name'] ?? '').toString().trim();
    if (cabinet.isNotEmpty && device.isNotEmpty) return '$cabinet / $device';
    if (cabinet.isNotEmpty) return cabinet;
    if (device.isNotEmpty) return device;
    final node = (a['collectControlNodeName'] ?? '').toString().trim();
    if (node.isNotEmpty) return node;
    return 'System Alarm';
  }

  static String _alarmLevel(Map a) {
    final v = (a['alarmLevelLevel'] ?? a['alarmLevel'] ?? a['level'] ?? a['severity'])?.toString();
    return (v ?? '').trim();
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    
    var alarms = widget.alarms.whereType<Map>().toList();



    // Background colors matching the setting page approach
    final bgColor = isLight
        ? const Color(0xFFF9F7F1)
        : const Color(0xFF060B11);
    
    final sectionHeaderColor = isLight ? const Color(0xFF757575) : Colors.white54;
    final itemBgColor = isLight ? const Color(0xFFF3EFE6) : const Color(0xFF131922);
    final textColor = isLight ? Colors.black87 : Colors.white;
    final dividerColor = isLight ? Colors.black.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.05);

    return Container(
      color: bgColor,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: textColor),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Notifications',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: textColor,
                            letterSpacing: -0.5,
                          ),
                        ),
                        if (alarms.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF3A30),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${alarms.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                height: 1.0,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // List
            Expanded(
              child: alarms.isEmpty
                  ? Center(
                      child: Text(
                        'No Notifications',
                        style: TextStyle(
                          color: sectionHeaderColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Current Section
                          Padding(
                            padding: const EdgeInsets.fromLTRB(28, 12, 24, 12),
                            child: Text(
                              'Current',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: sectionHeaderColor,
                              ),
                            ),
                          ),
                          Container(
                            color: itemBgColor,
                            child: Column(
                              children: [
                                for (int i = 0; i < alarms.length; i++) ...[
                                  _buildAlarmItem(alarms[i], textColor),
                                  if (i < alarms.length - 1)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 86),
                                      child: Divider(height: 1, thickness: 1, color: dividerColor),
                                    ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlarmItem(Map a, Color textColor) {
    final title = _title(a);
    final subtitle = _subtitle(a);
    final level = _alarmLevel(a);
    final color = _levelColor(level);
    final icon = _alarmIcon(title);
    final isResolved = level.trim().toLowerCase().contains('resolved');
    final isPinSetup = a['isPinSetupPrompt'] == true;
    final isLight = Theme.of(context).brightness == Brightness.light;
    
    // We treat active issues as unread (red dot), resolved as read
    final unread = !isResolved;

    return InkWell(
      onTap: () async {
        if (isPinSetup) {
           Navigator.of(context).pop();
           final result = await showDialog<String>(
             context: context,
             builder: (_) => const SetPinDialog(showSkipOptions: false),
           );
           if (result != null && result != 'skipped' && result.length >= 4) {
             final success = await AdapterApiService.instance.setPin(result);
             if (context.mounted) {
               AppToast.show(context, success ? 'PIN setup successfully.' : 'Failed to set PIN.');
               if (success) {
                 CpanelApiService.instance.currentUser ??= {};
                 CpanelApiService.instance.currentUser!['has_pin'] = 1;
               }
             }
           }
           return;
        }

        GlobalEventBus.targetHistoricalAlarm.value = a;
        Navigator.of(context).pop();
        if (widget.onNavigateToReport != null) {
          widget.onNavigateToReport!();
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icon Box
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isLight ? color.withValues(alpha: 0.15) : const Color(0xFF1B1B1B),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 14),
            
            // Text Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: textColor.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Unread Dot
            if (unread)
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF3A30),
                  shape: BoxShape.circle,
                ),
              )
            else
              const SizedBox(width: 10),
          ],
        ),
      ),
    );
  }
}
