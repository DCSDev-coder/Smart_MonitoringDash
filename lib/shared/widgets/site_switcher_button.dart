import 'package:flutter/material.dart';

import '../../core/auth/session_flow_service.dart';
import '../../core/network/cpanel_api_service.dart';
import '../../features/smart_rack_console/theme/console_theme.dart';
import '../utils/app_toast.dart';

/// Compact Site & Rack selector pills shown in `'main'` builds whenever the
/// logged-in account has 2+ sites or the active site has 2+ racks assigned by
/// Admin. Hidden for single-site/single-rack accounts and `rack_console` kiosks.
class SiteSwitcherButton extends StatefulWidget {
  const SiteSwitcherButton({
    super.key,
    this.compact = false,
  });

  final bool compact;

  @override
  State<SiteSwitcherButton> createState() => _SiteSwitcherButtonState();
}

class _SiteSwitcherButtonState extends State<SiteSwitcherButton> {
  bool _switching = false;

  Future<void> _handleSelectSite(Map<String, dynamic> site) async {
    final currentId = int.tryParse(
      CpanelApiService.instance.currentSite?['site_id']?.toString() ?? '',
    );
    final nextId = int.tryParse(site['site_id']?.toString() ?? '');
    if (_switching || (currentId != null && currentId == nextId)) return;

    setState(() => _switching = true);
    try {
      final updated = await SessionFlowService.instance.switchSite(site);
      if (!mounted) return;
      final name = (updated['site_name'] ?? 'Site').toString();
      AppToast.showSuccess(context, 'Switched to $name');
    } catch (e) {
      if (!mounted) return;
      AppToast.showError(context, 'Failed to switch site: $e');
    } finally {
      if (mounted) {
        setState(() => _switching = false);
      }
    }
  }

  Future<void> _handleSelectMonitor(Map<String, dynamic> monitor) async {
    final currentId = CpanelApiService.instance.selectedMonitorId;
    final nextId = int.tryParse(monitor['id']?.toString() ?? '');
    if (_switching || (currentId != null && currentId == nextId)) return;

    setState(() => _switching = true);
    try {
      await SessionFlowService.instance.switchMonitor(monitor);
      if (!mounted) return;
      final cab = (monitor['cabinet_id'] ?? '').toString().trim();
      final lbl = (monitor['label'] ?? 'Rack').toString().trim();
      AppToast.showSuccess(
        context,
        cab.isNotEmpty ? 'Switched to $cab ($lbl)' : 'Switched to $lbl',
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.showError(context, 'Failed to switch rack: $e');
    } finally {
      if (mounted) {
        setState(() => _switching = false);
      }
    }
  }

  Widget _buildPill({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color accent,
  }) {
    final textPrimary = ConsoleTheme.textPrimary(context);
    final textSecondary = ConsoleTheme.textSecondary(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: widget.compact ? 9 : 12,
        vertical: widget.compact ? 6 : 7,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accent.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_switching)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: accent,
              ),
            )
          else
            Icon(icon, size: 15, color: accent),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: widget.compact ? 86 : 150,
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 3),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 16,
            color: textSecondary,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CpanelApiService.instance,
      builder: (context, _) {
        final api = CpanelApiService.instance;
        final showSites = api.hasMultipleSites;
        final showMonitors = api.hasMultipleMonitors;
        if (!showSites && !showMonitors) {
          return const SizedBox.shrink();
        }

        final cyan = ConsoleTheme.cyan(context);
        final blue = ConsoleTheme.primaryBlue(context);
        final cardBg = ConsoleTheme.cardBg(context);
        final textPrimary = ConsoleTheme.textPrimary(context);
        final textSecondary = ConsoleTheme.textSecondary(context);

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showSites)
              PopupMenuButton<Map<String, dynamic>>(
                enabled: !_switching,
                tooltip: 'Switch Site',
                color: cardBg,
                offset: const Offset(0, 42),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: cyan.withValues(alpha: 0.25)),
                ),
                onSelected: _handleSelectSite,
                itemBuilder: (ctx) {
                  final currentId = int.tryParse(
                    api.currentSite?['site_id']?.toString() ?? '',
                  );
                  return api.availableSites.map((site) {
                    final sId = int.tryParse(site['site_id']?.toString() ?? '');
                    final isSelected = sId != null && sId == currentId;
                    final name = (site['site_name'] ?? 'Site #$sId').toString();
                    final monitorsCount = site['monitors'] is List
                        ? (site['monitors'] as List).length
                        : 0;
                    final ip = (site['open_ip'] ?? '').toString().trim();
                    final subtitle = [
                      if (monitorsCount > 1) '$monitorsCount racks',
                      if (ip.isNotEmpty) ip,
                    ].join(' • ');

                    return PopupMenuItem<Map<String, dynamic>>(
                      value: site,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isSelected
                                ? Icons.check_circle_rounded
                                : Icons.apartment_rounded,
                            size: 18,
                            color: isSelected ? cyan : textSecondary,
                          ),
                          const SizedBox(width: 10),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 210),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isSelected ? cyan : textPrimary,
                                    fontSize: 13,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                                if (subtitle.isNotEmpty)
                                  Text(
                                    subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList();
                },
                child: _buildPill(
                  context: context,
                  icon: Icons.apartment_rounded,
                  label: () {
                    final name = (api.currentSite?['site_name'] ?? 'Select Site')
                        .toString()
                        .trim();
                    return widget.compact ? name : 'Site: $name';
                  }(),
                  accent: cyan,
                ),
              ),
            if (showSites && showMonitors) const SizedBox(width: 8),
            if (showMonitors)
              PopupMenuButton<Map<String, dynamic>>(
                enabled: !_switching,
                tooltip: 'Switch Server Rack',
                color: cardBg,
                offset: const Offset(0, 42),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: blue.withValues(alpha: 0.3)),
                ),
                onSelected: _handleSelectMonitor,
                itemBuilder: (ctx) {
                  final activeMonitor = api.currentMonitor;
                  final activeId = int.tryParse(
                    activeMonitor?['id']?.toString() ?? '',
                  );
                  return api.availableMonitors.map((mon) {
                    final mId = int.tryParse(mon['id']?.toString() ?? '');
                    final isSelected = mId != null && mId == activeId;
                    final cab = (mon['cabinet_id'] ?? '').toString().trim();
                    final label = (mon['label'] ?? 'Rack').toString().trim();
                    final ip = (mon['open_ip'] ?? '').toString().trim();
                    final title = cab.isNotEmpty ? '$cab • $label' : label;

                    return PopupMenuItem<Map<String, dynamic>>(
                      value: mon,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isSelected
                                ? Icons.check_circle_rounded
                                : Icons.dns_outlined,
                            size: 18,
                            color: isSelected ? blue : textSecondary,
                          ),
                          const SizedBox(width: 10),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 210),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isSelected ? blue : textPrimary,
                                    fontSize: 13,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                                if (ip.isNotEmpty)
                                  Text(
                                    ip,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList();
                },
                child: _buildPill(
                  context: context,
                  icon: Icons.dns_outlined,
                  label: () {
                    final m = api.currentMonitor;
                    final cab = (m?['cabinet_id'] ?? '').toString().trim();
                    final lbl = (m?['label'] ?? 'Rack').toString().trim();
                    final rackName = cab.isNotEmpty ? cab : lbl;
                    return widget.compact ? rackName : 'Rack: $rackName';
                  }(),
                  accent: blue,
                ),
              ),
          ],
        );
      },
    );
  }
}
