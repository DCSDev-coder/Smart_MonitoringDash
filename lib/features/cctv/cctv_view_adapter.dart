export 'cctv_view_adapter_mobile.dart'
    if (dart.library.html) 'cctv_view_adapter_web.dart';

abstract class CctvViewAdapter {
  void initPlayer(Function(String detail, bool isError) onReport);
  void updateIframeSource(String? url, bool streamError, String? token);
  void openUrl(String url);
}
