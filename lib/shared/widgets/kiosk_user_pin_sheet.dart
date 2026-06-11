import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import 'dashboard_glass.dart';
import '../../shared/utils/app_toast.dart';

class RackConsoleApprovalResult {
  const RackConsoleApprovalResult({
    required this.pin,
  });

  final String pin;
}

class RackConsoleUserPinSheet {
  RackConsoleUserPinSheet._();

  static Future<RackConsoleApprovalResult?> show(
    BuildContext context, {
    required String reason,
    String title = 'RACK CONSOLE PIN APPROVAL',
    String confirmLabel = 'Confirm',
  }) {
    return showModalBottomSheet<RackConsoleApprovalResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RackConsoleUserPinSheetBody(
        title: title,
        reason: reason,
        confirmLabel: confirmLabel,
      ),
    );
  }
}

class _RackConsoleUserPinSheetBody extends StatefulWidget {
  const _RackConsoleUserPinSheetBody({
    required this.title,
    required this.reason,
    required this.confirmLabel,
  });

  final String title;
  final String reason;
  final String confirmLabel;

  @override
  State<_RackConsoleUserPinSheetBody> createState() =>
      _RackConsoleUserPinSheetBodyState();
}

class _RackConsoleUserPinSheetBodyState
    extends State<_RackConsoleUserPinSheetBody> {
  final _pinCtrl = TextEditingController();

  bool _obscurePin = true;
  bool _submitting = false;

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_submitting) return;
    final pin = _pinCtrl.text.trim();
    if (pin.length < 4 || pin.length > 6) {
      AppToast.show(context, 'Enter a 4-6 digit PIN.');
      return;
    }

    setState(() => _submitting = true);
    Navigator.of(context).pop(
      RackConsoleApprovalResult(
        pin: pin,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: DashboardGlass(
        radius: 24,
        padding: const EdgeInsets.all(24),
        tint: isLight ? Colors.white : const Color(0xFF0B0F14),
        borderColor: isLight ? AppTheme.lightStroke : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isLight
                      ? Colors.black.withValues(alpha: 0.16)
                      : Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title,
                  style: TextStyle(
                    color: isLight ? AppTheme.lightTextPrimary : Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: isLight
                        ? AppTheme.lightTextSecondary
                        : Colors.white.withValues(alpha: 0.8),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              widget.reason,
              style: TextStyle(
                color: isLight
                    ? AppTheme.lightTextSecondary
                    : Colors.white.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pinCtrl,
              obscureText: _obscurePin,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              style: TextStyle(
                color: isLight ? AppTheme.lightTextPrimary : Colors.white,
                fontSize: 24,
                letterSpacing: 8,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                labelText: 'PIN',
                hintText: '••••',
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscurePin = !_obscurePin),
                  icon: Icon(
                    _obscurePin ? Icons.visibility : Icons.visibility_off,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(widget.confirmLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
