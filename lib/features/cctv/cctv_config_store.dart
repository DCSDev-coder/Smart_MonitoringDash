import 'cctv_config_store_base.dart';
import 'cctv_config_store_mobile.dart'
    if (dart.library.html) 'cctv_config_store_web.dart';

final CctvConfigStore cctvConfigStore = createPlatformCctvConfigStore();
