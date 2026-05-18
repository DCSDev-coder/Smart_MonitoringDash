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
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isLight
            ? const Color(0xFFF3F4F7)
            : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLight
              ? const Color(0xFFD5DAE2)
              : Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscure,
              style: TextStyle(
                color: isLight ? AppTheme.lightTextPrimary : Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
              cursorColor:
                  isLight ? AppTheme.lightTextPrimary : Colors.white,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                  color: isLight
                      ? AppTheme.lightTextSecondary
                      : Colors.white.withValues(alpha: 0.40),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
                // Explicitly disable ALL borders to avoid a "double input"
                // look from theme-provided focused/outlined borders.
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                filled: false,
                fillColor: Colors.transparent,
                isDense: true,
                isCollapsed: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          IconButton(
            onPressed: _isSubmitting ? null : onToggle,
            icon: Icon(
              obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              color: isLight
                  ? AppTheme.lightTextSecondary
                  : Colors.white.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    // We keep the existing glass styling choices from SettingsOverlay for consistency.
    final maxW = (MediaQuery.of(context).size.width - 32).clamp(300.0, 380.0);
    final viewInsets = MediaQuery.of(context).viewInsets;

    // Local helper for the same font used by SettingsOverlay.
    TextStyle bitcount(BuildContext ctx,
        {required double fontSize,
        required Color color,
        double? letterSpacing}) {
      return TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        color: color,
        letterSpacing: letterSpacing,
      );
    }

    // NOTE: We intentionally do NOT use a translucent material barrier color here.
    // The caller (SettingsOverlay) already blurs/dims the background.
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + viewInsets.bottom),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxW,
                maxHeight: MediaQuery.of(context).size.height * 0.84,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
                decoration: BoxDecoration(
                  // Fully opaque background (user request): the dialog card itself
                  // should not be see-through.
                  color: isLight ? Colors.white : const Color(0xFF0B0F14),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: isLight
                        ? const Color(0xFFD7DCE4)
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    Text(
                      'Reset Password',
                      style: bitcount(
                        context,
                        fontSize: 24,
                        color: isLight
                            ? AppTheme.lightTextPrimary
                            : Colors.white,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Flexible(
                      fit: FlexFit.loose,
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            _passwordField(
                              controller: _currentCtrl,
                              hint: 'Current Password',
                              obscure: _obscureCurrent,
                              onToggle: () =>
                                  setState(() => _obscureCurrent = !_obscureCurrent),
                            ),
                            const SizedBox(height: 14),
                            _passwordField(
                              controller: _newCtrl,
                              hint: 'New Password',
                              obscure: _obscureNew,
                              onToggle: () => setState(() => _obscureNew = !_obscureNew),
                            ),
                            const SizedBox(height: 14),
                            _passwordField(
                              controller: _confirmCtrl,
                              hint: 'Confirm New Password',
                              obscure: _obscureConfirm,
                              onToggle: () =>
                                  setState(() => _obscureConfirm = !_obscureConfirm),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: isLight
                                    ? AppTheme.lightTextPrimary
                                    : Colors.white,
                                backgroundColor: isLight
                                    ? const Color(0xFFF1F2F5)
                                    : Colors.transparent,
                                side: BorderSide(
                                  color: isLight
                                      ? const Color(0xFFD5DAE2)
                                      : Colors.white.withValues(alpha: 0.18),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              onPressed: _isSubmitting ? null : () => Navigator.pop(context, false),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                // Match the app's primary accent green.
                                backgroundColor: AppTheme.accentGreen,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              onPressed: _isSubmitting ? null : _submit,
                              child: _isSubmitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Save',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
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
