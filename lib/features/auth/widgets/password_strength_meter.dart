import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PasswordStrengthMeter extends StatefulWidget {
  final TextEditingController passwordController;

  const PasswordStrengthMeter({
    super.key,
    required this.passwordController,
  });

  @override
  State<PasswordStrengthMeter> createState() => _PasswordStrengthMeterState();
}

class _PasswordStrengthMeterState extends State<PasswordStrengthMeter> {
  int _score = 0;

  @override
  void initState() {
    super.initState();
    widget.passwordController.addListener(_calculateScore);
  }

  @override
  void dispose() {
    widget.passwordController.removeListener(_calculateScore);
    super.dispose();
  }

  void _calculateScore() {
    final text = widget.passwordController.text;
    int score = 0;
    if (text.length >= 6) score += 1;
    if (text.length >= 10) score += 1;
    if (text.contains(RegExp(r'[0-9]'))) score += 1;
    if (text.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) score += 1;

    // Clamp score to 4
    if (score > 4) score = 4;
    
    // Also if empty, 0
    if (text.isEmpty) score = 0;

    if (_score != score) {
      setState(() {
        _score = score;
      });
    }
  }

  Color _getColorForScore(int index, int totalScore) {
    if (index >= totalScore) return Colors.white.withValues(alpha: 0.1); // inactive
    
    if (totalScore <= 1) return Colors.redAccent;
    if (totalScore == 2) return Colors.amber;
    return const Color(0xFF00BD10); // Green for 3 and 4
  }

  String _getLabelForScore(int score) {
    if (score == 0) return '';
    if (score <= 1) return 'Weak';
    if (score == 2) return 'Fair';
    if (score == 3) return 'Good';
    return 'Strong';
  }

  Color _getLabelColor(int score) {
    if (score <= 1) return Colors.redAccent;
    if (score == 2) return Colors.amber;
    return const Color(0xFF00BD10);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(4, (index) {
            final isActive = index < _score;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: index < 3 ? 6.0 : 0.0),
                child: Container(
                  height: 4,
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: const Cubic(0.34, 1.56, 0.64, 1.0), // spring-like bounce
                    width: isActive ? double.infinity : 0,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _getColorForScore(index, _score),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        if (_score > 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _getLabelForScore(_score),
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: _getLabelColor(_score),
              ),
            ),
          ),
      ],
    );
  }
}
