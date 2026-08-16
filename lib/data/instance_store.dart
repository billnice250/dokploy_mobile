import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models.dart';
import 'tls_credentials.dart';

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
            authMode: InstanceAuthMode.values.firstWhere(
              (value) => value.name == json['authMode'],
              orElse: () => InstanceAuthMode.apiKey,
            ),
            hasCustomCa: json['hasCustomCa'] == true,
            hasClientCertificate: json['hasClientCertificate'] == true,
            caFileName: json['caFileName'] is String
                ? json['caFileName'] as String
                : '',
            clientCertificateFileName:
                json['clientCertificateFileName'] is String
                    ? json['clientCertificateFileName'] as String
                    : '',
          ),
        );
      } on FormatException {
        // A malformed profile must not prevent other instances from loading.
      }
    }
    return instances;
  }

  Future<void> save(
    DokployInstance instance,
    String apiKey, {
    String caPemBundle = '',
    List<int>? clientPkcs12,
    String clientPkcs12Password = '',
    bool setActiveInstance = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final instances = await load();
    final next = [
      ...instances.where((item) => item.id != instance.id),
      instance,
    ];
    await prefs.setStringList(
      _instancesKey,
      next.map((item) => jsonEncode(_instanceJson(item))).toList(),
    );
    await _writeOrDelete(_secretKey(instance.id), apiKey);
    await _writeOrDelete(_caKey(instance.id), caPemBundle);
    await _writeOrDelete(
      _clientCertificateKey(instance.id),
      clientPkcs12 == null ? '' : base64Encode(clientPkcs12),
    );
    await _writeOrDelete(
      _clientCertificatePasswordKey(instance.id),
      clientPkcs12Password,
    );
    if (setActiveInstance) await setActive(instance.id);
  }

  Future<String?> apiKey(String id) => _secure.read(key: _secretKey(id));

  Future<InstanceSecrets> secrets(String id) async {
    final values = await Future.wait([
      _secure.read(key: _secretKey(id)),
      _secure.read(key: _caKey(id)),
      _secure.read(key: _clientCertificateKey(id)),
      _secure.read(key: _clientCertificatePasswordKey(id)),
    ]);
    final encodedClientCertificate = values[2];
    return InstanceSecrets(
      apiKey: values[0] ?? '',
      caPemBundle: values[1] ?? '',
      clientPkcs12:
          encodedClientCertificate == null || encodedClientCertificate.isEmpty
              ? null
              : base64Decode(encodedClientCertificate),
      clientPkcs12Password: values[3] ?? '',
    );
  }

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
          .map((item) => jsonEncode(_instanceJson(item)))
          .toList(),
    );
    if (await activeId() == id) await prefs.remove(_activeKey);
    await _secure.delete(key: _secretKey(id));
    await _secure.delete(key: _caKey(id));
    await _secure.delete(key: _clientCertificateKey(id));
    await _secure.delete(key: _clientCertificatePasswordKey(id));
  }

  Map<String, dynamic> _instanceJson(DokployInstance item) => {
        'id': item.id,
        'name': item.name,
        'baseUrl': item.baseUrl,
        'version': item.version,
        'authMode': item.authMode.name,
        'hasCustomCa': item.hasCustomCa,
        'hasClientCertificate': item.hasClientCertificate,
        'caFileName': item.caFileName,
        'clientCertificateFileName': item.clientCertificateFileName,
      };

  Future<void> _writeOrDelete(String key, String value) => value.isEmpty
      ? _secure.delete(key: key)
      : _secure.write(key: key, value: value);

  String _secretKey(String id) => 'dokploy_api_key_$id';
  String _caKey(String id) => 'dokploy_ca_bundle_$id';
  String _clientCertificateKey(String id) => 'dokploy_client_pkcs12_$id';
  String _clientCertificatePasswordKey(String id) =>
      'dokploy_client_pkcs12_password_$id';
}
