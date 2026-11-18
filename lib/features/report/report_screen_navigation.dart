part of 'report_screen.dart';

extension _ReportScreenNavigation on _ReportScreenState {
  Widget _buildCustomNavButtons() {
    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Row(
          children: [
            _navBtn('Energy', Icons.bolt_rounded, 0),
            const SizedBox(width: 8),
            _navBtn('Health', Icons.favorite_outline_rounded, 1),
            const SizedBox(width: 8),
            _navBtn('Security', Icons.shield_outlined, 2),
          ],
        ),
      ),
    );
  }

  Widget _navBtn(String label, IconData icon, int index) {
    return Expanded(
      child: AnimatedBuilder(
        animation: _tabSelC,
        builder: (context, _) {
          final t = _tabSelC.value.clamp(0.0, 2.0);
          final selected = (t - index).abs() < 0.5;
          final isLight = Theme.of(context).brightness == Brightness.light;
          const accent = Color(0xFF0EA5E9);

          return GestureDetector(
            onTap: () => _selectTab(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: selected
                    ? accent.withValues(alpha: isLight ? 0.14 : 0.18)
                    : (isLight ? Colors.white : const Color(0xFF141820)),
                border: Border.all(
                  color: selected
                      ? accent.withValues(alpha: 0.55)
                      : (isLight
                          ? const Color(0xFFE5E7EB)
                          : Colors.white.withValues(alpha: 0.08)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: selected
                        ? (isLight
                            ? const Color(0xFF0284C7)
                            : const Color(0xFF38BDF8))
                        : (isLight
                            ? AppTheme.lightTextSecondary
                            : Colors.white.withValues(alpha: 0.55)),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        maxLines: 1,
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(
                          color: selected
                              ? (isLight
                                  ? const Color(0xFF0284C7)
                                  : Colors.white)
                              : (isLight
                                  ? AppTheme.lightTextSecondary
                                  : Colors.white.withValues(alpha: 0.58)),
                          fontSize: 13.5,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
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
