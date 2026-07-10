import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AnimatedAuthField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final bool isPassword;
  final TextInputAction action;
  final Function(String)? onSubmitted;
  final Widget? suffixIcon;

  const AnimatedAuthField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.label,
    this.isPassword = false,
    this.action = TextInputAction.done,
    this.onSubmitted,
    this.suffixIcon,
  });

  @override
  AnimatedAuthFieldState createState() => AnimatedAuthFieldState();
}

class AnimatedAuthFieldState extends State<AnimatedAuthField>
    with TickerProviderStateMixin {
  bool _obscure = true;
  bool _isFocused = false;
  String? _errorText;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _obscure = widget.isPassword;

    widget.focusNode.addListener(_handleFocusChange);
    widget.controller.addListener(_handleTextChange);

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: -4.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -4.0, end: 2.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 2.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _shakeController,
      curve: const Cubic(0.36, 0.07, 0.19, 0.97),
    ));
  }

  void _handleFocusChange() {
    setState(() {
      _isFocused = widget.focusNode.hasFocus;
    });
  }

  void _handleTextChange() {
    setState(() {});
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_handleFocusChange);
    widget.controller.removeListener(_handleTextChange);
    _shakeController.dispose();
    super.dispose();
  }

  void showError(String message) {
    setState(() {
      _errorText = message;
    });
    _shakeController.forward(from: 0.0);
  }

  void clearError() {
    if (_errorText != null) {
      setState(() {
        _errorText = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasText = widget.controller.text.isNotEmpty;
    final isLabelUp = _isFocused || hasText;
    final hasError = _errorText != null;

    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnimation.value, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 58,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF5B6474).withValues(alpha: 0.28),
                          const Color(0xFF303747).withValues(alpha: 0.22),
                        ],
                      ),
                      border: Border.all(
                        color: hasError
                            ? Colors.redAccent
                            : (_isFocused
                                ? const Color(0xFF00BD10)
                                : Colors.white.withValues(alpha: 0.16)),
                        width: _isFocused || hasError ? 1.5 : 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.28),
                          blurRadius: 18,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 18, top: 12),
                            child: TextField(
                              controller: widget.controller,
                              focusNode: widget.focusNode,
                              obscuringCharacter: '*',
                              obscureText: widget.isPassword ? _obscure : false,
                              textInputAction: widget.action,
                              onSubmitted: widget.onSubmitted,
                              onTapOutside: (_) => widget.focusNode.unfocus(),
                              onChanged: (_) => clearError(),
                              cursorColor: const Color(0xFF00BD10),
                              textAlignVertical: TextAlignVertical.center,
                              style: GoogleFonts.manrope(
                                color: Colors.white,
                                fontSize: 16,
                                letterSpacing: 0.2,
                              ),
                              decoration: const InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                                filled: false,
                              ),
                            ),
                          ),
                        ),
                        if (widget.isPassword)
                          IconButton(
                            icon: Icon(
                              _obscure ? Icons.visibility_off : Icons.visibility,
                              color: Colors.white70,
                            ),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          )
                        else if (widget.suffixIcon != null)
                          widget.suffixIcon!,
                      ],
                    ),
                  ),
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    top: isLabelUp ? 8 : 18,
                    left: 18,
                    child: IgnorePointer(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        style: GoogleFonts.manrope(
                          color: hasError
                              ? Colors.redAccent
                              : (isLabelUp
                                  ? const Color(0xFF00BD10)
                                  : Colors.white60),
                          fontSize: isLabelUp ? 11 : 16,
                          fontWeight:
                              isLabelUp ? FontWeight.bold : FontWeight.normal,
                          letterSpacing: 0.2,
                        ),
                        child: Text(widget.label),
                      ),
                    ),
                  ),
                ],
              ),
              if (hasError && _errorText!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: FadeTransition(
                    opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                      CurvedAnimation(
                        parent: _shakeController,
                        curve: Curves.easeIn,
                      ),
                    ),
                    child: Text(
                      _errorText!,
                      style: GoogleFonts.manrope(
                        color: Colors.redAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
