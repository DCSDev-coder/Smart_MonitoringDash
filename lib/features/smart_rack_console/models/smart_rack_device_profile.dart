import 'package:flutter/foundation.dart';

enum SmartRackDeviceKind {
  androidOperator,
  ePadDisplay,
}

@immutable
class SmartRackDeviceProfile {
  const SmartRackDeviceProfile({
    required this.kind,
    required this.label,
    required this.allowControls,
    required this.compactLayout,
  });

  final SmartRackDeviceKind kind;
  final String label;
  final bool allowControls;
  final bool compactLayout;

  bool get isDisplayOnly => !allowControls;
}

class SmartRackDeviceProfiles {
  SmartRackDeviceProfiles._();

  static const androidOperator = SmartRackDeviceProfile(
    kind: SmartRackDeviceKind.androidOperator,
    label: 'Android Operator Console',
    allowControls: true,
    compactLayout: false,
  );

  static const ePadDisplay = SmartRackDeviceProfile(
    kind: SmartRackDeviceKind.ePadDisplay,
    label: 'ePAD-IS Display Console',
    allowControls: false,
    compactLayout: true,
  );
}
