import 'package:flutter/material.dart';

import '../../core/network/cpanel_api_service.dart';
import '../../core/theme/app_theme.dart';

/// A safe, self-contained reset-password dialog.
///
/// We keep TextEditingControllers inside the dialog State and dispose them in
/// dispose(). This avoids "used after dispose" races that can happen when
/// disposing controllers from the caller after `Navigator.pop`.
class ResetPasswordAlertDialog extends StatefulWidget {
  final String username;

  const ResetPasswordAlertDialog({super.key, required this.username});

  @override
  State<ResetPasswordAlertDialog> createState() =>
      _ResetPasswordAlertDialogState();
}

class _ResetPasswordAlertDialogState extends State<ResetPasswordAlertDialog> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _isSubmitting = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final currentPassword = _currentCtrl.text.trim();
    final newPassword = _newCtrl.text.trim();
    final confirmPassword = _confirmCtrl.text.trim();

    if (currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all password fields.')),
      );
      return;
    }

    if (newPassword.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New password must be at least 8 characters.')),
      );
      return;
    }

    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New password and confirmation do not match.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final success = await CpanelApiService.instance.changePassword(
      username: widget.username,
      currentPassword: currentPassword,
      newPassword: newPassword,
    );

    if (!mounted) return;

    if (success) {
      Navigator.pop(context, true);
    } else {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset failed. Check your current password and try again.'),
          backgroundColor: AppTheme.statusError,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return AlertDialog(
      backgroundColor: isLight ? Colors.white : null,
      surfaceTintColor: Colors.transparent,
      title: Text(
        'Reset Password',
        style: TextStyle(
          color: isLight ? AppTheme.lightTextPrimary : null,
          fontWeight: FontWeight.w800,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _currentCtrl,
              obscureText: _obscureCurrent,
              style: TextStyle(
                color: isLight ? AppTheme.lightTextPrimary : null,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                labelText: 'Current Password',
                labelStyle: TextStyle(
                  color: isLight ? AppTheme.lightTextSecondary : null,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureCurrent ? Icons.visibility_off : Icons.visibility,
                    color: isLight ? AppTheme.lightTextSecondary : null,
                  ),
                  onPressed: _isSubmitting ? null : () => setState(() => _obscureCurrent = !_obscureCurrent),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newCtrl,
              obscureText: _obscureNew,
              style: TextStyle(
                color: isLight ? AppTheme.lightTextPrimary : null,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                labelText: 'New Password',
                labelStyle: TextStyle(
                  color: isLight ? AppTheme.lightTextSecondary : null,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureNew ? Icons.visibility_off : Icons.visibility,
                    color: isLight ? AppTheme.lightTextSecondary : null,
                  ),
                  onPressed: _isSubmitting ? null : () => setState(() => _obscureNew = !_obscureNew),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmCtrl,
              obscureText: _obscureConfirm,
              style: TextStyle(
                color: isLight ? AppTheme.lightTextPrimary : null,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                labelText: 'Confirm New Password',
                labelStyle: TextStyle(
                  color: isLight ? AppTheme.lightTextSecondary : null,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                    color: isLight ? AppTheme.lightTextSecondary : null,
                  ),
                  onPressed: _isSubmitting ? null : () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
            ),
            if (_isSubmitting) ...[
              const SizedBox(height: 16),
              const CircularProgressIndicator(),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class ResetPasswordGlassDialog extends StatefulWidget {
  final String username;

  const ResetPasswordGlassDialog({super.key, required this.username});

  @override
  State<ResetPasswordGlassDialog> createState() => _ResetPasswordGlassDialogState();
}

class _ResetPasswordGlassDialogState extends State<ResetPasswordGlassDialog> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _isSubmitting = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final currentPassword = _currentCtrl.text.trim();
    final newPassword = _newCtrl.text.trim();
    final confirmPassword = _confirmCtrl.text.trim();

    if (currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all password fields.')),
      );
      return;
    }

    if (newPassword.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New password must be at least 8 characters.')),
      );
      return;
    }

    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New password and confirmation do not match.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final success = await CpanelApiService.instance.changePassword(
      username: widget.username,
      currentPassword: currentPassword,
      newPassword: newPassword,
    );

    if (!mounted) return;

    if (success) {
      Navigator.pop(context, true);
    } else {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset failed. Check your current password and try again.'),
          backgroundColor: AppTheme.statusError,
        ),
      );
    }
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final color = isLight ? AppTheme.lightTextPrimary : Colors.white;
    final hintColor = isLight ? AppTheme.lightTextSecondary : Colors.white70;
    final borderColor = isLight ? const Color(0xFFD5DAE2) : Colors.white24;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          hint,
          style: TextStyle(
            color: hintColor,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: borderColor,
                width: 1.5,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: obscure,
                  style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: obscure ? 6.0 : 1.0,
                  ),
                  cursorColor: color,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              IconButton(
                onPressed: _isSubmitting ? null : onToggle,
                icon: Icon(
                  obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: hintColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final bgColor = isLight ? Colors.white : const Color(0xFF0B0F14);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isLight ? AppTheme.lightTextPrimary : Colors.white,
          ),
          onPressed: () => Navigator.pop(context, false),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reset Password',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: isLight ? AppTheme.lightTextPrimary : Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 40),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _passwordField(
                        controller: _currentCtrl,
                        hint: 'Current Password',
                        obscure: _obscureCurrent,
                        onToggle: () => setState(() => _obscureCurrent = !_obscureCurrent),
                      ),
                      const SizedBox(height: 24),
                      _passwordField(
                        controller: _newCtrl,
                        hint: 'New Password',
                        obscure: _obscureNew,
                        onToggle: () => setState(() => _obscureNew = !_obscureNew),
                      ),
                      const SizedBox(height: 24),
                      _passwordField(
                        controller: _confirmCtrl,
                        hint: 'Confirm New Password',
                        obscure: _obscureConfirm,
                        onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.accentGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'UPDATE PASSWORD',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
