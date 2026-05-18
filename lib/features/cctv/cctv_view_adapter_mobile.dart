import 'cctv_view_adapter.dart';

class CctvViewAdapterImpl implements CctvViewAdapter {
  @override
  void initPlayer(Function(String detail, bool isError) onReport) {
    // No-op on mobile
  }

  @override
  void updateIframeSource(String? url, bool streamError, String? token) {
    // No-op on mobile
  }

  @override
  void openUrl(String url) {
    // You could use url_launcher here if needed, but for now we keep it simple
  }
}

CctvViewAdapter createAdapter() => CctvViewAdapterImpl();
