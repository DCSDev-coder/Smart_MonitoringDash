class SiteRuntimeConfig {
  SiteRuntimeConfig._();

  static int? siteId(Map<String, dynamic>? site) {
    if (site == null) return null;
    return int.tryParse(site['site_id']?.toString() ?? '') ??
        int.tryParse(site['id']?.toString() ?? '');
  }

  static String? cabinetId(Map<String, dynamic>? site) {
    if (site == null) return null;
    final raw = (site['dahua_cabinet_id'] ??
            site['cabinet_id'] ??
            site['cabinetId'] ??
            site['rack_cabinet_id'] ??
            site['cabinet_no'])
        ?.toString();
    if (raw == null || raw.trim().isEmpty) return null;
    return int.tryParse(raw.trim())?.toString();
  }

  static Map<String, dynamic>? nodesConfig(Map<String, dynamic>? site) {
    final nodes = site?['app_config_nodes'];
    if (nodes is Map<String, dynamic>) return nodes;
    if (nodes is Map) {
      return nodes.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
  }

  static String metricCodeForNode(
    Map<String, dynamic>? site,
    int nodeId, {
    required String fallback,
  }) {
    final nodes = nodesConfig(site);
    if (nodes == null) return fallback;
    final cfg = nodes[nodeId.toString()];
    if (cfg is! Map) return fallback;
    final map = Map<String, dynamic>.from(cfg);
    const candidates = <String>[
      'active_power',
      'active_power_metric',
      'power_metric',
      'metric_active_power',
      'active_power_single_phase',
      'metricTypeLibCode',
    ];
    for (final key in candidates) {
      final v = map[key]?.toString().trim();
      if (v != null && v.isNotEmpty) return v;
    }
    return fallback;
  }

  static int? nodeIdForType(
    Map<String, dynamic>? site, {
    required String type,
    int? fallbackNodeId,
  }) {
    final nodes = nodesConfig(site);
    if (nodes == null || nodes.isEmpty) return fallbackNodeId;

    final wanted = type.trim().toLowerCase();
    for (final entry in nodes.entries) {
      final cfg = entry.value;
      if (cfg is! Map) continue;
      final map = Map<String, dynamic>.from(cfg);
      final candidates = <String>[
        map['nodeTypeName']?.toString() ?? '',
        map['node_type_name']?.toString() ?? '',
        map['nodeTypeCode']?.toString() ?? '',
        map['node_type_code']?.toString() ?? '',
        map['typeName']?.toString() ?? '',
        map['type_name']?.toString() ?? '',
        map['type']?.toString() ?? '',
        map['name']?.toString() ?? '',
        map['label']?.toString() ?? '',
      ].map((v) => v.trim().toLowerCase()).where((v) => v.isNotEmpty);

      final matched = candidates.any(
        (value) => value == wanted || value.contains(wanted),
      );
      if (!matched) continue;

      final id = int.tryParse(entry.key);
      if (id != null) return id;

      final explicitId = int.tryParse(
        map['id']?.toString() ??
            map['nodeId']?.toString() ??
            map['node_id']?.toString() ??
            '',
      );
      if (explicitId != null) return explicitId;
    }

    return fallbackNodeId;
  }
}

