import 'package:dio/dio.dart';

import '../domain/failures.dart';

/// Thin RPC-style Dokploy transport. Endpoint names and transport failures stay
/// here so they cannot leak into widgets or app-owned domain models.
class DokployApi {
  DokployApi({required String baseUrl, required String apiKey})
      : _dio = Dio(
          BaseOptions(
            baseUrl: '${baseUrl.replaceAll(RegExp(r'/$'), '')}/api',
            connectTimeout: const Duration(seconds: 10),
            sendTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 30),
            headers: {
              'x-api-key': apiKey,
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
          ),
        );

  final Dio _dio;

  Future<dynamic> get(
    String procedure, [
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  ]) async {
    try {
      return (await _dio.get<dynamic>(
        '/$procedure',
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
        '/$procedure',
        data: body ?? const {},
        cancelToken: cancelToken,
      ))
          .data;
    } on DioException catch (error) {
      throw mapDioFailure(error, procedure);
    }
  }

  Future<dynamic> projects() => get('project.all');
  Future<dynamic> homeStats() => get('project.homeStats');
  Future<dynamic> project(String id) => get('project.one', {'projectId': id});

  Future<dynamic> application(String id) =>
      get('application.one', {'applicationId': id});
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
