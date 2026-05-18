import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import 'cctv_config_manager.dart';
import 'cctv_view_adapter.dart'
    if (dart.library.html) 'cctv_view_adapter_web.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'cctv_viewer.dart';

class CctvScreen extends StatefulWidget {
  const CctvScreen({super.key});

  @override
  State<CctvScreen> createState() => CctvScreenState();
}

class CctvScreenState extends State<CctvScreen> {


  final bool _loading = false;
  final _adapter = createAdapter();

  // NVR Config (Mutable by user)
  String _nvrIp = '192.168.1.8';
  int _nvrPort = 554;
  String _nvrUser = 'admin';
  String _nvrPass = '';
  Map<int, String> _channelStreams = {};
  List<int> _selectedChannels = [];

  //CCTV Mute
  final Map<int, bool> _isMuted = {};
  final Map<int, bool> _soundDetected = {};
  final Map<int, bool> _isStreamLoading = {};
  final Map<int, bool> _hasVideo = {};
  final Map<int, String?> _streamErrors = {};
  final Map<int, StreamSubscription> _trackSubscriptions = {};
  final Map<int, StreamSubscription> _logSubscriptions = {};
  final Map<int, Timer> _streamTimeouts = {};

  //CCTV Fullscreen
  String _getHighResUrl(String subStreamUrl) {
    if (subStreamUrl.contains('/Streaming/Channels/')) {
      return subStreamUrl
          .replaceFirst('/Streaming/Channels/102', '/Streaming/Channels/101')
          .replaceFirst('/Streaming/Channels/202', '/Streaming/Channels/201')
          .replaceFirst('/Streaming/Channels/302', '/Streaming/Channels/301')
          .replaceFirst('/Streaming/Channels/402', '/Streaming/Channels/401')
          .replaceFirst('/Streaming/Channels/502', '/Streaming/Channels/501')
          .replaceFirst('/Streaming/Channels/602', '/Streaming/Channels/601')
          .replaceFirst('/Streaming/Channels/702', '/Streaming/Channels/701')
          .replaceFirst('/Streaming/Channels/802', '/Streaming/Channels/801')
          .replaceFirst('/Streaming/Channels/902', '/Streaming/Channels/901');
    }

    return subStreamUrl.replaceAll('subtype=1', 'subtype=0');
  }

  // Player pool for simultaneous multi-stream display
  final Map<int, Player> _playerPool = {};
  final Map<int, VideoController> _controllerPool = {};

  @override
  void initState() {
    super.initState();
    _adapter.initPlayer((detail, isError) {
      if (mounted) {
        setState(() {
          // Player status updates handled via adapter/pool
        });
      }
    });
    _loadSavedConfig();
  }

  void updateConfig(Map<String, dynamic> config) {
    setState(() {
      _nvrIp = config['nvrIp'];
      _nvrPort = config['nvrPort'];
      _nvrUser = config['nvrUser'];
      _nvrPass = config['nvrPass'];
      _channelStreams = Map<int, String>.from(config['channelStreams']);
      _selectedChannels = List<int>.from(config['selectedChannels']);

      // Apply Global Mute if requested
      if (config.containsKey('muteAll')) {
        final muteAll = config['muteAll'] == true;
        for (var ch in _playerPool.keys) {
          _playerPool[ch]?.setVolume(muteAll ? 0 : 100);
          _isMuted[ch] = muteAll;
        }
      }
    });
    _updateDisplayPlayers();
    _persistConfig();
  }

  Future<void> _loadSavedConfig() async {
    final config = await CctvConfigManager.loadConfig();

    if (!mounted) return;

    setState(() {
      _nvrIp = config['nvrIp'];
      _nvrPort = config['nvrPort'];
      _nvrUser = config['nvrUser'];
      _nvrPass = config['nvrPass'];
      
      final savedMuteAll = config['muteAll'];
      for (final p in _playerPool.values) {
        p.setVolume(savedMuteAll ? 0 : 100);
      }
      for (final key in _playerPool.keys) {
        _isMuted[key] = savedMuteAll;
      }
      
      _channelStreams = config['channelStreams'];
      _selectedChannels = config['selectedChannels'];
    });

    _updateDisplayPlayers();
  }

