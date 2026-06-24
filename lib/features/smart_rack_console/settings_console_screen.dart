import 'package:flutter/material.dart';

import '../../core/network/cpanel_api_service.dart';
import '../../shared/widgets/safe_network_image.dart';
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
  final TextEditingController _ipController = TextEditingController(text: '192.168.1.100');
  final TextEditingController _subnetController = TextEditingController(text: '255.255.255.0');
  final TextEditingController _gatewayController = TextEditingController(text: '192.168.1.1');

  @override
  void dispose() {
    _ipController.dispose();
    _subnetController.dispose();
    _gatewayController.dispose();
    super.dispose();
  }

  String? _companyLogoUrl() {
    final site = CpanelApiService.instance.currentSite;
    if (site == null) return null;
    final logo = site['company_logo_path']?.toString() ?? '';
    if (logo.trim().isEmpty) return null;
    return '${CpanelApiService.baseAssetUrl}$logo';
  }

  Widget _buildDcsLogo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('DCS', style: TextStyle(color: ConsoleTheme.cyan(context), fontSize: 64, fontWeight: FontWeight.bold, letterSpacing: 2)),
            const SizedBox(width: 8),
            const Icon(Icons.copyright, color: Colors.redAccent, size: 20),
          ],
        ),
        const Text('DATA CENTER SPECIALISTS', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: ConsoleTheme.textSecondary(context))),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: TextStyle(color: ConsoleTheme.textPrimary(context)),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF0F2648).withValues(alpha: 0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: ConsoleTheme.divider(context)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: ConsoleTheme.divider(context)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: ConsoleTheme.primaryBlue(context)),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildIpConfiguration() {
    return ConsoleSectionCard(
      title: 'IP Configuration',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              SizedBox(width: 250, child: _buildTextField('IP Address', _ipController)),
              SizedBox(width: 250, child: _buildTextField('Subnet Mask', _subnetController)),
              SizedBox(width: 250, child: _buildTextField('Gateway', _gatewayController)),
            ],
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: ConsoleTheme.primaryBlue(context),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: ConsoleTheme.textSecondary(context), fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            value, 
            style: TextStyle(
              color: isLink ? ConsoleTheme.cyan(context) : ConsoleTheme.textPrimary(context), 
              decoration: isLink ? TextDecoration.underline : TextDecoration.none,
              decorationColor: ConsoleTheme.cyan(context),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutContent() {
    final col1 = Expanded(
      flex: 5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Official Website:', 'https://datacenterspecialists.com', isLink: true),
          _buildInfoRow('Contact Us:', '+603-7800 0511'),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ConsoleTheme.primaryBlue(context),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            onPressed: () {},
            child: const Text('Check For Updates'),
          ),
          const SizedBox(height: 8),
          Text('(Check And Update Cabinet Screen Version)', style: TextStyle(color: ConsoleTheme.textSecondary(context), fontSize: 11)),
        ],
      ),
    );

    final col2 = Expanded(
      flex: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Cabinet Screen Version:', 'V1.0.10-3'),
          _buildInfoRow('Platform Version:', '1.0.12-5'),
        ],
      ),
    );

    final logoUrl = _companyLogoUrl();
    final col3 = Expanded(
      flex: 3,
      child: Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 48.0),
          child: logoUrl != null && logoUrl.isNotEmpty
              ? SizedBox(
                  height: 160,
                  child: SafeNetworkImage(
                    logoUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context) => _buildDcsLogo(),
                  ),
                )
              : SizedBox(
                  height: 160,
                  child: Center(child: _buildDcsLogo()),
                ),
        ),
      ),
    );

    if (widget.compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Official Website:', 'https://datacenterspecialists.com', isLink: true),
          _buildInfoRow('Contact Us:', '+603-7800 0511'),
          const SizedBox(height: 16),
          _buildInfoRow('Cabinet Screen Version:', 'V1.0.10-3'),
          _buildInfoRow('Platform Version:', '1.0.12-5'),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ConsoleTheme.primaryBlue(context),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            onPressed: () {},
            child: const Text('Check For Updates'),
          ),
          const SizedBox(height: 8),
          Text('(Check And Update Cabinet Screen Version)', style: TextStyle(color: ConsoleTheme.textSecondary(context), fontSize: 11)),
          const SizedBox(height: 32),
          Center(
            child: logoUrl != null && logoUrl.isNotEmpty
              ? SizedBox(
                  height: 160,
                  child: SafeNetworkImage(
                    logoUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context) => _buildDcsLogo(),
                  ),
                )
              : _buildDcsLogo(),
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
        const SizedBox(width: 32),
        col3,
      ],
    );
  }

  Widget _buildAboutUs() {
    return ConsoleSectionCard(
      title: 'About Us',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Related Information:', style: TextStyle(color: ConsoleTheme.textPrimary(context), fontSize: 16, fontWeight: FontWeight.bold)),
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
            Text('Settings & Configuration', style: TextStyle(color: ConsoleTheme.textPrimary(context), fontSize: 24, fontWeight: FontWeight.bold)),
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
