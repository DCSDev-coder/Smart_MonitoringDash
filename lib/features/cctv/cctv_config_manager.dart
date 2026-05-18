import 'dart:convert';
import 'cctv_config_store.dart';

class CctvConfigManager {
  static const String prefsNvrIp = 'cctv_nvr_ip';
  static const String prefsNvrPort = 'cctv_nvr_port';
  static const String prefsNvrUser = 'cctv_nvr_user';
  static const String prefsNvrPass = 'cctv_nvr_pass';
  static const String prefsChannelStreams = 'cctv_channel_streams';
  static const String prefsSelectedChannels = 'cctv_selected_channels';
  static const String prefsMuteAll = 'cctv_mute_all';

  static Future<Map<String, dynamic>> loadConfig() async {
    final encodedStreams = await cctvConfigStore.getString(prefsChannelStreams);
    final encodedSelected = await cctvConfigStore.getString(prefsSelectedChannels);
    final savedIp = await cctvConfigStore.getString(prefsNvrIp);
    final savedPort = await cctvConfigStore.getInt(prefsNvrPort);
    final savedUser = await cctvConfigStore.getString(prefsNvrUser);
    final savedPass = await cctvConfigStore.getString(prefsNvrPass);
    final savedMuteAll = await cctvConfigStore.getBool(prefsMuteAll);

    final loadedStreams = <int, String>{};
    if (encodedStreams != null && encodedStreams.isNotEmpty) {
      final decoded = jsonDecode(encodedStreams);
      if (decoded is Map<String, dynamic>) {
        for (final entry in decoded.entries) {
          final key = int.tryParse(entry.key);
          final value = entry.value?.toString();
          if (key != null && value != null && value.isNotEmpty) {
            loadedStreams[key] = value;
          }
        }
      }
    }

    final loadedSelected = <int>[];
    if (encodedSelected != null && encodedSelected.isNotEmpty) {
      final decoded = jsonDecode(encodedSelected);
      if (decoded is List) {
        for (final item in decoded) {
          final value = int.tryParse(item.toString());
          if (value != null) {
            loadedSelected.add(value);
          }
        }
      }
    }

    return {
      'nvrIp': savedIp ?? '192.168.1.8',
      'nvrPort': savedPort ?? 554,
      'nvrUser': savedUser ?? 'admin',
      'nvrPass': savedPass ?? '',
      'channelStreams': loadedStreams,
      'selectedChannels': loadedSelected,
      'muteAll': savedMuteAll ?? true,
    };
  }

  static Future<void> persistConfig(Map<String, dynamic> config) async {
    await cctvConfigStore.setString(prefsNvrIp, config['nvrIp']);
    await cctvConfigStore.setInt(prefsNvrPort, config['nvrPort']);
    await cctvConfigStore.setString(prefsNvrUser, config['nvrUser']);
    await cctvConfigStore.setString(prefsNvrPass, config['nvrPass']);
    
    final Map<int, String> streams = Map<int, String>.from(config['channelStreams']);
    await cctvConfigStore.setString(
      prefsChannelStreams,
      jsonEncode(streams.map((key, value) => MapEntry(key.toString(), value))),
    );
    
    final List<int> selected = List<int>.from(config['selectedChannels']);
    await cctvConfigStore.setString(
      prefsSelectedChannels,
      jsonEncode(selected),
    );
    
    await cctvConfigStore.setBool(prefsMuteAll, config['muteAll'] ?? true);
  }
}
