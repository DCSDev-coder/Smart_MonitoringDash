import 'package:flutter_test/flutter_test.dart';

import 'package:smart_rack_dashboard/core/config/app_config.dart';

void main() {
  test('app variant defaults to main or explicit rack console', () {
    expect(
      AppConfig.appVariant == 'main' || AppConfig.appVariant == 'rack_console',
      isTrue,
    );
  });
}
