import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/utils/app_toast.dart';
import 'dashboard_glass.dart';

class SetPinDialog extends StatefulWidget {
  final bool showSkipOptions;
  
  const SetPinDialog({super.key, this.showSkipOptions = false});

  @override
  State<SetPinDialog> createState() => _SetPinDialogState();
}

class _SetPinDialogState extends State<SetPinDialog> {
  final _pinCtrl = TextEditingController();
  bool _neverShowAgain = false;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: DashboardGlass(
        radius: 22,
        padding: const EdgeInsets.all(24),
        tint: isLight ? Colors.white : const Color(0xFF111922).withValues(alpha: 0.96),
        borderColor: isLight ? AppTheme.lightStroke : Colors.transparent,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text('Set Door Access PIN',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: isLight ? AppTheme.lightTextPrimary : Colors.white)),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded,
                        color: isLight ? AppTheme.lightTextSecondary : Colors.white70),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (widget.showSkipOptions) ...[
                Text(
                  'Please set a 4-digit PIN to securely access Rack Consoles and open doors.',
                  style: TextStyle(
                    fontSize: 14,
                    color: isLight ? AppTheme.lightTextSecondary : Colors.white70,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _pinCtrl,
                keyboardType: TextInputType.number,
                obscureText: true,
                autofocus: true,
                maxLength: 6,
                style: TextStyle(
                  color: isLight ? AppTheme.lightTextPrimary : Colors.white,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: 'Enter 4-6 digit PIN',
                  hintStyle: TextStyle(
                    color: isLight ? AppTheme.lightTextSecondary.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.35),
                  ),
                  filled: true,
                  fillColor: isLight ? Colors.black.withValues(alpha: 0.03) : Colors.white.withValues(alpha: 0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: isLight ? Colors.black.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.18)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: isLight ? Colors.black.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.18)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.55)),
                  ),
                  counterStyle: TextStyle(
                    color: isLight ? AppTheme.lightTextSecondary : Colors.white70,
                  ),
                ),
              ),
              if (widget.showSkipOptions) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: Checkbox(
                        value: _neverShowAgain,
                        onChanged: (v) => setState(() => _neverShowAgain = v ?? false),
                        activeColor: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('Never show again', style: TextStyle(fontSize: 13, color: isLight ? AppTheme.lightTextSecondary : Colors.white70)),
                  ],
                ),
                const SizedBox(height: 16),
              ] else ...[
                const SizedBox(height: 24),
              ],
              Row(
                children: [
                  if (widget.showSkipOptions) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          if (_neverShowAgain) {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('never_show_pin_prompt', true);
                          }
                          if (context.mounted) Navigator.pop(context, 'skipped');
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          foregroundColor: isLight ? AppTheme.lightTextSecondary : Colors.white70,
                          side: BorderSide(color: isLight ? AppTheme.lightTextSecondary.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.25)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Skip'),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: widget.showSkipOptions ? 2 : 1,
                    child: FilledButton(
                      onPressed: () {
                        final pin = _pinCtrl.text.trim();
                        if (pin.length < 4) {
                          AppToast.showError(context, 'PIN must be at least 4 digits');
                          return;
                        }
                        if (pin.contains(RegExp(r'[^0-9]'))) {
                          AppToast.showError(context, 'PIN must contain only numbers');
                          return;
                        }
                        Navigator.pop(context, pin);
                      },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Save PIN', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
