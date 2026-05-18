import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/dashboard_glass.dart';

class CctvSettingsScreen extends StatefulWidget {
  final Map<String, dynamic> initialConfig;

  const CctvSettingsScreen({super.key, required this.initialConfig});

  @override
  State<CctvSettingsScreen> createState() => _CctvSettingsScreenState();
}

class _CctvSettingsScreenState extends State<CctvSettingsScreen> {
  late TextEditingController _ipController;
  late TextEditingController _userController;
  late TextEditingController _passController;
  late TextEditingController _portController;

  late String _nvrIp;
  late String _nvrUser;
  late String _nvrPass;
  late int _nvrPort;

  Map<int, String> _channelStreams = {};
  List<int> _selectedChannels = [];
  bool _muteAll = true; // Lesson 5.1: Added Mute All status

  bool _isScanning = false;
  String _scanningStatus = '';
  int _currentScanId = 0;
  String? _lastProbeError;
  String? _lastProbeLog;
  String? _lastProbeUrl;

  Future<bool> _probeRtspUrl(String url) async {
    _lastProbeError = null;
    _lastProbeLog = null;
    _lastProbeUrl = url;
    late final Player player;
    try {
      player = Player();
    } catch (_) {
      // Video engine not available (e.g. missing Android native libs).
      _lastProbeError = 'Video engine unavailable on this device/build.';
      return false;
    }

    bool streamRejected = false;
    bool streamOpened = false;
    bool hasVideoTrack = false;

    final logSub = player.stream.log.listen((log) {
      final text = log.text.toLowerCase();
      _lastProbeLog = log.text.trim();
      if (text.contains('404') ||
          text.contains('401') ||
          text.contains('unauthorized') ||
          text.contains('forbidden') ||
          text.contains('denied') ||
          text.contains('connection refused') ||
          text.contains('refused') ||
          text.contains('timed out') ||
          text.contains('failed to recognize file format') ||
          text.contains('failed')) {
        streamRejected = true;
        if (_lastProbeError == null) {
          if (text.contains('401') || text.contains('unauthorized')) {
            _lastProbeError = 'Unauthorized (check username/password).';
          } else if (text.contains('404')) {
            _lastProbeError = 'Stream path not found (404).';
          } else if (text.contains('refused')) {
            _lastProbeError =
                'Connection refused (RTSP disabled or port blocked).';
          } else if (text.contains('timed out')) {
            _lastProbeError = 'Connection timed out (network/port blocked).';
          } else if (text.contains('failed to recognize file format')) {
            _lastProbeError =
                'Device returned non-video/unsupported stream. Check RTSP port/path and set camera encoding to H.264.';
          } else if (text.contains('forbidden') || text.contains('denied')) {
            _lastProbeError = 'Access denied by device.';
          } else {
            _lastProbeError = 'Stream failed to open.';
          }
        }
      }
    });
    final trackSub = player.stream.tracks.listen((tracks) {
      if (tracks.video.isNotEmpty) {
        hasVideoTrack = true;
      }
    });

    try {
      await player.open(Media(url));
      // Some RTSP streams take a while to expose tracks/frames depending on codec,
      // network jitter, or device load. Be a bit more patient than the UI feels.
      for (int i = 0; i < 30; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (streamRejected) {
          break;
        }
        if (hasVideoTrack) {
          streamOpened = true;
          break;
        }
        final width = player.state.width ?? 0;
        final height = player.state.height ?? 0;
        if (width > 0 && height > 0) {
          streamOpened = true;
          break;
        }
      }
      if (!streamOpened && !streamRejected) {
        _lastProbeError ??= 'No video received (check network/RTSP settings).';
      }
    } catch (e) {
      streamRejected = true;
      _lastProbeError ??= 'Connection failed: $e';
    } finally {
      await logSub.cancel();
      await trackSub.cancel();
      await player.stop();
      await player.dispose();
    }

    return streamOpened && !streamRejected;
  }

