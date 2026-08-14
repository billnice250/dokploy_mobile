import 'package:dokploy_mobile/data/dokploy_api.dart';
import 'package:dokploy_mobile/data/real_repository.dart';
import 'package:dokploy_mobile/domain/failures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps Dokploy permission flags into capabilities', () async {
    final repository = RealDokployRepository(
      _FakeApi(
        permissionPayload: const {
          'service': {'read': true},
          'deployment': {'read': true, 'create': true, 'cancel': false},
          'logs': {'read': true},
          'server': {'read': false},
          'monitoring': {'read': false},
        },
      ),
    );

    final capabilities = await repository.capabilities();

    expect(capabilities.deployments, isTrue);
    expect(capabilities.lifecycle, isTrue);
    expect(capabilities.cancelDeployments, isFalse);
    expect(capabilities.logs, isTrue);
    expect(capabilities.servers, isFalse);
  });

  test('does not call optional endpoints denied by permissions', () async {
    final api = _FakeApi();
    final repository = RealDokployRepository(api);

    expect(await repository.deployments(), isEmpty);
    expect(await repository.servers(), isEmpty);
    expect(api.deploymentCalls, 0);
    expect(api.serverCalls, 0);
  });

  test('maps the nested project.all hierarchy without project.one', () async {
    final api = _FakeApi(projectPayload: _projectFixture);
    final repository = RealDokployRepository(api);

    final projects = await repository.projects();
    final services = await repository.services();

    expect(projects.single.name, 'Home media server');
    expect(projects.single.environmentCount, 1);
    expect(projects.single.serviceCount, 3);
    expect(
      services.map((service) => service.name),
      containsAll(['fixaar', 'plex', 'jellyfin']),
    );
    expect(api.projectOneCalls, 0);
  });

  test('server permission denial does not break the dashboard', () async {
    final repository = RealDokployRepository(
      _FakeApi(
        serverFailure: _unauthorized('server.all'),
        permissionPayload: const {
          'server': {'read': true},
        },
      ),
    );

    final dashboard = await repository.dashboard();

    expect(dashboard.servers, isEmpty);
    expect(dashboard.projects, isEmpty);
  });

  test('core project authentication denial is not swallowed', () async {
    final repository = RealDokployRepository(
      _FakeApi(projectFailure: _unauthorized('project.all')),
    );

    await expectLater(
      repository.projects(),
      throwsA(
        isA<DokployFailure>().having(
          (failure) => failure.kind,
          'kind',
          DokployFailureKind.unauthorized,
        ),
      ),
    );
  });

  test('maps deployment detail metadata and bounded logs', () async {
    final repository = RealDokployRepository(
      _FakeApi(
        permissionPayload: const {
          'deployment': {'read': true},
        },
        deploymentPayload: const [
          {
            'deploymentId': 'deployment-1',
            'title': 'Manual deployment',
            'status': 'done',
            'createdAt': '2026-08-14T10:00:00.000Z',
            'startedAt': '2026-08-14T10:00:01.000Z',
            'finishedAt': '2026-08-14T10:00:06.000Z',
            'errorMessage': null,
            'composeId': 'compose-1',
            'compose': {'composeId': 'compose-1', 'name': 'jellyfin'},
          },
        ],
        deploymentLogPayload: 'building\ndeploying\ndone',
      ),
    );

    final deployment = (await repository.deployments()).single;
    final logs = await repository.deploymentLogs(deployment.id, tail: 3);

    expect(deployment.service, 'jellyfin');
    expect(deployment.serviceId, 'compose-1');
    expect(deployment.title, 'Manual deployment');
    expect(deployment.durationSeconds, 5);
    expect(logs, ['building', 'deploying', 'done']);
  });
}

DokployFailure _unauthorized(String operation) => DokployFailure(
      kind: DokployFailureKind.unauthorized,
      operation: operation,
      message: 'Unauthorized',
      statusCode: 401,
    );

class _FakeApi extends DokployApi {
  _FakeApi({
    this.serverFailure,
    this.projectFailure,
    this.projectPayload = const <dynamic>[],
    this.permissionPayload = const <String, dynamic>{},
    this.deploymentPayload = const <dynamic>[],
    this.deploymentLogPayload = '',
  }) : super(baseUrl: 'https://dokploy.example.com', apiKey: 'test-token');

  final DokployFailure? serverFailure;
  final DokployFailure? projectFailure;
  final dynamic projectPayload;
  final dynamic permissionPayload;
  final dynamic deploymentPayload;
  final dynamic deploymentLogPayload;
  int projectOneCalls = 0;
  int deploymentCalls = 0;
  int serverCalls = 0;

  @override
  Future<dynamic> projects() async {
    if (projectFailure case final failure?) throw failure;
    return projectPayload;
  }

  @override
  Future<dynamic> permissions() async => permissionPayload;

  @override
  Future<dynamic> project(String id) async {
    projectOneCalls++;
    throw StateError('project.one should not be needed for project.all data');
  }

  @override
  Future<dynamic> deploymentsCentralized() async {
    deploymentCalls++;
    return deploymentPayload;
  }

  @override
  Future<dynamic> deploymentLogs(String id, {int tail = 500}) async =>
      deploymentLogPayload;

  @override
  Future<dynamic> servers() async {
    serverCalls++;
    if (serverFailure case final failure?) throw failure;
    return <dynamic>[];
  }
}

const _projectFixture = <dynamic>[
  {
    'projectId': 'project-1',
    'name': 'Home media server',
    'description': '',
    'environments': [
      {
        'environmentId': 'environment-1',
        'name': 'production',
        'applications': [
          {
            'applicationId': 'application-1',
            'name': 'fixaar',
            'applicationStatus': 'done',
          },
        ],
        'compose': [
          {
            'composeId': 'compose-1',
            'name': 'plex',
            'composeStatus': 'done',
          },
          {
            'composeId': 'compose-2',
            'name': 'jellyfin',
            'composeStatus': 'done',
          },
        ],
        'postgres': <dynamic>[],
        'mysql': <dynamic>[],
        'mariadb': <dynamic>[],
        'mongo': <dynamic>[],
        'redis': <dynamic>[],
      },
    ],
  },
];
