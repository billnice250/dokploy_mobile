import 'package:dio/dio.dart';
import 'package:dokploy_mobile/data/dokploy_api.dart';
import 'package:dokploy_mobile/domain/failures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