  Future<void> _persistConfig() async {
    await CctvConfigManager.persistConfig(getConfig());
  }

  void _updateDisplayPlayers() {
    if (kIsWeb) return;

    // Clean up players not in selection
    final removedChannels = _playerPool.keys
        .where((id) => !_selectedChannels.contains(id))
        .toList();
    for (final id in removedChannels) {
      _disposeChannelResources(id);
      _playerPool[id]?.dispose();
      _playerPool.remove(id);
      _controllerPool.remove(id);
    }

    // Add new players
    for (final chNum in _selectedChannels) {
      if (!_playerPool.containsKey(chNum) &&
          _channelStreams.containsKey(chNum)) {
        final url = _channelStreams[chNum]!;
        Player p;
        try {
          p = Player();
        } catch (_) {
          _isStreamLoading[chNum] = false;
          _streamErrors[chNum] =
              'Video engine unavailable on this device/build (missing native libs).';
          continue;
        }
        // Lesson 2: Start every new camera as MUTED
        p.setVolume(0);
        _isMuted[chNum] = true;
        _soundDetected[chNum] = false;

        // Lesson 4: The "Magic Ear" - Detect if the stream has audio
        _trackSubscriptions[chNum] = p.stream.tracks.listen((tracks) {
          if (mounted) {
            setState(() {
              _soundDetected[chNum] = tracks.audio.isNotEmpty;
              if (tracks.video.isNotEmpty) {
                _hasVideo[chNum] = true;
                _isStreamLoading[chNum] = false;
                _streamErrors[chNum] = null;
              } else {
                _hasVideo[chNum] = false;
              }
            });
          }
        });
        _logSubscriptions[chNum] = p.stream.log.listen((log) {
          // Once we have confirmed video, ignore noisy "failed" log lines that
          // don't actually stop playback.
          if (_hasVideo[chNum] == true) return;
          final text = log.text.toLowerCase();
          if (text.contains('401') ||
              text.contains('404') ||
              text.contains('unauthorized') ||
              text.contains('forbidden') ||
              text.contains('timed out') ||
              text.contains('failed')) {
            if (mounted) {
              setState(() {
                _isStreamLoading[chNum] = false;
                _streamErrors[chNum] = 'Stream failed to open.';
              });
            }
          }
        });

        VideoController c;
        try {
          c = VideoController(p);
        } catch (_) {
          _isStreamLoading[chNum] = false;
          _streamErrors[chNum] = 'Failed to initialize CCTV video controller.';
          try {
            p.dispose();
          } catch (_) {}
          continue;
        }
        _playerPool[chNum] = p;
        _controllerPool[chNum] = c;
        _isStreamLoading[chNum] = true;
        _streamErrors[chNum] = null;
        _streamTimeouts[chNum]?.cancel();
        _streamTimeouts[chNum] = Timer(const Duration(seconds: 12), () {
          if (!mounted) return;
          final hasVideo = (p.state.width ?? 0) > 0 && (p.state.height ?? 0) > 0;
          if (!hasVideo) {
            setState(() {
              _isStreamLoading[chNum] = false;
              _streamErrors[chNum] ??= 'No video received from this camera.';
            });
          }
        });
        try {
          p.open(Media(url));
        } catch (_) {
          _isStreamLoading[chNum] = false;
          _streamErrors[chNum] = 'Stream failed to open.';
        }
      }
    }
    setState(() {});
  }

