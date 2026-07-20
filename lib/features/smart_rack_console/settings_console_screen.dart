import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../shared/utils/app_toast.dart';
import '../../shared/widgets/secure_action_guard.dart';
import 'services/rack_console_update_service.dart';
import 'theme/console_theme.dart';
import 'widgets/console_section_card.dart';

class SettingsConsoleScreen extends StatefulWidget {
  const SettingsConsoleScreen({
    super.key,
    required this.compact,
  });

  final bool compact;

  @override
  State<SettingsConsoleScreen> createState() => _SettingsConsoleScreenState();
}

class _SettingsConsoleScreenState extends State<SettingsConsoleScreen> {
  final TextEditingController _ipController =
      TextEditingController(text: '192.168.1.100');
  final TextEditingController _subnetController =
      TextEditingController(text: '255.255.255.0');
  final TextEditingController _gatewayController =
      TextEditingController(text: '192.168.1.1');
  final RackConsoleUpdateService _updateService = RackConsoleUpdateService();
  bool _isIpConfigHidden = true;
  bool _checkingUpdate = false;
  bool _downloadingUpdate = false;
  bool _installingUpdate = false;
  RackConsoleUpdateStatus? _updateStatus;
  String? _updateMessage;

  @override
  void initState() {
    super.initState();
    _loadCurrentVersion();
  }

