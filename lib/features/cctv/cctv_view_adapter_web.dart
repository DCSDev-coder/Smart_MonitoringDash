import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'dart:ui_web' as ui;
import 'cctv_view_adapter.dart';

@JS()
extension type CCTVMessage(JSObject _) implements JSObject {
  external String? get type;
  external String? get detail;
  external bool? get isError;
}

class CctvViewAdapterImpl implements CctvViewAdapter {
  web.HTMLIFrameElement? _currentIframe;

  @override
  void initPlayer(Function(String detail, bool isError) onReport) {
    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(
      'cctv-player',
      (int viewId) {
        final iframe = web.document.createElement('iframe') as web.HTMLIFrameElement
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%';

        _currentIframe = iframe;
        return iframe;
      },
    );

    web.window.onMessage.listen((web.MessageEvent event) {
      final data = event.data;
      if (data != null && data.isA<JSObject>()) {
        final msg = data as CCTVMessage;
        if (msg.type == 'cctv-report') {
          onReport(
            msg.detail ?? 'Error',
            msg.isError == true,
          );
        }
      }
    });
  }

  @override
  void updateIframeSource(String? url, bool streamError, String? token) {
    final iframe = _currentIframe;
    if (iframe == null) return;

    if (url == null || streamError) {
      iframe.srcdoc = ('''
        <style>
          body { margin: 0; background: #000; color: #666; font-family: sans-serif; display: flex; align-items: center; justify-content: center; height: 100vh; text-align: center; }
          .error { padding: 20px; border: 1px solid #333; border-radius: 8px; }
          h2 { color: #888; margin-bottom: 8px; font-size: 16px; }
          p { font-size: 12px; }
        </style>
        <div class="error">
          <h2>CCTV FOOTAGE UNAVAILABLE</h2>
          <p>The stream connection timed out or is not reachable.</p>
        </div>
      ''').toJS;
    } else if (url.toLowerCase().startsWith('rtsp://')) {
      // RTSP cannot play in any web browser — show a clear informational message
      iframe.srcdoc = ('''
        <!DOCTYPE html>
        <html>
        <head>
          <style>
            body, html { margin: 0; padding: 0; width: 100%; height: 100%; background: #111; display: flex; align-items: center; justify-content: center; font-family: sans-serif; }
            .notice { background: #1a1a2e; border: 1px solid #2a2a4a; border-radius: 12px; padding: 28px; max-width: 340px; text-align: center; }
            .badge { display: inline-block; background: #0a84ff22; border: 1px solid #0a84ff55; color: #5aabff; border-radius: 6px; padding: 3px 10px; font-size: 11px; margin-bottom: 14px; letter-spacing: 1px; }
            h2 { color: #ccc; font-size: 15px; margin: 0 0 10px; }
            p { color: #666; font-size: 12px; line-height: 1.7; margin: 0; }
            strong { color: #aaa; }
          </style>
        </head>
        <body>
          <div class="notice">
            <div class="badge">RTSP STREAM</div>
            <h2>&#128241; Use the Mobile App</h2>
            <p>RTSP streams cannot be played inside a web browser. Open the <strong>Smart Rack app</strong> on your Android or iPhone to view live CCTV footage, or install <strong>iVMS-4200</strong> on your PC.</p>
          </div>
        </body>
        </html>
      ''').toJS;
    } else {
      final headersJson = token != null ? '{"X-Access-Token": "$token"}' : '{}';
      final isHls = url.toLowerCase().contains('.m3u8');

      iframe.srcdoc = ('''
<!DOCTYPE html>
<html>
<head>
    <style>
        body, html { margin: 0; padding: 0; width: 100%; height: 100%; background: #000; overflow: hidden; display: flex; align-items: center; justify-content: center; font-family: sans-serif; }
        #videoElement { width: 100%; height: 100%; }
        .msg { color: #888; font-size: 14px; text-align: center; padding: 20px; }
    </style>
    ${isHls ? '<script src="https://cdn.jsdelivr.net/npm/hls.js@latest"></script>' : '<script src="https://cdnjs.cloudflare.com/ajax/libs/flv.js/1.6.2/flv.min.js"></script>'}
</head>
<body>
    <video id="videoElement" controls autoplay muted></video>
    <script>
        var video = document.getElementById('videoElement');
        var url = '$url';
        if ($isHls) {
            if (Hls.isSupported()) {
                var hls = new Hls(); hls.loadSource(url); hls.attachMediaElement(video);
                hls.on(Hls.Events.MANIFEST_PARSED, function() { video.play(); });
            }
        } else if (flvjs.isSupported()) {
            var flvPlayer = flvjs.createPlayer({ type: 'flv', url: url, isLive: true, cors: true, withCredentials: true }, { enableStashBuffer: false, headers: $headersJson });
            flvPlayer.attachMediaElement(video); flvPlayer.load(); flvPlayer.play();
            flvPlayer.on(flvjs.Events.ERROR, function(t, d, i) {
                window.parent.postMessage({ type: 'cctv-report', isError: true, detail: t + ': ' + d }, '*');
            });
        }
    </script>
</body>
</html>
''').toJS;
    }
  }

  @override
  void openUrl(String url) {
    web.window.open(url, '_blank');
  }
}

CctvViewAdapter createAdapter() => CctvViewAdapterImpl();