  void _disposeChannelResources(int chNum) {
    _trackSubscriptions.remove(chNum)?.cancel();
    _logSubscriptions.remove(chNum)?.cancel();
    _streamTimeouts.remove(chNum)?.cancel();
    _isStreamLoading.remove(chNum);
    _streamErrors.remove(chNum);
    _isMuted.remove(chNum);
    _soundDetected.remove(chNum);
    _hasVideo.remove(chNum);
  }

  @override
  void dispose() {
    for (final id in _playerPool.keys.toList()) {
      _disposeChannelResources(id);
    }
    for (var p in _playerPool.values) {
      p.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screenWidth = media.size.width;
    final hPadding = screenWidth * 0.06;
 
    final uiScale = screenWidth >= 900 ? (screenWidth / 1150).clamp(1.0, 1.25) : 1.0;
 
    return MediaQuery(
      data: media.copyWith(textScaler: TextScaler.linear(uiScale)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: EdgeInsets.only(
                        left: hPadding,
                        right: hPadding,
                        top: AppConstants.headerClearance(context),
                        bottom: 24,
                      ),
                      children: [
                        _buildVideoPlayer(uiScale),
                        const SizedBox(height: 40),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayer(double uiScale) {
    if (_selectedChannels.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 100),
        child: _buildEmptyPlaceholder(uiScale),
      );
    }

    return Column(
      children: _selectedChannels.map((ch) => _buildCameraCard(ch, uiScale)).toList(),
    );
  }

  Widget _buildCameraCard(int chNum, double uiScale) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Restore the Label
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Text(
              'CAM $chNum',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppTheme.textPrimary),
            ),
          ),
          // Use AspectRatio + Container for the rounded box
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4)),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              // NOW put the Stack here
              child: Stack(
                children: [
                  _buildPlayerContent(chNum, uiScale),
                  // Mute/Unmute Overlay stays here!
                  Positioned(
                    top: 12,
                    right: 12,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          final muted = _isMuted[chNum] ?? true;
                          _isMuted[chNum] = !muted;
                          _playerPool[chNum]?.setVolume(muted ? 100 : 0);
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          (_isMuted[chNum] ?? true)
                              ? Icons.volume_off_rounded
                              : Icons.volume_up_rounded,
                          color: (_soundDetected[chNum] ?? false)
                              ? AppTheme.accentGreen
                              : Colors.white,
                          size: 20 * uiScale,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerContent(int chNum, double uiScale) {
    final controller = _controllerPool[chNum];
    final subStreamUrl = _channelStreams[chNum];
    final error = _streamErrors[chNum];
    final isLoading = _isStreamLoading[chNum] ?? false;

    if (controller != null && subStreamUrl != null) {
      return GestureDetector(
        onTap: () {
          _playerPool[chNum]?.pause();

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CctvFullScreenViewer(
                channelId: chNum,
                streamUrl: _getHighResUrl(subStreamUrl),
              ),
            ),
          ).then((_) {
            _playerPool[chNum]?.play();
          });
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            Video(controller: controller, controls: NoVideoControls),
            if (isLoading)
              const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            if (error != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.signal_wifi_statusbar_connected_no_internet_4_rounded,
                        color: Colors.white70,
                        size: 28 * uiScale,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        error,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    }
    return const Center(child: CircularProgressIndicator(strokeWidth: 2));
  }

  Widget _buildEmptyPlaceholder(double uiScale) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.videocam_off_rounded,
              color: Colors.white12, size: 64 * uiScale),
          const SizedBox(height: 16),
          const Text('NO CAMERA SELECTED',
              style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
          const SizedBox(height: 8),
          const Text('Configure settings to add cameras',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  Map<String, dynamic> getConfig() {
    return {
      'nvrIp': _nvrIp,
      'nvrPort': _nvrPort,
      'nvrUser': _nvrUser,
      'nvrPass': _nvrPass,
      'channelStreams': _channelStreams,
      'selectedChannels': _selectedChannels,
      'muteAll': _playerPool.isEmpty
          ? true
          : _playerPool.values.every((p) => p.state.volume == 0),
    };
  }
}
