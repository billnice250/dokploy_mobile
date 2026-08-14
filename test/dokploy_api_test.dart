import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dokploy_mobile/data/dokploy_api.dart';
import 'package:dokploy_mobile/domain/failures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses the /api path and sends x-api-key', () async {
    final adapter = _RecordingAdapter();
    final api = DokployApi(
      baseUrl: 'https://dokploy.example.com/',
      apiKey: '  test-token  ',
      adapter: adapter,
    );

    await api.projects();

    expect(
      adapter.request?.uri.toString(),
      'https://dokploy.example.com/api/project.all',
    );
    expect(adapter.request?.headers['x-api-key'], 'test-token');
  });

  test('does not duplicate an /api suffix in the instance URL', () async {
    final adapter = _RecordingAdapter();
    final api = DokployApi(
      baseUrl: 'https://dokploy.example.com/api/',
      apiKey: 'test-token',
      adapter: adapter,
    );

    await api.projects();

    expect(
      adapter.request?.uri.toString(),
      'https://dokploy.example.com/api/project.all',
    );
  });

  group('Dokploy transport failure mapping', () {
    test('maps unauthorized responses without exposing request headers', () {
      final request = RequestOptions(
        path: '/project.all',
        headers: const {'x-api-key': 'must-not-leak'},
      );
      final failure = mapDioFailure(
        DioException(
          requestOptions: request,
          response: Response<dynamic>(
            requestOptions: request,
            statusCode: 401,
            data: const {'message': 'Invalid API token'},
          ),
          type: DioExceptionType.badResponse,
        ),
        'project.all',
      );

      expect(failure.kind, DokployFailureKind.unauthorized);
      expect(failure.operation, 'project.all');
      expect(failure.message, 'Invalid API token');
      expect(failure.toString(), isNot(contains('must-not-leak')));
    });

    test('distinguishes TLS and timeout failures', () {
      final request = RequestOptions(path: '/project.all');

      expect(
        mapDioFailure(
          DioException(
            requestOptions: request,
            type: DioExceptionType.badCertificate,
          ),
          'project.all',
        ).kind,
        DokployFailureKind.tlsFailure,
      );
      expect(
        mapDioFailure(
          DioException(
            requestOptions: request,
            type: DioExceptionType.connectionTimeout,
          ),
          'project.all',
        ).kind,
        DokployFailureKind.timeout,
      );
    });
  });
}

class _RecordingAdapter implements HttpClientAdapter {
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString('[]', 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}
