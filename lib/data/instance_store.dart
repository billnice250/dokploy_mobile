import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models.dart';

class InstanceStore {
  const InstanceStore(
      {FlutterSecureStorage secure = const FlutterSecureStorage()})
      : _secure = secure;

  static const _instancesKey = 'dokploy_instances_v1';
  static const _activeKey = 'dokploy_active_instance_v1';
  final FlutterSecureStorage _secure;

  Future<List<DokployInstance>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getStringList(_instancesKey) ??
        prefs.getStringList('instances') ??
        const <String>[];
    final instances = <DokployInstance>[];
    for (final value in encoded) {
      try {
        final json = jsonDecode(value);
        if (json is! Map<String, dynamic>) continue;
        final id = json['id'];
        final name = json['name'];
        final baseUrl = json['baseUrl'];
        if (id is! String || name is! String || baseUrl is! String) continue;
        instances.add(
          DokployInstance(
            id: id,
            name: name,
            baseUrl: baseUrl,
            version: json['version'] is String
                ? json['version'] as String
                : 'unknown',
          ),
        );
      } on FormatException {
        // A malformed profile must not prevent other instances from loading.
      }
    }
    return instances;
  }

  Future<void> save(DokployInstance instance, String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    final instances = await load();
    final next = [
      ...instances.where((item) => item.id != instance.id),
      instance,
    ];
    await prefs.setStringList(
      _instancesKey,
      next
          .map(
            (item) => jsonEncode({
              'id': item.id,
              'name': item.name,
              'baseUrl': item.baseUrl,
              'version': item.version,
            }),
          )
          .toList(),
    );
    await _secure.write(key: _secretKey(instance.id), value: apiKey);
    await setActive(instance.id);
  }

  Future<String?> apiKey(String id) => _secure.read(key: _secretKey(id));

  Future<String?> activeId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeKey);
  }

  Future<void> setActive(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeKey, id);
  }

  Future<void> remove(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final instances = await load();
    await prefs.setStringList(
      _instancesKey,
      instances
          .where((item) => item.id != id)
          .map(
            (item) => jsonEncode({
              'id': item.id,
              'name': item.name,
              'baseUrl': item.baseUrl,
              'version': item.version,
            }),
          )
          .toList(),
    );
    if (await activeId() == id) await prefs.remove(_activeKey);
    await _secure.delete(key: _secretKey(id));
  }

  String _secretKey(String id) => 'dokploy_api_key_$id';
}
