part of 'report_screen.dart';

extension _ReportScreenNavigation on _ReportScreenState {
  Widget _buildCustomNavButtons() {
    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.light
                ? Colors.white
                : const Color(0xFF0F1722),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.light
                  ? Colors.black.withValues(alpha: 0.10)
                  : const Color(0xFF1E2D3D),
            ),
          ),
          child: SizedBox(
            height: 44,
            width: double.infinity,
            child: Stack(
              children: [
                AnimatedBuilder(
                  animation: _tabSelC,
                  builder: (context, _) {
                    final sel = _tabSelC.value.clamp(0.0, 2.0);
                    const energyC = Color(0xFF3271D7);
                    const healthC = AppTheme.accentGreen;
                    const securityC = Color(0xFFE6A600);

                    Color accentColor;
                    if (sel <= 1.0) {
                      accentColor = Color.lerp(energyC, healthC, sel)!;
                    } else {
                      accentColor = Color.lerp(healthC, securityC, sel - 1.0)!;
                    }

                    final alignX = -1.0 + (sel * 1.0);

                    return Align(
                      alignment: Alignment(alignX, 0),
                      child: FractionallySizedBox(
                        widthFactor: 1 / 3,
                        heightFactor: 1.0,
                        child: _AuraPill(color: accentColor),
                      ),
                    );
                  },
                ),
                Row(
                  children: [
                    _navBtn('ENERGY', 0),
                    _navBtn('HEALTH', 1),
                    _navBtn('SECURITY', 2),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navBtn(String label, int index) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _selectTab(index),
        behavior: HitTestBehavior.opaque,
        child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: AnimatedBuilder(
                animation: _tabSelC,
                builder: (context, _) {
                  final t = _tabSelC.value.clamp(0.0, 2.0);
                  final selectedness =
                      (1.0 - (t - index).abs()).clamp(0.0, 1.0).toDouble();
                  final isLight =
                      Theme.of(context).brightness == Brightness.light;
                  final unselectedColor = isLight
                      ? AppTheme.lightTextSecondary.withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.5);
                  return Text(
                    label,
                    style: TextStyle(
                      color: Color.lerp(
                        unselectedColor,
                        Colors.white,
                        selectedness,
                      ),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
  }

  Widget _buildEventFilterRow() {
    String labelFor(String r) {
      final s = r.trim();
      if (s.isEmpty) return 'Today';
      return '${s[0].toUpperCase()}${s.substring(1).toLowerCase()}';
    }

    final display = _eventLogRange.isEmpty ? 'Today' : _eventLogRange;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Theme(
      data: Theme.of(context).copyWith(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
      ),
      child: PopupMenuButton<String>(
        onSelected: (v) {
          _setEventLogRange(v);
        },
        color: isLight ? Colors.white : const Color(0xFF111922),
        itemBuilder: (context) => _ReportScreenState._eventRangeOptions
            .map(
              (option) => PopupMenuItem<String>(
                value: option,
                child: Text(
                  option,
                  style: TextStyle(
                    color: isLight ? AppTheme.lightTextPrimary : Colors.white,
                  ),
                ),
              ),
            )
            .toList(),
        child: DashboardGlass(
          radius: 14,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          tint: Theme.of(context).brightness == Brightness.light
              ? Colors.white
              : const Color(0xFF111922).withValues(alpha: 0.92),
          borderColor: Theme.of(context).brightness == Brightness.light
              ? AppTheme.lightStroke
              : const Color(0x22FFFFFF),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                labelFor(display),
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.light
                      ? AppTheme.lightTextPrimary
                      : Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: isLight
                    ? AppTheme.lightTextSecondary.withValues(alpha: 0.7)
                    : Colors.white.withValues(alpha: 0.75),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
