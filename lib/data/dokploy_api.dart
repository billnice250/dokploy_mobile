import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../domain/failures.dart';

/// Thin RPC-style Dokploy transport. Endpoint names and transport failures stay
/// here so they cannot leak into widgets or app-owned domain models.
class DokployApi {
  DokployApi({
    required String baseUrl,
    required String apiKey,
    HttpClientAdapter? adapter,
  })  : monitoringCallbackUrl = _monitoringCallbackUrl(baseUrl),
        _dio = Dio(
          BaseOptions(
            baseUrl: _apiBaseUrl(baseUrl),
            connectTimeout: const Duration(seconds: 10),
            sendTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 30),
            headers: {
              'x-api-key': apiKey.trim(),
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
          ),
        ) {
    if (adapter != null) _dio.httpClientAdapter = adapter;
    if (kDebugMode) {
      _dio.interceptors.add(_SafeHttpLogger(apiKey.trim()));
    }
  }

  final Dio _dio;

  /// Public callback consumed by Dokploy's monitoring sidecar for threshold
  /// events. This must be an absolute URL even when thresholds are disabled.
  final String monitoringCallbackUrl;

  Future<dynamic> get(
    String procedure, [
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  ]) async {
    try {
      return (await _dio.get<dynamic>(
        procedure,
        queryParameters: query,
        cancelToken: cancelToken,
      ))
          .data;
    } on DioException catch (error) {
      throw mapDioFailure(error, procedure);
    }
  }

  Future<dynamic> post(
    String procedure, [
    Map<String, dynamic>? body,
    CancelToken? cancelToken,
  ]) async {
    try {
      // Mutations are deliberately never retried here.
      return (await _dio.post<dynamic>(
        procedure,
        data: body ?? const {},
        cancelToken: cancelToken,
      ))
          .data;
    } on DioException catch (error) {
      throw mapDioFailure(error, procedure);
    }
  }

  Future<dynamic> projects() => get('project.all');
  Future<dynamic> permissions() => get('user.getPermissions');
  Future<dynamic> homeStats() => get('project.homeStats');
  Future<dynamic> project(String id) => get('project.one', {'projectId': id});

  Future<dynamic> application(String id) =>
      get('application.one', {'applicationId': id});
  Future<dynamic> applicationMonitoring(String appName) =>
      get('application.readAppMonitoring', {'appName': appName});
  Future<dynamic> applicationLogs(String id, {int tail = 200}) => get(
        'application.readLogs',
        {'applicationId': id, 'tail': tail.clamp(1, 10000)},
      );
  Future<void> startApplication(String id) async =>
      post('application.start', {'applicationId': id});
  Future<void> stopApplication(String id) async =>
      post('application.stop', {'applicationId': id});
  Future<void> redeployApplication(String id) async =>
      post('application.redeploy', {'applicationId': id});

  Future<dynamic> compose(String id) => get('compose.one', {'composeId': id});
  Future<dynamic> composeServices(String id) =>
      get('compose.loadServices', {'composeId': id});
  Future<void> deployCompose(String id) async =>
      post('compose.deploy', {'composeId': id});
  Future<void> stopCompose(String id) async =>
      post('compose.stop', {'composeId': id});
  Future<void> startCompose(String id) async =>
      post('compose.start', {'composeId': id});

  Future<dynamic> deploymentsByApplication(String id) =>
      get('deployment.all', {'applicationId': id});
  Future<dynamic> deploymentsByCompose(String id) =>
      get('deployment.allByCompose', {'composeId': id});
  Future<dynamic> deploymentsCentralized() => get('deployment.allCentralized');
  Future<dynamic> deploymentQueue() => get('deployment.queueList');
  Future<dynamic> deploymentLogs(String id, {int tail = 500}) => get(
        'deployment.readLogs',
        {'deploymentId': id, 'tail': tail.clamp(1, 10000)},
      );
  Future<void> cancelDeployment(String id) async =>
      post('deployment.killProcess', {'deploymentId': id});

