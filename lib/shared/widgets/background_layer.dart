import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../utils/global_video_background.dart';

enum BackgroundChannel { auth, app }

class BackgroundLayer extends StatelessWidget {
  final BackgroundChannel channel;
  final double overlayAlpha;

  /// When true, the app channel will not render video even if available.
  /// This is the main performance knob for post-login screens.
  final bool staticForApp;

  /// Optional: provide an image asset (e.g. a frame from the app background video).
  /// If null, a gradient background is used.
  final String? appStaticImageAsset;

  const BackgroundLayer({
    super.key,
    required this.channel,
    required this.overlayAlpha,
    this.staticForApp = true,
    this.appStaticImageAsset,
  });

  @override
  Widget build(BuildContext context) {
    final isAuth = channel == BackgroundChannel.auth;
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final VideoController? controller = isAuth
        ? GlobalVideoBackground.auth.controller
        : (staticForApp ? null : GlobalVideoBackground.app.controller);
    final bool useVideo = controller != null;

    Widget base;
    if (useVideo) {
      base = RepaintBoundary(
        child: Video(
          controller: controller,
          fit: BoxFit.cover,
          controls: NoVideoControls,
        ),
      );
    } else if (!isAuth) {
      // Post-login background: keep it lightweight and consistent.
      // A single solid color avoids GPU-heavy video playback and avoids
      // image decode/resampling artifacts.
      base = ColoredBox(color: theme.scaffoldBackgroundColor);
    } else {
      base = DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              isLight ? theme.scaffoldBackgroundColor : const Color(0xFF0A1220),
              isLight ? theme.scaffoldBackgroundColor : const Color(0xFF060B11),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        Positioned.fill(child: base),
        Positioned.fill(
          child: ColoredBox(
            color: (isLight ? Colors.white : const Color(0xFF060B11))
                .withValues(alpha: overlayAlpha),
          ),
        ),
      ],
    );
  }
}
