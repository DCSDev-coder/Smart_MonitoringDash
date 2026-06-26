String alarmSearchText(dynamic alarm) {
  if (alarm is! Map) return alarm?.toString().toLowerCase() ?? '';

  final parts = <String>[
    alarm['msg']?.toString() ?? '',
    alarm['content']?.toString() ?? '',
    alarm['alarmMsg']?.toString() ?? '',
    alarm['message']?.toString() ?? '',
    alarm['alarmItem']?.toString() ?? '',
    alarm['alarmItemName']?.toString() ?? '',
    alarm['alarmName']?.toString() ?? '',
    alarm['name']?.toString() ?? '',
    alarm['collectControlNodeName']?.toString() ?? '',
    alarm['deviceCabinetName']?.toString() ?? '',
    alarm['deviceCabinetItemName']?.toString() ?? '',
    alarm['locationName']?.toString() ?? '',
    alarm['alarmTypeName']?.toString() ?? '',
    alarm['alarmType']?.toString() ?? '',
    alarm['alarmLevelLevel']?.toString() ?? '',
    alarm['alarmLevelName']?.toString() ?? '',
  ];

  return parts.where((part) => part.trim().isNotEmpty).join(' ').toLowerCase();
}

String alarmDisplayText(dynamic alarm) {
  if (alarm is! Map) return alarm?.toString() ?? 'Alarm';

  final title = [
    alarm['alarmItem'],
    alarm['alarmItemName'],
    alarm['alarmName'],
    alarm['msg'],
    alarm['content'],
    alarm['message'],
    alarm['name'],
  ].map((value) => value?.toString().trim() ?? '').firstWhere(
        (value) => value.isNotEmpty,
        orElse: () => 'Alarm',
      );

  return title;
}

bool alarmIsResolved(dynamic alarm) {
  if (alarm is! Map) return false;
  if (alarm['recoveryTime'] != null ||
      alarm['recoverTime'] != null ||
      alarm['clearTime'] != null ||
      alarm['endTime'] != null) {
    return true;
  }

  final status = (alarm['statusTxt'] ?? alarm['status'] ?? '')
      .toString()
      .trim()
      .toLowerCase();
  return status == 'resolved' ||
      status == 'recover' ||
      status == 'recovered' ||
      status == 'clear' ||
      status == 'cleared' ||
      status == 'closed';
}
