import '../../core/config/app_config.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../core/utils/app_log.dart';

class GlobalVideoBackground {
  /// Background video used after the user is signed in (dashboard, manage users, etc).
  static GlobalVideoBackground? _app;
  static GlobalVideoBackground get app =>
      _app ??= GlobalVideoBackground._internal(assetUri: appAssetUri);

  /// Background video used for auth flows (welcome, login, signup, request access).
  static GlobalVideoBackground? _auth;
  static GlobalVideoBackground get auth =>
      _auth ??= GlobalVideoBackground._internal(assetUri: authAssetUri);

  /// Back-compat: treat `instance` as the post-login app background.
  static GlobalVideoBackground get instance => app;

  /// Replace these with your own assets (keep the `asset://` prefix).
  /// Example:
  /// `asset://assets/background/auth_bg.mp4`
  /// `asset://assets/background/app_bg.mp4`
  /// Post-login video background is intentionally disabled for performance.
  /// The UI uses a solid-color background via `BackgroundLayer(staticForApp: true)`.
  static const String appAssetUri = '';
  static String get authAssetUri => AppConfig.isRackConsoleBuild
      ? ''
      : 'asset:///assets/background/14900-259623335_medium.mp4';

  Player? player;
  VideoController? controller;

  GlobalVideoBackground._internal({required String assetUri}) {
    try {
      if (assetUri.trim().isEmpty) {
        // Explicitly disabled.
        player = null;
        controller = null;
        return;
      }
      player = Player();
      controller = VideoController(player!);
      player!.setPlaylistMode(PlaylistMode.loop);
      player!.open(Media(assetUri));
      player!.setVolume(0);
      player!.play(); // Force playback start
    } catch (e) {
      AppLog.d('[GlobalVideoBackground] Init error for $assetUri: $e');
      player = null;
      controller = null;
    }
  }
}