  @override
  void dispose() {
    _ipController.dispose();
    _subnetController.dispose();
    _gatewayController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentVersion() async {
    try {
      final status = await _updateService.currentStatus();
      if (!mounted) return;
      setState(() {
        _updateStatus = status;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _updateMessage = 'Unable to read installed version.';
      });
    }
  }

  Future<void> _checkForUpdates() async {
    if (AppConfig.updateManifestUrl.isEmpty) {
      setState(() {
        _updateMessage =
            'Update URL is not configured. Add UPDATE_MANIFEST_URL at build time.';
      });
      AppToast.showError(context, 'Update URL is not configured.');
      return;
    }

    setState(() {
      _checkingUpdate = true;
      _updateMessage = 'Checking latest version...';
    });
    try {
      final status = await _updateService.checkForUpdate();
      if (!mounted) return;
      setState(() {
        _updateStatus = status;
        _updateMessage = status.hasUpdate
            ? 'Update available: ${status.latest!.versionName}'
            : 'This rack console is up to date.';
      });
      AppToast.show(
        context,
        status.hasUpdate ? 'Update available.' : 'Already up to date.',
      );
    } catch (e) {
      if (!mounted) return;
      final message = _updateErrorMessage(e);
      setState(() {
        _updateMessage = message;
      });
      AppToast.showError(context, message);
    } finally {
      if (mounted) {
        setState(() {
          _checkingUpdate = false;
        });
      }
    }
  }

  Future<void> _downloadUpdate() async {
    final status = _updateStatus;
    if (status == null || !status.hasUpdate) {
      await _checkForUpdates();
      return;
    }

    setState(() {
      _downloadingUpdate = true;
      _updateMessage = 'Downloading update package...';
    });
    try {
      final downloaded = await _updateService.downloadUpdate(status);
      if (!mounted) return;
      setState(() {
        _updateStatus = downloaded;
        _updateMessage = 'Update downloaded. Ready to install.';
      });
      AppToast.showSuccess(context, 'Update downloaded.');
    } catch (e) {
      if (!mounted) return;
      final message = _updateErrorMessage(e);
      setState(() {
        _updateMessage = message;
      });
      AppToast.showError(context, message);
    } finally {
      if (mounted) {
        setState(() {
          _downloadingUpdate = false;
        });
      }
    }
  }

  Future<void> _installUpdate() async {
    final status = _updateStatus;
    if (status?.downloadedApkPath == null) {
      await _downloadUpdate();
      return;
    }

    setState(() {
      _installingUpdate = true;
      _updateMessage = 'Opening Android installer...';
    });
    try {
      await _updateService.installDownloadedUpdate(status!);
      if (!mounted) return;
      setState(() {
        _updateMessage = 'Follow the Android install prompt to finish.';
      });
    } catch (e) {
      if (!mounted) return;
      final message = _updateErrorMessage(e);
      setState(() {
        _updateMessage = message;
      });
      AppToast.showError(context, message);
    } finally {
      if (mounted) {
        setState(() {
          _installingUpdate = false;
        });
      }
    }
  }

  String _updateErrorMessage(Object error) {
    if (error is RackConsoleUpdateException) return error.message;
    final raw = error.toString();
    if (raw.contains('REQUEST_INSTALL_PACKAGES') ||
        raw.contains('permission')) {
      return 'Android install permission is required for this app.';
    }
    if (raw.contains('Unsupported')) {
      return 'APK installation is only available on Android.';
    }
    return 'Update failed. Please try again.';
  }

  Future<void> _handleUpdateAction() async {
    if (_checkingUpdate || _downloadingUpdate || _installingUpdate) return;
    final status = _updateStatus;
    if (status?.downloadedApkPath != null) {
      await _installUpdate();
    } else if (status?.hasUpdate == true) {
      await _downloadUpdate();
    } else {
      await _checkForUpdates();
    }
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    final isDark = ConsoleTheme.isDark(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: ConsoleTheme.textSecondary(context),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          style: TextStyle(color: ConsoleTheme.textPrimary(context)),
          decoration: InputDecoration(
            filled: true,
            fillColor: isDark
                ? const Color(0xFF0F2648).withValues(alpha: 0.5)
                : const Color(0xFFF1F5F9),
            suffixIcon: suffixIcon,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(
                color: isDark
                    ? ConsoleTheme.divider(context)
                    : const Color(0xFFCBD5E1),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(
                color: isDark
                    ? ConsoleTheme.divider(context)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: ConsoleTheme.primaryBlue(context)),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildIpConfiguration() {
    Widget buildEyeIcon() {
      return IconButton(
        icon: Icon(
          _isIpConfigHidden ? Icons.visibility_off : Icons.visibility,
          color: ConsoleTheme.textSecondary(context),
          size: 20,
        ),
        onPressed: () async {
          if (_isIpConfigHidden) {
            final ok = await SecureActionGuard.ensureAuthorized(
              context,
              reason: 'View IP Configuration',
            );
            if (ok == true) {
              setState(() {
                _isIpConfigHidden = false;
              });
            }
          } else {
            setState(() {
              _isIpConfigHidden = true;
            });
          }
        },
      );
    }

    return ConsoleSectionCard(
      title: 'IP Configuration',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              SizedBox(
                width: 250,
                child: _buildTextField(
                  'IP Address',
                  _ipController,
                  obscureText: _isIpConfigHidden,
                  suffixIcon: buildEyeIcon(),
                ),
              ),
              SizedBox(
                width: 250,
                child: _buildTextField(
                  'Subnet Mask',
                  _subnetController,
                  obscureText: _isIpConfigHidden,
                  suffixIcon: buildEyeIcon(),
                ),
              ),
              SizedBox(
                width: 250,
                child: _buildTextField(
                  'Gateway',
                  _gatewayController,
                  obscureText: _isIpConfigHidden,
                  suffixIcon: buildEyeIcon(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: ConsoleTheme.primaryBlue(context),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
              ),
              onPressed: () {},
              child: const Text('Save Configuration'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isLink = false}) {
    final isDark = ConsoleTheme.isDark(context);
    final linkColor =
        isDark ? ConsoleTheme.cyan(context) : ConsoleTheme.primaryBlue(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: ConsoleTheme.textSecondary(context),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: isLink ? linkColor : ConsoleTheme.textPrimary(context),
              decoration:
                  isLink ? TextDecoration.underline : TextDecoration.none,
              decorationColor: linkColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateControls() {
    final status = _updateStatus;
    final isBusy = _checkingUpdate || _downloadingUpdate || _installingUpdate;
    final current = status?.currentVersion;
    final latest = status?.latest;
    final buttonLabel = isBusy
        ? (_checkingUpdate
            ? 'Checking...'
            : _downloadingUpdate
                ? 'Downloading...'
                : 'Opening Installer...')
        : status?.downloadedApkPath != null
            ? 'Install Update'
            : status?.hasUpdate == true
                ? 'Download Update'
                : 'Check For Updates';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow(
          'Cabinet Screen Version:',
          current == null
              ? 'Reading installed version...'
              : '${current.versionName} (${current.versionCode})',
        ),
        _buildInfoRow('Platform Version:', 'Android APK'),
        if (latest != null)
          _buildInfoRow(
            'Latest Version:',
            '${latest.versionName} (${latest.versionCode})',
          ),
        if (latest != null && latest.releaseNotes.isNotEmpty) ...[
          Text(
            'Release Notes:',
            style: TextStyle(
              color: ConsoleTheme.textSecondary(context),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          ...latest.releaseNotes.take(4).map(
                (note) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '- $note',
                    style: TextStyle(
                      color: ConsoleTheme.textPrimary(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
          const SizedBox(height: 12),
        ],
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: ConsoleTheme.primaryBlue(context),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
          onPressed: isBusy ? null : () => _handleUpdateAction(),
          child: Text(buttonLabel),
        ),
        const SizedBox(height: 8),
        Text(
          _updateMessage ?? '(Check And Update Cabinet Screen Version)',
          style: TextStyle(
            color: ConsoleTheme.textSecondary(context),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildAboutContent() {
    final col1 = Expanded(
      flex: 5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow(
              'Official Website:', 'https://datacenterspecialists.com',
              isLink: true),
          _buildInfoRow('Contact Us:', '+603-7800 0511'),
          const SizedBox(height: 24),
          _buildUpdateControls(),
        ],
      ),
    );

    final col2 = Expanded(
      flex: 3,
      child: Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 48.0),
          child: SizedBox(
            height: 160,
            child: Image.asset(
              'assets/DCS_Logo/untitled_design.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );

    if (widget.compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow(
              'Official Website:', 'https://datacenterspecialists.com',
              isLink: true),
          _buildInfoRow('Contact Us:', '+603-7800 0511'),
          const SizedBox(height: 16),
          _buildUpdateControls(),
          const SizedBox(height: 32),
          Center(
            child: SizedBox(
              height: 160,
              child: Image.asset(
                'assets/DCS_Logo/untitled_design.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        col1,
        const SizedBox(width: 32),
        col2,
      ],
    );
  }

  Widget _buildAboutUs() {
    return ConsoleSectionCard(
      title: 'About Us',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Related Information:',
              style: TextStyle(
                  color: ConsoleTheme.textPrimary(context),
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          _buildAboutContent(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: ConsoleTheme.pageBgGradient(context),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(ConsoleTheme.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Settings & Configuration',
                style: TextStyle(
                    color: ConsoleTheme.textPrimary(context),
                    fontSize: 24,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            _buildIpConfiguration(),
            const SizedBox(height: 24),
            _buildAboutUs(),
          ],
        ),
      ),
    );
  }
}
