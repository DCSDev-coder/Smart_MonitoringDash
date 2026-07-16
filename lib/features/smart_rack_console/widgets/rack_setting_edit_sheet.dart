import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/utils/app_toast.dart';
import '../theme/console_theme.dart';

class RackSettingEditSheet {
  RackSettingEditSheet._();

  static Future<String?> show(
    BuildContext context, {
    required String title,
    required String label,
    required String currentValue,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RackSettingEditSheetBody(
        title: title,
        label: label,
        currentValue: currentValue,
      ),
    );
  }
}

class _RackSettingEditSheetBody extends StatefulWidget {
  const _RackSettingEditSheetBody({
    required this.title,
    required this.label,
    required this.currentValue,
  });

  final String title;
  final String label;
  final String currentValue;

  @override
  State<_RackSettingEditSheetBody> createState() =>
      _RackSettingEditSheetBodyState();
}

class _RackSettingEditSheetBodyState extends State<_RackSettingEditSheetBody> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  TextInputType _keyboardType(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'on' ||
        normalized == 'off' ||
        normalized == 'enable' ||
        normalized == 'disable' ||
        normalized == 'true' ||
        normalized == 'false') {
      return TextInputType.text;
    }
    if (RegExp(r'^-?\d+(\.\d+)?$').hasMatch(value.trim())) {
      return const TextInputType.numberWithOptions(decimal: true, signed: true);
    }
    return TextInputType.text;
  }

  String? _validateValue(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Enter a new value.';
    return null;
  }

  void _submit() {
    final value = _controller.text.trim();
    final error = _validateValue(value);
    if (error != null) {
      AppToast.show(context, error);
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: ConsoleTheme.panelBg(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: ConsoleTheme.cardBorder(context),
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      color:
                          isLight ? Colors.black87 : ConsoleTheme.textPrimary(context),
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close_rounded,
                    color: isLight
                        ? Colors.black54
                        : ConsoleTheme.textSecondary(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              widget.label,
              style: TextStyle(
                color: isLight
                    ? Colors.black54
                    : ConsoleTheme.textSecondary(context),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: _keyboardType(widget.currentValue),
              inputFormatters: [
                LengthLimitingTextInputFormatter(64),
              ],
              style: TextStyle(
                color: isLight ? Colors.black : Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                labelText: 'New value',
                hintText: widget.currentValue,
                filled: true,
                fillColor: Colors.white.withValues(alpha: isLight ? 0.9 : 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _submit,
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