  Future<dynamic> servers() => get('server.all');
  Future<dynamic> metricsConfig() => get('user.getMetricsToken');
  Future<dynamic> serverMetrics({
    required String url,
    required String token,
    int dataPoints = 1,
  }) =>
      get('server.getServerMetrics', {
        'url': url,
        'token': token,
        'dataPoints': '$dataPoints',
      });
  Future<void> setupControlPlaneMonitoring(
    Map<String, dynamic> metricsConfig,
  ) async =>
      post('admin.setupMonitoring', {'metricsConfig': metricsConfig});
  Future<void> setupServerMonitoring(
    String serverId,
    Map<String, dynamic> metricsConfig,
  ) async =>
      post('server.setupMonitoring', {
        'serverId': serverId,
        'metricsConfig': metricsConfig,
      });
  Future<void> cleanDockerPrune({String? serverId}) async => post(
        'settings.cleanDockerPrune',
        {if (serverId != null) 'serverId': serverId},
      );

  Future<dynamic> postgres(String id) =>
      get('postgres.one', {'postgresId': id});
  Future<dynamic> postgresLogs(String id) =>
      get('postgres.readLogs', {'postgresId': id});
  Future<void> startPostgres(String id) async =>
      post('postgres.start', {'postgresId': id});
  Future<void> stopPostgres(String id) async =>
      post('postgres.stop', {'postgresId': id});
  Future<void> deployPostgres(String id) async =>
      post('postgres.deploy', {'postgresId': id});
}

String _apiBaseUrl(String input) {
  final uri = Uri.parse(input.trim());
  var path = uri.path.replaceAll(RegExp(r'/+$'), '');
  if (!path.endsWith('/api')) path = '$path/api';
  return uri.replace(path: '$path/').toString();
}

String _monitoringCallbackUrl(String input) {
  final uri = Uri.parse(input.trim());
  return uri
      .replace(
        path: '/api/trpc/notification.receiveNotification',
        query: null,
        fragment: null,
      )
      .toString();
}

class _SafeHttpLogger extends Interceptor {
  _SafeHttpLogger(this.apiKey) {
    _write(
      'configured x-api-key: ${_credentialDescription(apiKey)}',
    );
  }

