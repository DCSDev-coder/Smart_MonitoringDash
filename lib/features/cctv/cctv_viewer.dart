import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../core/theme/app_theme.dart';

class CctvFullScreenViewer extends StatefulWidget {
  final int channelId;
  final String streamUrl;

  const CctvFullScreenViewer({
    super.key,
    required this.channelId,
    required this.streamUrl,
  });

  @override
  State<CctvFullScreenViewer> createState() => _CctvFullScreenViewerState();
}

class _CctvFullScreenViewerState extends State<CctvFullScreenViewer> {
  Player? _player;
  VideoController? _controller;

  bool _isMuted = false;
  bool _isLoading = true;
  bool _hasVideo = false;
  String? _error;
  StreamSubscription? _trackSub;
  StreamSubscription? _logSub;
  Timer? _timeout;

  @override
  void initState() {
    super.initState();
    //Force Landscape Orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    //Hide System UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    try {
      _player = Player();
      _controller = VideoController(_player!);
    } catch (_) {
      _isLoading = false;
      _error =
          'Video engine unavailable on this device/build.\n\nIf this is Android, ensure libmpv is bundled in the APK.';
      return;
    }

    final player = _player!;

    _trackSub = player.stream.tracks.listen((tracks) {
      if (!mounted) return;
      if (tracks.video.isNotEmpty) {
        setState(() {
          _hasVideo = true;
          _isLoading = false;
          _error = null;
        });
      } else {
        _hasVideo = false;
      }
    });
    _logSub = player.stream.log.listen((log) {
      // Once video is confirmed, ignore noisy "failed" logs that don't actually
      // stop playback.
      if (_hasVideo) return;
      final text = log.text.toLowerCase();
      if (text.contains('401') ||
          text.contains('404') ||
          text.contains('unauthorized') ||
          text.contains('forbidden') ||
          text.contains('timed out') ||
          text.contains('failed')) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _error = 'Stream failed to open.';
        });
      }
    });

    try {
      player.open(Media(widget.streamUrl));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Failed to start the CCTV player.';
      });
      return;
    }

    _timeout = Timer(const Duration(seconds: 12), () {
      if (!mounted) return;
      if ((player.state.width ?? 0) <= 0 || (player.state.height ?? 0) <= 0) {
        setState(() {
          _isLoading = false;
          _error ??= 'No video received from this camera.';
        });
      }
    });
  }

  @override
  void dispose() {
    //Restore UI
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    _timeout?.cancel();
    _trackSub?.cancel();
    _logSub?.cancel();
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Digital Zoom Container ────────────────────────
          Center(
            child: InteractiveViewer(
              clipBehavior: Clip.none,
              minScale: 1.0,
              maxScale: 5.0,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (controller != null)
                    Video(controller: controller, controls: NoVideoControls),
                  if (_isLoading)
                    const CircularProgressIndicator(strokeWidth: 2),
                  if (_error != null)
                    Container(
                      color: Colors.black.withValues(alpha: 0.55),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 18,
                      ),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          //Top Bar
          Positioned(
            top: 40, //Space for landscape status bars
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 24),
                  onPressed: () => Navigator.pop(context),
                ),

                // Center Action Group
                Row(
                  children: [
                    // Mute Toggle
                    IconButton(
                      icon: Icon(
                        _isMuted ? Icons.volume_off : Icons.volume_up,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        setState(() {
                          _isMuted = !_isMuted;
                          _player?.setVolume(_isMuted ? 0 : 100);
                        });
                      },
                    ),
                  ],
                ),

                //High Def Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'HD Live',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          //Bottom Bar
          Positioned(
            bottom: 30,
            left: 30,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CAMERA ${widget.channelId}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  'MAIN STREAM • ACTIVE',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
