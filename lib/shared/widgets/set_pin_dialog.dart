import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/utils/app_toast.dart';

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
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 16, 0),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Expanded(child: Text('Set Door Access PIN')),
          IconButton(
            icon: const Icon(Icons.close_rounded),
            color: isLight ? Colors.black87 : Colors.white,
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.showSkipOptions) ...[
              Text(
                'Please set a 4-digit PIN to securely access Rack Consoles and open doors.',
                style: TextStyle(
                  fontSize: 14,
                  color: isLight ? AppTheme.textSecondary : Colors.white70,
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
              decoration: const InputDecoration(
                hintText: 'Enter 4-6 digit PIN',
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
                  const Text('Never show again', style: TextStyle(fontSize: 13)),
                ],
              ),
            ]
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      actions: [
        if (widget.showSkipOptions)
          Center(
            child: TextButton(
              onPressed: () async {
                if (_neverShowAgain) {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('never_show_pin_prompt', true);
                }
                if (context.mounted) Navigator.pop(context, 'skipped');
              },
              child: Text('Skip',
                  style: TextStyle(
                      color: isLight ? AppTheme.textSecondary : Colors.white70)),
            ),
          ),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
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
          style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white),
          child: const Text('Save PIN'),
        ),
        ),
      ],
    );
  }
}