  final String apiKey;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra['_dokployLogStartedAt'] =
        DateTime.now().microsecondsSinceEpoch;
    _write('→ ${options.method} ${_safeUri(options.uri)}');
    _write('  headers: ${_sanitize(options.headers)}');
    if (options.data != null) _write('  body: ${_format(options.data)}');
    handler.next(options);
  }

  @override
  void onResponse(
      Response<dynamic> response, ResponseInterceptorHandler handler) {
    _write(
      '← ${response.statusCode} ${response.requestOptions.method} '
      '${_safeUri(response.requestOptions.uri)} '
      '(${_elapsed(response.requestOptions)})',
    );
    _write('  response: ${_format(response.data)}');
    handler.next(response);
  }

  @override
  void onError(DioException error, ErrorInterceptorHandler handler) {
    final response = error.response;
    _write(
      '← ERROR ${response?.statusCode ?? error.type.name} '
      '${error.requestOptions.method} ${_safeUri(error.requestOptions.uri)} '
      '(${_elapsed(error.requestOptions)})',
    );
    if (response?.data != null) {
      _write('  response: ${_format(response?.data)}');
    }
    _write('  message: ${error.message}');
    handler.next(error);
  }

  String _elapsed(RequestOptions options) {
    final started = options.extra['_dokployLogStartedAt'];
    if (started is! int) return 'unknown duration';
    final elapsed = DateTime.now().microsecondsSinceEpoch - started;
    return '${(elapsed / 1000).round()} ms';
  }

  String _format(dynamic value) {
    final rendered = '${_sanitize(value)}';
    const limit = 4000;
    return rendered.length <= limit
        ? rendered
        : '${rendered.substring(0, limit)}… <truncated>';
  }

  dynamic _sanitize(dynamic value, {String? key}) {
    if (key != null && _isSensitiveKey(key)) {
      if (key.toLowerCase() == 'x-api-key' && value is String) {
        return _credentialDescription(value);
      }
      return '<redacted>';
    }
    if (value is Map) {
      return value.map(
        (entryKey, entryValue) => MapEntry(
          '$entryKey',
          _sanitize(entryValue, key: '$entryKey'),
        ),
      );
    }
    if (value is Iterable) return value.map(_sanitize).toList();
    return value;
  }

  bool _isSensitiveKey(String key) {
    final normalized = key.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    return normalized.contains('password') ||
        normalized.contains('secret') ||
        normalized.contains('token') ||
        normalized.contains('apikey') ||
        normalized.contains('authorization') ||
        normalized.contains('cookie') ||
        normalized == 'env';
  }

  Uri _safeUri(Uri uri) {
    if (uri.queryParameters.isEmpty) return uri;
    return uri.replace(
      queryParameters: uri.queryParameters.map(
        (key, value) => MapEntry(
          key,
          _isSensitiveKey(key) ? '<redacted>' : value,
        ),
      ),
    );
  }

  String _credentialDescription(String value) {
    final normalized = value.trim();
    final fingerprint = sha256.convert(utf8.encode(normalized)).toString();
    final whitespace =
        normalized.length == value.length ? '' : ', whitespace-trimmed';
    return '<redacted length=${normalized.length}, '
        'sha256=${fingerprint.substring(0, 12)}$whitespace>';
  }

  void _write(String message) => debugPrint('[Dokploy HTTP] $message');
}

DokployFailure mapDioFailure(DioException error, String operation) {
  final status = error.response?.statusCode;
  final serverMessage = _serverMessage(error.response?.data);
  final kind = status != null && status >= 500
      ? DokployFailureKind.server
      : switch (status) {
          400 || 422 => DokployFailureKind.validation,
          401 => DokployFailureKind.unauthorized,
          403 => DokployFailureKind.forbidden,
          404 => DokployFailureKind.notFound,
          409 => DokployFailureKind.conflict,
          _ => switch (error.type) {
              DioExceptionType.connectionTimeout ||
              DioExceptionType.sendTimeout ||
              DioExceptionType.receiveTimeout =>
                DokployFailureKind.timeout,
              DioExceptionType.badCertificate => DokployFailureKind.tlsFailure,
              DioExceptionType.connectionError =>
                DokployFailureKind.connectionFailed,
              _ => DokployFailureKind.unknown,
            },
        };
  final fallback = switch (kind) {
    DokployFailureKind.unauthorized => 'The API key was rejected.',
    DokployFailureKind.forbidden =>
      'The API key lacks permission for this operation.',
    DokployFailureKind.notFound =>
      'The requested Dokploy resource was not found.',
    DokployFailureKind.connectionFailed =>
      'Could not connect to the Dokploy instance.',
    DokployFailureKind.tlsFailure =>
      'The server certificate could not be verified.',
    DokployFailureKind.timeout => 'The Dokploy request timed out.',
    DokployFailureKind.conflict => 'Dokploy reported a conflicting operation.',
    DokployFailureKind.validation => 'Dokploy rejected the request data.',
    DokployFailureKind.server => 'Dokploy reported a server error.',
    _ => 'The Dokploy request failed.',
  };
  return DokployFailure(
    kind: kind,
    operation: operation,
    message: serverMessage ?? fallback,
    statusCode: status,
  );
}

String? _serverMessage(dynamic data) {
  if (data is Map && data['message'] is String) {
    final message = (data['message'] as String).trim();
    return message.isEmpty ? null : message;
  }
  return null;
}