  String _buildRtspUrl({
    required String user,
    required String pass,
    required String ip,
    required int port,
    required String path,
  }) {
    final trimmed = path.startsWith('/') ? path : '/$path';
    final qIndex = trimmed.indexOf('?');
    final p = qIndex >= 0 ? trimmed.substring(0, qIndex) : trimmed;
    final q = qIndex >= 0 ? trimmed.substring(qIndex + 1) : null;

    // IMPORTANT: username/password must be percent-encoded for RTSP URLs,
    // otherwise characters like '@' or ':' will break authentication parsing.
    final uri = Uri(
      scheme: 'rtsp',
      userInfo: '${Uri.encodeComponent(user)}:${Uri.encodeComponent(pass)}',
      host: ip,
      port: port,
      path: p,
      query: q,
    );
    return uri.toString();
  }

  Iterable<String> _buildRtspUrlCandidates({
    required String user,
    required String pass,
    required String ip,
    required int port,
    required String path,
  }) sync* {
    final trimmed = path.startsWith('/') ? path : '/$path';

    // 1) Raw credentials (some embedded RTSP servers are picky and don't decode
    // percent-encoding in the userinfo part correctly).
    yield 'rtsp://$user:$pass@$ip:$port$trimmed';

    // 2) Properly URL-encoded credentials (works when password has '@', ':' etc).
    yield _buildRtspUrl(
      user: user,
      pass: pass,
      ip: ip,
      port: port,
      path: trimmed,
    );
  }

  Iterable<String> _hikvisionStreamingChannelPaths(int ch) sync* {
    // Hikvision convention:
    // - main stream: 101, 201, 301...
    // - sub stream:  102, 202, 302...
    // Some installs disable sub-stream, so we try both.
    yield '/Streaming/Channels/${ch}01';
    yield '/Streaming/Channels/${ch}02';
  }

  @override
  void initState() {
    super.initState();
    final config = widget.initialConfig;
    _nvrIp = config['nvrIp'] ?? '192.168.1.8';
    _nvrUser = config['nvrUser'] ?? 'admin';
    _nvrPass = config['nvrPass'] ?? '';
    _nvrPort = config['nvrPort'] ?? 554;
    _channelStreams = Map<int, String>.from(config['channelStreams'] ?? {});
    _selectedChannels = List<int>.from(config['selectedChannels'] ?? []);
    _muteAll = config['muteAll'] ?? true; // Lesson 5.1: Initialize from config

    _ipController = TextEditingController(text: _nvrIp);
    _userController = TextEditingController(text: _nvrUser);
    _passController = TextEditingController(text: _nvrPass);
    _portController = TextEditingController(text: _nvrPort.toString());
  }

