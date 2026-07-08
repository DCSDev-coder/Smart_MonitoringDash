import 'package:flutter/material.dart';

import '../../core/network/adapter_api_service.dart';
import '../../core/network/api_service.dart';
import '../../core/network/cpanel_api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/utils/app_toast.dart';
import '../../shared/widgets/header_refresh_bar.dart';
import '../../shared/widgets/dashboard_glass.dart';
import '../../shared/widgets/kiosk_user_pin_sheet.dart';
import '../../shared/widgets/secure_action_guard.dart';
import '../../shared/widgets/skeleton.dart';

class ControlPresetsScreen extends StatefulWidget {
  const ControlPresetsScreen({super.key});

  @override
  State<ControlPresetsScreen> createState() => _ControlPresetsScreenState();
}

class _ControlPresetsScreenState extends State<ControlPresetsScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  int? _portalUserId;
  RefreshIndicatorStatus? _refreshStatus;

  _LiveControlSnapshot? _live;
  String? _defaultPresetKey;
  Map<String, _ControlPreset> _presets = const {};

  Map<String, dynamic>? get _site => CpanelApiService.instance.currentSite;

  int? get _siteId {
    final site = _site;
    if (site == null) return null;
    return int.tryParse(site['site_id']?.toString() ?? '') ??
        int.tryParse(site['id']?.toString() ?? '');
  }

  bool get _isRackConsoleMode =>
      CpanelApiService.instance.isCurrentSiteRackConsole(_site);

  bool get _canChangeSettings {
    final site = _site;
    if (site == null) return false;
    final ownerId = int.tryParse(site['owner_user_id']?.toString() ?? '');
    if (ownerId != null && _portalUserId != null && ownerId == _portalUserId) {
      return true;
    }

    final role = site['role']?.toString().trim().toLowerCase();
    if (role == 'admin') return true;
    return CpanelApiService.instance.isTruthyFlag(site['can_change_settings']);
  }

  bool get _canUseControlPresets {
    final site = _site;
    if (site == null) return false;
    return _canChangeSettings ||
        CpanelApiService.instance.isTruthyFlag(site['can_view_control']);
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final siteId = _siteId;
    if (siteId == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Site context is missing. Please sign in again.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final portalUserId = await CpanelApiService.instance.getUserId();
      final presetsRes =
          await CpanelApiService.instance.fetchSiteControlPresets(
        siteId: siteId,
      );
      final live = await _fetchLiveSnapshot();
      if (!mounted) return;

      final presetMap = <String, _ControlPreset>{};
      final presetList = (presetsRes?['presets'] is List)
          ? (presetsRes!['presets'] as List)
          : const <dynamic>[];
      for (final raw in presetList) {
        if (raw is! Map) continue;
        final preset = _ControlPreset.fromJson(
          Map<String, dynamic>.from(raw.cast<String, dynamic>()),
        );
        presetMap[preset.presetKey] = preset;
      }

      for (final key in _presetKeys) {
        presetMap.putIfAbsent(key, () => _ControlPreset.empty(key));
      }

      setState(() {
        _portalUserId = portalUserId;
        _presets = presetMap;
        _defaultPresetKey = presetsRes?['default_preset_key']?.toString();
        _live = live;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _portalUserId = null;
        _loading = false;
        _error = 'Failed to load control presets.';
      });
    }
  }

  void _onRefreshStatusChanged(RefreshIndicatorStatus? status) {
    if (!mounted || _refreshStatus == status) return;
    setState(() => _refreshStatus = status);
  }

  bool get _showRefreshBar =>
      _loading ||
      _saving ||
      (_refreshStatus != null &&
          _refreshStatus != RefreshIndicatorStatus.canceled);

  Future<_LiveControlSnapshot?> _fetchLiveSnapshot() async {
    final candidates = <Map<String, dynamic>>[];
    final seenIds = <int>{};

    Future<void> collectCandidates(String? name) async {
      final list = await ApiService.instance
          .fetchPowerEnvNodes(name: name, pageSize: 100);
      final records = (list?['result']?['records'] as List?) ?? const [];
      for (final raw in records) {
        if (raw is! Map) continue;
        final item = raw.cast<String, dynamic>();
        final id = item['id'];
        final nodeId =
            (id is num) ? id.toInt() : int.tryParse(id?.toString() ?? '');
        if (nodeId == null || !seenIds.add(nodeId)) continue;
        candidates.add(item);
      }
    }

    await collectCandidates('*ac*');
    await collectCandidates('*AC*');
    await collectCandidates(null);
    candidates.sort((a, b) => _acScore(b).compareTo(_acScore(a)));

    for (final candidate in candidates) {
      final nodeId = int.tryParse(candidate['id']?.toString() ?? '');
      if (nodeId == null) continue;
      final snapshot = await _fetchNodeSnapshot(
        nodeId,
        fallbackName: candidate['name']?.toString(),
      );
      if (snapshot != null && snapshot.writableRows.isNotEmpty) {
        return snapshot;
      }
    }

    final legacy = await _fetchNodeSnapshot(17, fallbackName: 'AC');
    if (legacy != null && legacy.writableRows.isNotEmpty) return legacy;
    return null;
  }

  Future<_LiveControlSnapshot?> _fetchNodeSnapshot(
    int nodeId, {
    String? fallbackName,
  }) async {
    final siteId = _siteId;
    Map<String, dynamic>? res;
    if (siteId != null && AdapterApiService.instance.isConfigured) {
      res = await AdapterApiService.instance.fetchNodeWithMetric(
        siteId: siteId,
        nodeId: nodeId,
      );
    }
    res ??= await ApiService.instance.fetchNodeWithMetric(nodeId);
    final primary = _LiveControlSnapshot.fromNodeWithMetric(res);
    if (primary.rows.isNotEmpty) return primary;

    try {
      final metricsRes = await ApiService.instance.fetchNodeMetrics(nodeId);
      final fallback = _LiveControlSnapshot.fromMetricList(
        metricsRes,
        fallbackNodeId: nodeId,
        fallbackName: fallbackName ?? 'AC',
      );
      if (fallback.rows.isNotEmpty) return fallback;
    } catch (_) {}

    return primary;
  }

  String get _currentStateLabel {
    final live = _live;
    if (live == null || live.writableRows.isEmpty) return 'Unavailable';
    final matching = _matchingPresetKey(live);
    if (matching == null) return 'Custom';
    return _presetLabel(matching);
  }

  String get _defaultStateLabel {
    if (_defaultPresetKey == null || _defaultPresetKey!.isEmpty) return 'None';
    return _presetLabel(_defaultPresetKey!);
  }

  String? _matchingPresetKey(_LiveControlSnapshot live) {
    for (final key in _presetKeys) {
      final preset = _presets[key];
      if (preset == null || preset.values.isEmpty) continue;
      if (_doesPresetMatchLive(preset, live)) return key;
    }
    return null;
  }

  bool _doesPresetMatchLive(_ControlPreset preset, _LiveControlSnapshot live) {
    if (preset.values.isEmpty) return false;
    final liveByMetric = <String, String>{};
    for (final row in live.writableRows) {
      liveByMetric[row.metricCode] = row.value;
    }

    for (final entry in preset.values) {
      if (!liveByMetric.containsKey(entry.metricCode)) return false;
      if (liveByMetric[entry.metricCode] != entry.value) return false;
    }
    return true;
  }

  Future<String?> _promptAdminPassword() async {
    final ctrl = TextEditingController();
    final pw = await showDialog<String>(
      context: context,
      builder: (context) {
        final isLight = Theme.of(context).brightness == Brightness.light;
        bool obscure = true;
        return StatefulBuilder(
          builder: (context, setLocalState) => Dialog(
            backgroundColor: Colors.transparent,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: DashboardGlass(
                radius: 18,
                padding: const EdgeInsets.all(16),
                tint: isLight ? Colors.white : const Color(0xFF111922),
                borderColor: Colors.transparent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Admin Password Required',
                      style: TextStyle(
                        color:
                            isLight ? AppTheme.lightTextPrimary : Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Enter the admin password to save or change the default preset.',
                      style: TextStyle(
                        color: isLight
                            ? AppTheme.lightTextSecondary
                            : Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: ctrl,
                      autofocus: true,
                      obscureText: obscure,
                      style: TextStyle(
                          color: isLight ? Colors.black : Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        labelStyle: TextStyle(
                            color: isLight ? Colors.black54 : Colors.white54),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: isLight ? Colors.black12 : Colors.white24,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary),
                        ),
                        suffixIcon: IconButton(
                          onPressed: () =>
                              setLocalState(() => obscure = !obscure),
                          icon: Icon(
                            obscure ? Icons.visibility : Icons.visibility_off,
                            color: isLight ? Colors.black54 : Colors.white54,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () =>
                                Navigator.pop(context, ctrl.text.trim()),
                            child: const Text('Confirm'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    ctrl.dispose();
    if (pw == null || pw.trim().isEmpty) return null;
    return pw.trim();
  }

  Future<void> _applyPreset(String presetKey) async {
    final preset = _presets[presetKey];
    final siteId = _siteId;
    final live = _live;
    if (preset == null ||
        preset.values.isEmpty ||
        siteId == null ||
        live == null) {
      AppToast.show(
          context, 'Preset is empty or live controls are unavailable.');
      return;
    }

    if (_saving) return;

    RackConsoleApprovalResult? rackConsoleApproval;
    if (_isRackConsoleMode) {
      if (!AdapterApiService.instance.isConfigured) {
        AppToast.show(
          context,
          'Rack Console preset apply requires the adapter connection.',
        );
        return;
      }
      rackConsoleApproval = await RackConsoleUserPinSheet.show(
        context,
        title: 'RACK CONSOLE PRESET APPROVAL',
        reason: 'Enter the approving user PIN to apply ${preset.displayName}.',
        confirmLabel: 'Approve and Apply',
      );
      if (!mounted || rackConsoleApproval == null) return;
    } else {
      final authorized = await SecureActionGuard.ensureAuthorized(
        context,
        reason: 'Confirm to apply ${preset.displayName}',
        ttl: const Duration(seconds: 30),
        allowPin: true,
      );
      if (!mounted || !authorized) return;
    }

    setState(() => _saving = true);
    try {
      final rowMap = <String, _LiveControlRow>{
        for (final row in live.writableRows) row.metricCode: row,
      };

      for (final entry in preset.values) {
        final row = rowMap[entry.metricCode];
        if (row == null) continue;

        Map<String, dynamic>? res;
        if (_isRackConsoleMode && rackConsoleApproval != null) {
          res = await AdapterApiService.instance.writeNodeMetricWithUserPin(
            siteId: siteId,
            nodeId: live.nodeId,
            metricTypeLibCode: row.metricCode,
            value: entry.value,
            pin: rackConsoleApproval.pin,
          );
        } else if (AdapterApiService.instance.isConfigured) {
          res = await AdapterApiService.instance.writeNodeMetric(
            siteId: siteId,
            nodeId: live.nodeId,
            metricTypeLibCode: row.metricCode,
            value: entry.value,
          );
        }
        res ??= await ApiService.instance.writeNodeMetric(
          nodeId: live.nodeId,
          metricTypeLibCode: row.metricCode,
          value: entry.value,
        );

        final ok =
            (res?['success'] == true) || (res?['code']?.toString() == '20000');
        if (!ok) {
          if (!mounted) return;
          final msg = res?['message']?.toString() ??
              'Failed while applying ${preset.displayName}.';
          AppToast.showError(context, msg);
          return;
        }
      }

      if (!mounted) return;
      AppToast.showSuccess(context, '${preset.displayName} applied.');
      await _reload();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveCurrentToPreset(String presetKey) async {
    final siteId = _siteId;
    final live = _live;
    if (siteId == null || live == null || live.writableRows.isEmpty) {
      AppToast.show(context, 'Live control values are unavailable.');
      return;
    }
    if (!_canChangeSettings) {
      AppToast.show(context, 'You do not have permission to save presets.');
      return;
    }

    final adminPassword = await _promptAdminPassword();
    if (!mounted || adminPassword == null) return;

    setState(() => _saving = true);
    try {
      final values = [
        for (final row in live.writableRows) row.toPresetJson(),
      ];
      final res = await CpanelApiService.instance.saveSiteControlPreset(
        siteId: siteId,
        presetKey: presetKey,
        adminPassword: adminPassword,
        values: values,
      );
      final ok = res?['status'] == 'success';
      if (!ok) {
        if (!mounted) return;
        String msg = res?['message']?.toString() ?? 'Failed to save preset.';
        if (msg.contains('Invalid Action')) {
          msg = 'This feature is currently unavailable on the backend server.';
        }
        AppToast.showError(context, msg);
        return;
      }
      if (!mounted) return;
      AppToast.showSuccess(context, '${_presetLabel(presetKey)} saved.');
      await _reload();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setDefaultPreset(String presetKey) async {
    if (!_canChangeSettings) {
      AppToast.show(context, 'You do not have permission to change defaults.');
      return;
    }
    final preset = _presets[presetKey];
    if (preset == null || preset.values.isEmpty) {
      AppToast.show(context, 'Save the preset first before making it default.');
      return;
    }

    final adminPassword = await _promptAdminPassword();
    if (!mounted || adminPassword == null) return;

    final siteId = _siteId;
    if (siteId == null) return;

    setState(() => _saving = true);
    try {
      final res = await CpanelApiService.instance.setDefaultSiteControlPreset(
        siteId: siteId,
        presetKey: presetKey,
        adminPassword: adminPassword,
      );
      final ok = res?['status'] == 'success';
      if (!ok) {
        if (!mounted) return;
        String msg = res?['message']?.toString() ??
            'Failed to change the default preset.';
        if (msg.contains('Invalid Action')) {
          msg = 'This feature is currently unavailable on the backend server.';
        }
        AppToast.showError(context, msg);
        return;
      }
      if (!mounted) return;
      AppToast.showSuccess(
          context, '${_presetLabel(presetKey)} is now default.');
      await _reload();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final textPrimary = isLight ? AppTheme.lightTextPrimary : Colors.white;
    final textSecondary = isLight
        ? AppTheme.lightTextSecondary
        : Colors.white.withValues(alpha: 0.7);

    return Scaffold(
      backgroundColor: isLight
          ? const Color.fromARGB(255, 247, 251, 255)
          : const Color(0xFF060B11),
      body: Stack(
        children: [
          Positioned.fill(
            child: RefreshIndicator.noSpinner(
              onRefresh: _reload,
              onStatusChange: _onRefreshStatusChanged,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                    16, MediaQuery.of(context).padding.top + 70, 16, 16),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 24),
                    child: Text(
                      'AC Control Presets',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: textPrimary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  DashboardGlass(
                    radius: 20,
                    padding: const EdgeInsets.all(16),
                    tint: isLight ? Colors.white : const Color(0xFF10161D),
                    borderColor: Colors.transparent,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Site State',
                          style: TextStyle(
                            color: textPrimary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Current state: $_currentStateLabel',
                          style: TextStyle(color: textSecondary),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Default preset: $_defaultStateLabel',
                          style: TextStyle(color: textSecondary),
                        ),
                        if (_isRackConsoleMode) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Rack Console mode is active. Applying a preset will require the approving user PIN.',
                            style:
                                TextStyle(color: textSecondary, fontSize: 13),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_loading)
                    _buildLoadingSkeleton()
                  else if (_error != null)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Text(_error!,
                            style: TextStyle(color: textSecondary)),
                      ),
                    )
                  else if (!_canUseControlPresets)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          'Your account does not have permission to use control presets.',
                          style: TextStyle(color: textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else if (_live == null || _live!.writableRows.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          'Live AC control values are unavailable for this site.',
                          style: TextStyle(color: textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    ..._presetKeys.map((key) => Padding(
                          key: ValueKey(key),
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _PresetCardWidget(
                            key: ValueKey('card_$key'),
                            preset: _presets[key]!,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            isDefault: _defaultPresetKey == key,
                            isActive: _live != null &&
                                _doesPresetMatchLive(_presets[key]!, _live!),
                            isSaving: _saving,
                            onApply: () => _applyPreset(key),
                            onSaveCurrent: () => _saveCurrentToPreset(key),
                            onSetDefault: () => _setDefaultPreset(key),
                          ),
                        )),
                ],
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            child: IconButton(
              icon: Icon(
                Icons.arrow_back,
                color: textPrimary,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          HeaderRefreshBar(
            visible: _showRefreshBar,
            top: MediaQuery.of(context).padding.top + 62,
            horizontalInset: 16,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final cardTint = isLight ? Colors.white : const Color(0xFF10161D);
    const borderColor = Colors.transparent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DashboardGlass(
          radius: 20,
          padding: const EdgeInsets.all(16),
          tint: cardTint,
          borderColor: borderColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Skeleton(
                width: 120,
                height: 14,
                borderRadius: BorderRadius.circular(8),
              ),
              const SizedBox(height: 12),
              Skeleton(
                height: 12,
                borderRadius: BorderRadius.circular(8),
              ),
              const SizedBox(height: 8),
              Skeleton(
                height: 12,
                borderRadius: BorderRadius.circular(8),
              ),
              if (_isRackConsoleMode) ...[
                const SizedBox(height: 12),
                Skeleton(
                  width: 220,
                  height: 12,
                  borderRadius: BorderRadius.circular(8),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (var index = 0; index < _presetKeys.length; index++) ...[
          DashboardGlass(
            radius: 18,
            padding: const EdgeInsets.all(16),
            tint: cardTint,
            borderColor: borderColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Skeleton(
                        width: 140,
                        height: 18,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    Skeleton(
                      width: 72,
                      height: 22,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Skeleton(
                  height: 12,
                  borderRadius: BorderRadius.circular(8),
                ),
                const SizedBox(height: 8),
                Skeleton(
                  height: 12,
                  borderRadius: BorderRadius.circular(8),
                ),
                const SizedBox(height: 8),
                Skeleton(
                  height: 12,
                  borderRadius: BorderRadius.circular(8),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Skeleton(
                        height: 40,
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Skeleton(
                        height: 40,
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (index != _presetKeys.length - 1) const SizedBox(height: 14),
        ],
      ],
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _PresetCardWidget extends StatefulWidget {
  final _ControlPreset preset;
  final Color textPrimary;
  final Color textSecondary;
  final bool isDefault;
  final bool isActive;
  final bool isSaving;
  final VoidCallback onApply;
  final VoidCallback onSaveCurrent;
  final VoidCallback onSetDefault;

  const _PresetCardWidget({
    super.key,
    required this.preset,
    required this.textPrimary,
    required this.textSecondary,
    required this.isDefault,
    required this.isActive,
    required this.isSaving,
    required this.onApply,
    required this.onSaveCurrent,
    required this.onSetDefault,
  });

  @override
  State<_PresetCardWidget> createState() => _PresetCardWidgetState();
}

class _PresetCardWidgetState extends State<_PresetCardWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final hasValues = widget.preset.values.isNotEmpty;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final visibleValues = _isExpanded
        ? widget.preset.values
        : widget.preset.values.take(3).toList();

    return DashboardGlass(
      radius: 18,
      padding: const EdgeInsets.all(16),
      tint: isLight ? Colors.white : const Color(0xFF10161D),
      borderColor: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.preset.displayName,
                  style: TextStyle(
                    color: widget.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ),
              if (widget.isDefault) _badge('Default', const Color(0xFF007AFF)),
              if (widget.isActive) ...[
                const SizedBox(width: 8),
                _badge('Current', Theme.of(context).colorScheme.primary),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hasValues
                ? '${widget.preset.values.length} control values saved'
                : 'No saved values yet',
            style: TextStyle(color: widget.textSecondary),
          ),
          if (hasValues) ...[
            const SizedBox(height: 10),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOutCubic,
              alignment: Alignment.topCenter,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final value in visibleValues)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '${value.name.isNotEmpty ? value.name : value.metricCode}: ${value.value}${value.unit.isNotEmpty ? ' ${value.unit}' : ''}',
                        style: TextStyle(
                            color: widget.textSecondary, fontSize: 13),
                      ),
                    ),
                  if (widget.preset.values.length > 3)
                    InkWell(
                      onTap: () => setState(() => _isExpanded = !_isExpanded),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 4, horizontal: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _isExpanded
                                  ? 'Show Less'
                                  : 'View All Details (${widget.preset.values.length})',
                              style: TextStyle(
                                color: isLight
                                    ? AppTheme.lightTextPrimary
                                    : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              _isExpanded
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              size: 16,
                              color: isLight
                                  ? AppTheme.lightTextPrimary
                                  : Colors.white,
                            )
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton(
                onPressed:
                    widget.isSaving || !hasValues ? null : widget.onApply,
                child: const Text('Apply'),
              ),
              OutlinedButton(
                onPressed: widget.isSaving ? null : widget.onSaveCurrent,
                child: const Text('Save Current'),
              ),
              OutlinedButton(
                onPressed: widget.isSaving || !hasValues || widget.isDefault
                    ? null
                    : widget.onSetDefault,
                child: const Text('Set Default'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

const List<String> _presetKeys = ['preset_1', 'preset_2', 'preset_3'];

String _presetLabel(String presetKey) {
  switch (presetKey) {
    case 'preset_1':
      return 'Preset 1';
    case 'preset_2':
      return 'Preset 2';
    case 'preset_3':
      return 'Preset 3';
    default:
      return presetKey;
  }
}

int _acScore(Map<String, dynamic> r) {
  final name = (r['name'] ?? '').toString().toLowerCase();
  final typeName = (r['nodeTypeName'] ?? '').toString().toLowerCase();
  final typeCode = (r['nodeTypeCode'] ?? '').toString().toLowerCase();
  final typeId = int.tryParse(r['nodeTypeId']?.toString() ?? '');
  int s = 0;
  if (typeId == 15) s += 40;
  if (name == 'ac') s += 20;
  if (name.contains(' ac')) s += 16;
  if (name.contains('ac')) s += 12;
  if (name.contains('air')) s += 8;
  if (typeName == 'ac') s += 25;
  if (typeName.contains('ac')) s += 14;
  if (typeName.contains('air')) s += 8;
  if (typeCode.contains('ac')) s += 12;
  if (typeCode.contains('air')) s += 6;
  return s;
}

class _ControlPreset {
  const _ControlPreset({
    required this.presetKey,
    required this.displayName,
    required this.values,
  });

  final String presetKey;
  final String displayName;
  final List<_ControlPresetValue> values;

  factory _ControlPreset.empty(String presetKey) => _ControlPreset(
        presetKey: presetKey,
        displayName: _presetLabel(presetKey),
        values: const [],
      );

  factory _ControlPreset.fromJson(Map<String, dynamic> json) {
    final rawValues = (json['values'] as List?) ?? const [];
    return _ControlPreset(
      presetKey: json['preset_key']?.toString() ?? 'preset_1',
      displayName: json['display_name']?.toString() ??
          _presetLabel(json['preset_key']?.toString() ?? 'preset_1'),
      values: [
        for (final raw in rawValues)
          if (raw is Map)
            _ControlPresetValue.fromJson(
                Map<String, dynamic>.from(raw.cast<String, dynamic>())),
      ],
    );
  }
}

class _ControlPresetValue {
  const _ControlPresetValue({
    required this.metricCode,
    required this.value,
    required this.name,
    required this.unit,
  });

  final String metricCode;
  final String value;
  final String name;
  final String unit;

  factory _ControlPresetValue.fromJson(Map<String, dynamic> json) {
    return _ControlPresetValue(
      metricCode: json['metric_code']?.toString() ??
          json['metricCode']?.toString() ??
          '',
      value: json['value']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      unit: json['unit']?.toString() ?? '',
    );
  }
}

class _LiveControlSnapshot {
  const _LiveControlSnapshot({
    required this.nodeId,
    required this.rows,
  });

  final int nodeId;
  final List<_LiveControlRow> rows;

  List<_LiveControlRow> get writableRows =>
      rows.where((row) => row.write).toList();

  factory _LiveControlSnapshot.fromNodeWithMetric(Map<String, dynamic>? res) {
    if (res == null) return const _LiveControlSnapshot(nodeId: 0, rows: []);
    final r = res['result'];
    if (r is! Map) return const _LiveControlSnapshot(nodeId: 0, rows: []);
    final nodeId = int.tryParse(r['id']?.toString() ?? '') ?? 0;
    final metrics = (r['metrics'] as List?) ?? const [];
    return _LiveControlSnapshot(
      nodeId: nodeId,
      rows: [
        for (final raw in metrics)
          if (raw is Map)
            _LiveControlRow.fromJson(
                Map<String, dynamic>.from(raw.cast<String, dynamic>())),
      ],
    );
  }

  factory _LiveControlSnapshot.fromMetricList(
    Map<String, dynamic>? res, {
    required int fallbackNodeId,
    required String fallbackName,
  }) {
    if (res == null) return const _LiveControlSnapshot(nodeId: 0, rows: []);
    final result = res['result'];
    if (result is! Map) {
      return const _LiveControlSnapshot(nodeId: 0, rows: []);
    }
    final records = (result['records'] as List?) ?? const [];
    return _LiveControlSnapshot(
      nodeId: fallbackNodeId,
      rows: [
        for (final raw in records)
          if (raw is Map)
            _LiveControlRow.fromJson(
                Map<String, dynamic>.from(raw.cast<String, dynamic>())),
      ],
    );
  }
}

class _LiveControlRow {
  const _LiveControlRow({
    required this.metricCode,
    required this.name,
    required this.unit,
    required this.value,
    required this.write,
  });

  final String metricCode;
  final String name;
  final String unit;
  final String value;
  final bool write;

  factory _LiveControlRow.fromJson(Map<String, dynamic> json) {
    final rawValue = json['valueStr']?.toString().trim().isNotEmpty == true
        ? json['valueStr']
        : (json['value'] ?? json['val']);
    return _LiveControlRow(
      metricCode: (json['code'] ?? json['metricTypeLibCode'] ?? '').toString(),
      name: (json['name'] ?? json['desc'] ?? '').toString(),
      unit: (json['codeUnit'] ?? '').toString(),
      value: rawValue == null ? '--' : rawValue.toString().trim(),
      write: json['write'] == true || json['writable'] == true,
    );
  }

  Map<String, dynamic> toPresetJson() {
    return {
      'metric_code': metricCode,
      'value': value,
      'name': name,
      'unit': unit,
    };
  }
}
