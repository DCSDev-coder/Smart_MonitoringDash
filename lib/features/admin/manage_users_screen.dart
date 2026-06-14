import 'package:flutter/material.dart';
import '../../core/network/cpanel_api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/background_layer.dart';
import '../../shared/widgets/dashboard_glass.dart';
import '../../shared/widgets/secure_action_guard.dart';
import '../dashboard/widgets/dashboard_typography.dart';
import 'add_user_screen.dart';
import 'edit_user_screen.dart';
import '../../shared/utils/app_toast.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  bool _loading = false;
  List<dynamic> _members = [];

  int? _portalUserId;
  String? _adminPasswordSession;

  Map<String, dynamic>? get _currentSite =>
      CpanelApiService.instance.currentSite;

  bool _isTruthy(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;

    final normalized = value.toString().trim().toLowerCase();
    return normalized == '1' || normalized == 'true' || normalized == 'yes';
  }

  int? get _siteId {
    final site = _currentSite;
    if (site == null) return null;
    return int.tryParse(site['site_id']?.toString() ?? '') ??
        int.tryParse(site['id']?.toString() ?? '');
  }

  String? get _siteName {
    final site = _currentSite;
    return site?['site_name']?.toString();
  }

  bool get _canManageUsers {
    final site = _currentSite;
    if (site == null) return false;

    final ownerId = int.tryParse(site['owner_user_id']?.toString() ?? '');
    if (_portalUserId != null && ownerId != null && ownerId == _portalUserId) {
      return true;
    }

    final role = site['role']?.toString().toLowerCase();
    if (role == 'admin') return true;

    final v = site['can_manage_users'];
    return _isTruthy(v);
  }

  @override
  void initState() {
    super.initState();
    _bootstrapManageUsers();
  }

  Future<void> _bootstrapManageUsers() async {
    await _loadPortalUserId();
    if (!mounted) return;
    await _initAdminSessionAndLoad();
  }

  Future<void> _loadPortalUserId() async {
    final uid = await CpanelApiService.instance.getUserId();
    if (!mounted) return;
    setState(() => _portalUserId = uid);
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _initAdminSessionAndLoad() async {
    // Prefer in-memory portal password from the current login session.
    var pw = CpanelApiService.instance.getPortalPasswordInMemory();

    if (!mounted) return;
    setState(() =>
        _adminPasswordSession = (pw != null && pw.isNotEmpty) ? pw : null);

    // Member list should load without requiring the admin password.
    await _verifyAndLoadMembers();
  }

  Future<void> _verifyAndLoadMembers() async {
    if (_loading) return;
    if (!_canManageUsers) {
      AppToast.show(context, 'You do not have permission to manage users.');
      return;
    }

    final siteId = _siteId;
    if (siteId == null) {
      AppToast.show(context, 'Site context is missing. Please sign in again.');
      return;
    }

    final adminUsername = await CpanelApiService.instance.getUsername();
    if (!mounted) return;
    if (adminUsername == null || adminUsername.isEmpty) {
      AppToast.show(context,
          'Your admin username is not available. Please sign in again.');
      return;
    }

    setState(() => _loading = true);
    final res = await CpanelApiService.instance.fetchSiteMembers(
      siteId: siteId,
      // Listing members should not require re-entering the admin password.
      // The backend authorizes using the Bearer token (portal session) plus
      // site_members permissions.
      adminUsername: adminUsername,
    );

    if (!mounted) return;

    final status =
        (res is Map<String, dynamic>) ? res['status']?.toString() : null;
    if (status != 'success') {
      final msg = (res is Map<String, dynamic>)
          ? (res['message']?.toString() ?? 'Failed to load members.')
          : 'Failed to load members.';
      setState(() {
        _loading = false;
        _members = [];
      });
      AppToast.show(context, msg);
      return;
    }

    final members =
        (res?['members'] is List) ? (res?['members'] as List) : <dynamic>[];
    setState(() {
      _loading = false;
      _members = members;
    });
  }

  Future<String?> _promptAdminPasswordIfMissing() async {
    final cached = _adminPasswordSession;
    if (cached != null && cached.isNotEmpty) return cached;

    final pw = await showGeneralDialog<String?>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      // Dark mode: keep the overlay solid/dim (no white haze).
      barrierColor: Theme.of(context).brightness == Brightness.light
          ? Colors.white.withValues(alpha: 0.60)
          : Colors.black,
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (ctx, __, ___) {
        final w = MediaQuery.of(ctx).size.width;
        final maxW = (w - 32).clamp(300.0, 420.0);
        return _AdminPasswordDialog(maxWidth: maxW);
      },
      transitionBuilder: (ctx, anim, __, child) {
        final curved =
            CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(curved),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
              child: child,
            ),
          ),
        );
      },
    );

    final cleaned = pw?.trim();
    if (cleaned == null || cleaned.isEmpty) return null;
    setState(() => _adminPasswordSession = cleaned);
    return cleaned;
  }

  Future<void> _deleteMember({
    required int memberUserId,
    required String username,
    required String role,
  }) async {
    final authorized = await SecureActionGuard.ensureAuthorized(
      context,
      reason: 'Please authenticate to remove member.',
    );
    if (!authorized) return;
    if (!mounted) return;

    final adminUsername = await CpanelApiService.instance.getUsername();
    if (!mounted) return;
    final siteId = _siteId;

    if (adminUsername == null || adminUsername.isEmpty || siteId == null) {
      AppToast.show(
          context, 'Missing admin or site context. Please sign in again.');
      return;
    }

    final adminPassword = await _promptAdminPasswordIfMissing();
    if (!mounted) return;
    if (adminPassword == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isLight = Theme.of(ctx).brightness == Brightness.light;
        return Material(
          type: MaterialType.transparency,
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: isLight
                          ? const Color(0xFFD7D7D7)
                          : const Color(0xFFFF2B2B).withValues(alpha: 0.32),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isLight
                            ? Colors.black.withValues(alpha: 0.08)
                            : const Color(0xFFFF2B2B).withValues(alpha: 0.18),
                        blurRadius: isLight ? 18 : 26,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: DashboardGlass(
                    radius: 26,
                    padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                    tint: isLight
                        ? const Color(0xFFF3F3F3)
                        : const Color(0xFF2A0508).withValues(alpha: 0.80),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Remove Member',
                          style: bitcount(
                            ctx,
                            fontSize: 18,
                            color: isLight
                                ? const Color(0xFF101010)
                                : const Color(0xFFFF4A4A),
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Are you sure to remove ($username)?',
                          style: TextStyle(
                            color: isLight
                                ? const Color(0xFF222222)
                                : Colors.white.withValues(alpha: 0.82),
                            fontSize: 13,
                            height: 1.3,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 48,
                                child: FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: isLight
                                        ? const Color(0xFFE6E6E6)
                                        : Colors.white.withValues(alpha: 0.10),
                                    foregroundColor: isLight
                                        ? const Color(0xFF111111)
                                        : Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                      side: BorderSide(
                                        color: isLight
                                            ? const Color(0xFFD0D0D0)
                                            : Colors.white
                                                .withValues(alpha: 0.12),
                                      ),
                                    ),
                                  ),
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text(
                                    'Cancel',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SizedBox(
                                height: 48,
                                child: FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFFB30000),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                  ),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text(
                                    'Remove',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    if (confirm != true) return;

    setState(() => _loading = true);
    final res = await CpanelApiService.instance.removeSiteMember(
      siteId: siteId,
      adminUsername: adminUsername,
      adminPassword: adminPassword,
      memberUserId: memberUserId,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    final status = res?['status']?.toString();
    final ok = status == 'success';
    if (ok) {
      await _verifyAndLoadMembers();
      if (!mounted) return;
      AppToast.show(context, 'Member removed.');
    } else {
      final msg = res?['message']?.toString() ??
          'Failed to remove member. Make sure `remove_site_member` is enabled on the backend and try again.';
      AppToast.showError(context, msg);
    }
  }

  Future<void> _editMember(Map<String, dynamic> member) async {
    final authorized = await SecureActionGuard.ensureAuthorized(
      context,
      reason: 'Please authenticate to edit member.',
    );
    if (!authorized) return;
    if (!mounted) return;

    final adminUsername = await CpanelApiService.instance.getUsername();
    if (!mounted) return;
    final siteId = _siteId;

    final memberUserId = int.tryParse(member['user_id']?.toString() ?? '');
    final username = member['username']?.toString() ?? 'user';

    if (adminUsername == null ||
        adminUsername.isEmpty ||
        siteId == null ||
        memberUserId == null) {
      AppToast.show(
          context, 'Missing admin/site/member info. Please sign in again.');
      return;
    }

    bool flag(String key, {required bool defaultValue}) {
      final v = member[key];
      if (v == null) return defaultValue;
      if (v is bool) return v;
      if (v is num) return v != 0;
      final s = v.toString().trim().toLowerCase();
      if (s == '1' || s == 'true' || s == 'yes') return true;
      if (s == '0' || s == 'false' || s == 'no') return false;
      return defaultValue;
    }

    bool canViewDashboard = flag('can_view_dashboard', defaultValue: true);
    bool canViewReport = flag('can_view_report', defaultValue: false);
    bool canViewRack = flag('can_view_rack', defaultValue: false);
    bool canViewControl = flag('can_view_control', defaultValue: false);
    bool canControlDoors = flag('can_control_doors', defaultValue: false);
    bool canChangeSettings = flag('can_change_settings', defaultValue: false);
    bool canManageUsers = flag('can_manage_users', defaultValue: false);
    bool isRackConsole = flag('is_kiosk', defaultValue: false);

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditUserScreen(
          username: username,
          siteId: siteId,
          memberUserId: memberUserId,
          adminUsername: adminUsername,
          canViewDashboard: canViewDashboard,
          canViewReport: canViewReport,
          canViewRack: canViewRack,
          canViewControl: canViewControl,
          canControlDoors: canControlDoors,
          canChangeSettings: canChangeSettings,
          canManageUsers: canManageUsers,
          isRackConsole: isRackConsole,
        ),
      ),
    );

    if (saved == true) {
      await _verifyAndLoadMembers();
      if (!mounted) return;
      AppToast.show(context, 'Member updated.');
    }
  }

  Future<void> _showAddUserDialog() async {
    final adminUsername = await CpanelApiService.instance.getUsername();
    if (!mounted) return;
    final siteId = _siteId;

    if (adminUsername == null || adminUsername.isEmpty || siteId == null) {
      AppToast.show(
          context, 'Missing admin or site context. Please sign in again.');
      return;
    }

    final adminPassword = await _promptAdminPasswordIfMissing();
    if (!mounted) return;
    if (adminPassword == null) return;
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddUserScreen(
          siteId: siteId,
          adminUsername: adminUsername,
          adminPassword: adminPassword,
        ),
      ),
    );

    if (created == true) {
      await _verifyAndLoadMembers();
      if (!mounted) return;
      AppToast.showSuccess(context, 'User created successfully.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screenWidth = media.size.width;
    final uiScale =
        screenWidth >= 900 ? (screenWidth / 1150).clamp(1.0, 1.25) : 1.0;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final siteName = _siteName ?? 'Site';
    final topPad = media.padding.top;

    return MediaQuery(
      data: media.copyWith(textScaler: TextScaler.linear(uiScale)),
      child: Scaffold(
        backgroundColor: isLight
            ? const Color.fromARGB(255, 247, 251, 255)
            : const Color(0xFF060B11),
        body: TickerMode(
          enabled: ModalRoute.of(context)?.isCurrent ?? true,
          child: Stack(
            children: [
              if (!isLight)
                const Positioned.fill(
                  child: BackgroundLayer(
                    channel: BackgroundChannel.app,
                    overlayAlpha: 0.74,
                    staticForApp: true,
                  ),
                ),

              Positioned.fill(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(16, topPad + 70, 16, 96),
                  children: [
                    Text(
                      'Manage Users',
                      style: TextStyle(
                        color:
                            isLight ? AppTheme.lightTextPrimary : Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      siteName.toUpperCase(),
                      style: TextStyle(
                        color: isLight
                            ? AppTheme.lightTextPrimary
                            : Colors.white.withValues(alpha: 0.75),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.6,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildMembersCard(),
                  ],
                ),
              ),
              if (_canManageUsers)
                Positioned(
                  right: 16,
                  bottom: 24,
                  child: SizedBox(
                    height: 44,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: isLight
                            ? Theme.of(context).colorScheme.primary
                            : const Color(0xFF0A8F2A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        elevation: isLight ? 0 : null,
                      ),
                      onPressed: _loading ? null : _showAddUserDialog,
                      icon:
                          const Icon(Icons.person_add_alt_1_rounded, size: 18),
                      label: const Text(
                        'Add Users',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: topPad + 10,
                left: 16,
                child: IconButton(
                  icon: Icon(
                    Icons.arrow_back,
                    color: isLight ? AppTheme.lightTextPrimary : Colors.white,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMembersCard() {
    final isLight = Theme.of(context).brightness == Brightness.light;
    if (!_canManageUsers) {
      return _infoCard(
        title: 'No Access',
        body: 'Your account does not have permission to manage site users.',
      );
    }

    final ownerId = int.tryParse(
      (CpanelApiService.instance.currentSite?['owner_user_id'] ?? '')
          .toString(),
    );

    // Show all members, including the currently logged-in admin.
    // The _memberRow widget handles hiding the edit/delete buttons for self/owner.
    final visibleMembers = _members.where((m) {
      if (m is! Map) return false;
      return true;
    }).toList();

    // Sort priority: Owner (0) > Admin (1) > Rack Console (2) > User (3)
    visibleMembers.sort((a, b) {
      int getWeight(dynamic m) {
        if (m is! Map) return 99;
        final uid = int.tryParse(m['user_id']?.toString() ?? '');
        if (ownerId != null && uid == ownerId) return 0;
        
        final role = m['role']?.toString().toLowerCase() ?? 'user';
        if (role == 'admin') return 1;
        
        final v = m['is_kiosk'];
        bool isKiosk = false;
        if (v is bool) {
          isKiosk = v;
        } else if (v is num) {
          isKiosk = v != 0;
        } else if (v != null) {
          final s = v.toString().trim().toLowerCase();
          isKiosk = s == '1' || s == 'true' || s == 'yes';
        }
        
        if (isKiosk) return 2;
        return 3;
      }
      
      final wA = getWeight(a);
      final wB = getWeight(b);
      if (wA != wB) return wA.compareTo(wB);
      
      final nameA = (a is Map ? a['username']?.toString() ?? a['member_username']?.toString() ?? '' : '').toLowerCase();
      final nameB = (b is Map ? b['username']?.toString() ?? b['member_username']?.toString() ?? '' : '').toLowerCase();
      return nameA.compareTo(nameB);
    });

    if (visibleMembers.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: isLight
              ? const Color(0xFFE7E7E7)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(18),
        ),
        padding: const EdgeInsets.fromLTRB(28, 18, 28, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No members loaded',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: isLight ? AppTheme.lightTextPrimary : Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _adminPasswordSession == null
                  ? 'No additional members found for this site yet.'
                  : 'No additional members found for this site yet.',
              style: TextStyle(
                color: isLight
                    ? AppTheme.lightTextSecondary
                    : Colors.white.withValues(alpha: 0.65),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    final adminsList = <dynamic>[];
    final kiosksList = <dynamic>[];
    final usersList = <dynamic>[];

    for (var m in visibleMembers) {
      if (m is! Map) continue;
      final uid = int.tryParse(m['user_id']?.toString() ?? '');
      if (ownerId != null && uid == ownerId) {
        adminsList.add(m);
        continue;
      }
      final role = m['role']?.toString().toLowerCase() ?? 'user';
      if (role == 'admin') {
        adminsList.add(m);
        continue;
      }
      
      final v = m['is_kiosk'];
      bool isKiosk = false;
      if (v is bool) isKiosk = v;
      else if (v is num) isKiosk = v != 0;
      else if (v != null) {
        final s = v.toString().trim().toLowerCase();
        isKiosk = s == '1' || s == 'true' || s == 'yes';
      }
      
      if (isKiosk) {
        kiosksList.add(m);
      } else {
        usersList.add(m);
      }
    }

    Widget buildSection(String title, List<dynamic> list) {
      if (list.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: DashboardGlass(
          radius: 18,
          padding: const EdgeInsets.all(16),
          tint: isLight
              ? const Color(0xFFFFFFFF)
              : Colors.white.withValues(alpha: 0.06),
          borderColor: isLight ? AppTheme.lightStroke : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  color: isLight
                      ? AppTheme.lightTextSecondary
                      : Colors.white.withValues(alpha: 0.65),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              ...list.map((m) => _memberRow(m)),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildSection('Owner & Admins', adminsList),
        buildSection('Rack Consoles', kiosksList),
        buildSection('Users', usersList),
      ],
    );
  }

  Widget _memberRow(dynamic member) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final map = (member is Map) ? member : <String, dynamic>{};

    final username = map['username']?.toString() ??
        map['member_username']?.toString() ??
        'user';
    final role = map['role']?.toString() ?? 'user';

    final memberUserId = int.tryParse(map['user_id']?.toString() ?? '');
    final ownerId = int.tryParse(
      (CpanelApiService.instance.currentSite?['owner_user_id'] ?? '')
          .toString(),
    );
    final isOwner =
        ownerId != null && memberUserId != null && ownerId == memberUserId;
    final isSelf = _portalUserId != null &&
        memberUserId != null &&
        _portalUserId == memberUserId;
    final isAdminRole = role.toLowerCase() == 'admin';
    final canDelete =
        memberUserId != null && !isOwner && !isSelf && !isAdminRole;
    final canEdit = memberUserId != null && !isOwner && !isSelf;

    bool flag(String key) {
      final v = map[key];
      if (v == null) return false;
      if (v is bool) return v;
      if (v is num) return v != 0;
      final s = v.toString().trim().toLowerCase();
      return s == '1' || s == 'true' || s == 'yes';
    }

    final isKiosk = flag('is_kiosk');

    final chips = isKiosk
        ? <Widget>[
            _permChip('RACK CONSOLE', true),
          ]
        : <Widget>[
            _permChip('HOME', flag('can_view_dashboard')),
            _permChip('REPORT', flag('can_view_report')),
            _permChip('POWER', flag('can_view_rack')),
            _permChip('CONTROL', flag('can_view_control')),
            _permChip('DOORS', flag('can_control_doors')),
            _permChip('SETTINGS', flag('can_change_settings')),
            _permChip('USERS', flag('can_manage_users')),
          ];

    Color getTint() {
      if (isOwner) return isLight ? const Color(0xFFFFF8E1) : const Color(0xFF1E1A0F);
      if (isAdminRole) return isLight ? const Color(0xFFE3F2FD) : const Color(0xFF0C1929);
      if (isKiosk) return isLight ? const Color(0xFFF3E5F5) : const Color(0xFF1A1224);
      return isLight ? const Color(0xFFF7F7F7) : Colors.white.withValues(alpha: 0.05);
    }

    Color? getBorder() {
      if (isOwner) return isLight ? const Color(0xFFFFE082) : const Color(0xFFFFC107).withValues(alpha: 0.3);
      if (isAdminRole) return isLight ? const Color(0xFF90CAF9) : const Color(0xFF2196F3).withValues(alpha: 0.3);
      if (isKiosk) return isLight ? const Color(0xFFCE93D8) : const Color(0xFFAB47BC).withValues(alpha: 0.3);
      return isLight ? AppTheme.lightStroke : null;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DashboardGlass(
        radius: 16,
        padding: const EdgeInsets.all(14),
        tint: getTint(),
        borderColor: getBorder(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person_outline_rounded,
                    color: isLight
                        ? AppTheme.lightTextSecondary
                        : Colors.white.withValues(alpha: 0.70),
                    size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    username,
                    style: TextStyle(
                      color: isLight ? AppTheme.lightTextPrimary : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (role.toLowerCase() == 'admin'
                            ? Theme.of(context).colorScheme.primary
                            : const Color(0xFF2D7DFF))
                        .withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    isOwner ? 'OWNER' : (isSelf ? 'YOU' : role.toUpperCase()),
                    style: TextStyle(
                      color: role.toLowerCase() == 'admin'
                          ? Theme.of(context).colorScheme.primary
                          : const Color(0xFF2D7DFF),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                if (canDelete) ...[
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: 'Remove member',
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: Color(0xFFFF3B30), size: 20),
                    onPressed: _loading
                        ? null
                        : () => _deleteMember(
                              memberUserId: memberUserId,
                              username: username,
                              role: role,
                            ),
                  ),
                ],
                if (canEdit) ...[
                  const SizedBox(width: 2),
                  IconButton(
                    tooltip: 'Edit permissions',
                    icon: Icon(Icons.edit_outlined,
                        color:
                            isLight ? const Color(0xFF5E6673) : Colors.white70,
                        size: 20),
                    onPressed: _loading
                        ? null
                        : () => _editMember(Map<String, dynamic>.from(map)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: chips),
          ],
        ),
      ),
    );
  }

  Widget _permChip(String label, bool enabled) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: enabled
            ? Theme.of(context).colorScheme.primary.withValues(alpha: isLight ? 0.18 : 0.16)
            : isLight
                ? const Color(0xFFD9DEE6)
                : Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: isLight && !enabled
            ? Border.all(color: const Color(0xFFC5CCD8))
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: enabled
              ? Theme.of(context).colorScheme.primary
              : isLight
                  ? const Color(0xFF606A78)
                  : Colors.white54,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _infoCard({required String title, required String body}) {
    return DashboardGlass(
      radius: 18,
      padding: const EdgeInsets.all(16),
      tint: Colors.white.withValues(alpha: 0.06),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminPasswordDialog extends StatefulWidget {
  final double maxWidth;

  const _AdminPasswordDialog({required this.maxWidth});

  @override
  State<_AdminPasswordDialog> createState() => _AdminPasswordDialogState();
}

class _AdminPasswordDialogState extends State<_AdminPasswordDialog> {
  final TextEditingController _ctrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return SafeArea(
      child: Center(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: widget.maxWidth),
            child: Material(
              type: MaterialType.transparency,
              child: DashboardGlass(
                radius: 22,
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                tint:
                    isLight ? const Color(0xFFFFFFFF) : const Color(0xFF060B11),
                borderColor: isLight
                    ? AppTheme.lightStroke
                    : Colors.white.withValues(alpha: 0.10),
                blurSigma: 6,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ADMIN PASSWORD',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: bitcount(
                        context,
                        fontSize: 16,
                        color:
                            isLight ? AppTheme.lightTextPrimary : Colors.white,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Enter admin password to continue.',
                      style: TextStyle(
                        color: isLight
                            ? AppTheme.lightTextSecondary
                            : Colors.white.withValues(alpha: 0.70),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _ctrl,
                      obscureText: _obscure,
                      autofocus: true,
                      style: TextStyle(
                        color:
                            isLight ? AppTheme.lightTextPrimary : Colors.white,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Admin password',
                        hintStyle: TextStyle(
                          color: isLight
                              ? AppTheme.lightTextSecondary
                              : Colors.white.withValues(alpha: 0.45),
                        ),
                        filled: true,
                        fillColor: isLight
                            ? const Color(0xFFF4F6FA)
                            : Colors.white.withValues(alpha: 0.06),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: isLight
                                ? AppTheme.lightStroke
                                : Colors.white.withValues(alpha: 0.18),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: isLight
                                ? AppTheme.lightStroke
                                : Colors.white.withValues(alpha: 0.18),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 1.4,
                          ),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure ? Icons.visibility_off : Icons.visibility,
                            color: isLight
                                ? AppTheme.lightTextSecondary
                                : Colors.white.withValues(alpha: 0.75),
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      onSubmitted: (_) =>
                          Navigator.pop(context, _ctrl.text.trim()),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 42,
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(context, null),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isLight
                                    ? const Color(0xFFF1F3F6)
                                    : Colors.white.withValues(alpha: 0.10),
                                foregroundColor: isLight
                                    ? AppTheme.lightTextPrimary
                                    : Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(
                                    color: isLight
                                        ? AppTheme.lightStroke
                                        : Colors.white.withValues(alpha: 0.10),
                                  ),
                                ),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 42,
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(
                                context,
                                _ctrl.text.trim(),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                'Continue',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