  @override
  void dispose() {
    _ipController.dispose();
    _userController.dispose();
    _passController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _runScan() async {
    final scanId = ++_currentScanId;
    setState(() {
      _isScanning = true;
      _channelStreams.clear();
      _selectedChannels.clear();
      _scanningStatus = 'Initializing Smart Scan...';
    });

    try {
      final String user = _userController.text.trim();
      final String pass = _passController.text.trim();
      final String ip = _ipController.text.trim();
      final int port = int.tryParse(_portController.text) ?? 554;

      if (ip.isEmpty || user.isEmpty || pass.isEmpty) {
        setState(() {
          _scanningStatus = 'Please fill IP address, username, and password.';
          _isScanning = false;
        });
        return;
      }

      final ips = [ip];
      bool foundAny = false;

      for (final currentIp in ips) {
        if (!mounted || scanId != _currentScanId) return;
        setState(() => _scanningStatus = 'Connecting to $currentIp:$port...');

        String? workingPathPattern;
        final discoveryPaths = [
          '/Streaming/Channels/101',
          '/Streaming/Channels/102',
          '/Streaming/Channels/201',
          // Common Hikvision alternate RTSP paths.
          '/h264/ch1/main/av_stream',
          '/h264/ch1/sub/av_stream',
          '/cam/realmonitor?channel=1&subtype=1',
          '/Streaming/Channels/902'
        ];

        for (final path in discoveryPaths) {
          if (!mounted || scanId != _currentScanId) return;
          for (final testUrl in _buildRtspUrlCandidates(
            user: user,
            pass: pass,
            ip: currentIp,
            port: port,
            path: path,
          )) {
            if (await _probeRtspUrl(testUrl)) {
              workingPathPattern = path;
              break;
            }
          }
          if (workingPathPattern != null) break;
        }
        if (workingPathPattern == null) {
          if (!mounted || scanId != _currentScanId) return;
          setState(() {
            final base = _lastProbeError == null
                ? 'Scan Failed: Unable to connect to $currentIp:$port.'
                : 'Scan Failed: $_lastProbeError';
            final parts = <String>[base];
            if (_lastProbeUrl != null) parts.add('Last URL: $_lastProbeUrl');
            if (_lastProbeLog != null) parts.add('Last log: $_lastProbeLog');
            _scanningStatus = parts.join('\n');
          });
          continue;
        }

        for (int ch = 1; ch <= 16; ch++) {
          if (!mounted || scanId != _currentScanId) return;
          setState(() => _scanningStatus = 'Checking CH $ch...');

          if (workingPathPattern.contains('Streaming')) {
            var ok = false;
            for (final path in _hikvisionStreamingChannelPaths(ch)) {
              for (final finalUrl in _buildRtspUrlCandidates(
                user: user,
                pass: pass,
                ip: currentIp,
                port: port,
                path: path,
              )) {
                if (await _probeRtspUrl(finalUrl)) {
                  setState(() {
                    _channelStreams[ch] = finalUrl;
                    foundAny = true;
                  });
                  ok = true;
                  break;
                }
              }
              if (ok) break;
            }
          } else if (workingPathPattern.contains('/h264/ch1/')) {
            // Map ch1->chN and keep main/sub stream naming.
            final paths = [
              '/h264/ch$ch/main/av_stream',
              '/h264/ch$ch/sub/av_stream',
            ];
            for (final path in paths) {
              for (final finalUrl in _buildRtspUrlCandidates(
                user: user,
                pass: pass,
                ip: currentIp,
                port: port,
                path: path,
              )) {
                if (await _probeRtspUrl(finalUrl)) {
                  setState(() {
                    _channelStreams[ch] = finalUrl;
                    foundAny = true;
                  });
                  break;
                }
              }
              if (_channelStreams.containsKey(ch)) break;
            }
          } else {
            final path = '/cam/realmonitor?channel=$ch&subtype=1';
            for (final finalUrl in _buildRtspUrlCandidates(
              user: user,
              pass: pass,
              ip: currentIp,
              port: port,
              path: path,
            )) {
              if (await _probeRtspUrl(finalUrl)) {
                setState(() {
                  _channelStreams[ch] = finalUrl;
                  foundAny = true;
                });
                break;
              }
            }
          }
        }
        if (foundAny) break;
      }
      if (!mounted || scanId != _currentScanId) return;
      setState(() {
        if (foundAny) {
          _scanningStatus = 'Scan Complete: ${_channelStreams.length} found';
        } else {
          final base = _lastProbeError == null
              ? 'Scan Failed: No cameras detected.'
              : 'Scan Failed: $_lastProbeError';
          final parts = <String>[base];
          if (_lastProbeUrl != null) parts.add('Last URL: $_lastProbeUrl');
          if (_lastProbeLog != null) parts.add('Last log: $_lastProbeLog');
          _scanningStatus = parts.join('\n');
        }
      });
    } finally {
      if (mounted && scanId == _currentScanId) {
        setState(() => _isScanning = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screenW = media.size.width;
    final uiScale = screenW >= 900 ? (screenW / 1150).clamp(1.0, 1.25) : 1.0;
 
    return MediaQuery(
      data: media.copyWith(textScaler: TextScaler.linear(uiScale)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          'CCTV CONFIGURATION',
          style: TextStyle(
            letterSpacing: 1.2,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _sectionLabel('NVR DETAILS'),
          const SizedBox(height: 12),
          _buildCard(
            child: Column(
              children: [
                _buildField('IP Address', _ipController),
                _buildField('Username', _userController),
                _buildField('Password', _passController, isPass: true),
                _buildField('RTSP Port', _portController),
                const SizedBox(height: 16),
                Center(
                  child: SizedBox(
                    width: 140,
                    child: ElevatedButton(
                      onPressed: _isScanning ? null : _runScan,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color(0xFF0E141B).withValues(alpha: 0.92),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                      ),
                      child: _isScanning
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Scan',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                if (_scanningStatus.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(_scanningStatus,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500)),
                ]
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Lesson 5.1: The Global Mute All Switch
          _buildCard(
            child: SwitchListTile(
              title: Text(
                'Mute All Cameras',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: Theme.of(context).brightness == Brightness.light ? AppTheme.lightTextPrimary : Colors.white,
                ),
              ),
              subtitle: Text(
                'Silence all audio streams by default',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).brightness == Brightness.light ? AppTheme.lightTextSecondary : Colors.white.withValues(alpha: 0.55),
                ),
              ),
              value: _muteAll,
              activeThumbColor: AppTheme.accentGreen,
              inactiveThumbColor: Colors.white.withValues(alpha: 0.7),
              inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
              activeTrackColor: AppTheme.accentGreen.withValues(alpha: 0.35),
              visualDensity: VisualDensity.compact,
              contentPadding: EdgeInsets.zero,
              onChanged: (bool value) {
                setState(() => _muteAll = value);
              },
            ),
          ),
          const SizedBox(height: 32),
          _sectionLabel('AVAILABLE CAMERAS'),
          const SizedBox(height: 12),
          _buildCard(
            child: _channelStreams.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.videocam_off_rounded,
                              color: Colors.white24, size: 48),
                          SizedBox(height: 12),
                          Text('No cameras detected or scanned.',
                              style: TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 14)),
                        ],
                      ),
                    ),
                  )
                : Column(
                    children: (_channelStreams.keys.toList()..sort()).map((ch) {
                      final isChecked = _selectedChannels.contains(ch);
                      return CheckboxListTile(
                        title: Text('Camera $ch',
                            style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                color: Colors.white)),
                        subtitle: Text('ID: ${ch}02 | Main Stream',
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).brightness == Brightness.light ? AppTheme.lightTextSecondary : Colors.white.withValues(alpha: 0.55),
                            )),
                        value: isChecked,
                        activeColor: AppTheme.accentGreen,
                        checkColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.22),
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              if (!_selectedChannels.contains(ch)) {
                                _selectedChannels.add(ch);
                              }
                            } else {
                              _selectedChannels.remove(ch);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 48),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, {
                'nvrIp': _ipController.text.trim(),
                'nvrUser': _userController.text.trim(),
                'nvrPass': _passController.text.trim(),
                'nvrPort': int.tryParse(_portController.text) ?? 554,
                'channelStreams': _channelStreams,
                'selectedChannels': _selectedChannels..sort(),
                'muteAll': _muteAll,
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Save',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(height: 80),
        ],
      ),
    ),
  );
}

  Widget _sectionLabel(String label) {
    return Text(label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: Colors.white.withValues(alpha: 0.65),
          letterSpacing: 1.2,
        ));
  }

  Widget _buildCard({required Widget child}) {
    return DashboardGlass(
      radius: 22,
      padding: const EdgeInsets.all(20),
      tint: Theme.of(context).brightness == Brightness.light ? Colors.white : const Color(0xFF0E141B).withValues(alpha: 0.92),
      borderColor: Theme.of(context).brightness == Brightness.light ? AppTheme.lightStroke : const Color(0x22FFFFFF),
      child: child,
    );
  }

  Widget _buildField(String label, TextEditingController controller,
      {bool isPass = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        // Match the app's "overlay" input style (solid dark surface + subtle stroke).
        color: Theme.of(context).brightness == Brightness.light ? Colors.black.withValues(alpha: 0.05) : const Color(0xFF0F161E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.20),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SizedBox(
        height: 56,
        child: TextField(
          controller: controller,
          obscureText: isPass,
          cursorColor: Colors.white,
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.light ? AppTheme.lightTextPrimary : Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            hintText: label,
            hintStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.50),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            // Our app theme uses InputDecorationTheme(filled: true,...).
            // Force transparent so no white layer sits on top.
            filled: false,
            fillColor: Colors.transparent,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
          ),
        ),
      ),
    );
  }
}
