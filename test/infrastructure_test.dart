import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dokploy_mobile/data/dokploy_api.dart';
import 'package:dokploy_mobile/data/real_repository.dart';
import 'package:dokploy_mobile/domain/terminal_session.dart';
import 'package:dokploy_mobile/domain/models.dart';
import 'package:dokploy_mobile/screens/server_containers.dart';
import 'package:dokploy_mobile/screens/terminal.dart';

void main() {
  test('container inventory and actions preserve host scope', () async {
    final adapter = _Adapter(
        '[{"containerId":"abc123","name":"web","image":"nginx:alpine","ports":"80/tcp","state":"running"}]');
    final api = DokployApi(
        baseUrl: 'https://example.test', apiKey: 'test-key', adapter: adapter);
    final repository = RealDokployRepository(api);
    final items = await repository.serverContainers(serverId: 'remote');
    expect(items.single.image, 'nginx:alpine');
    expect(items.single.running, isTrue);
    expect(adapter.request!.queryParameters, {'serverId': 'remote'});
    await repository.containerAction('abc123', ContainerAction.restart,
        serverId: 'remote');
    expect(adapter.request!.path, 'docker.restartContainer');
    expect(adapter.request!.method, 'POST');
    expect(
        adapter.request!.data, {'containerId': 'abc123', 'serverId': 'remote'});
    await repository.serverContainers();
    expect(adapter.request!.queryParameters, isEmpty);
    await expectLater(api.containerAction('a; rm', ContainerAction.stop),
        throwsArgumentError);
  });

  test('health mapping preserves missing values and reports upstream failure',
      () async {
    final adapter =
        _Adapter('{"resources":{"cpuCount":4},"disk":{"totalBytes":100}}');
    final repository = RealDokployRepository(DokployApi(
        baseUrl: 'https://example.test', apiKey: 'test', adapter: adapter));
    final health = await repository.serverDiagnostics();
    expect(health.cpuCount, 4);
    expect(health.memoryTotal, isNull);
    adapter.response = '{"error":"SSH failed","resources":{"cpuCount":0}}';
    await expectLater(repository.serverDiagnostics(), throwsException);
  });

  test('terminal authenticates by header and sends input and resize frames',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requestReceived = Completer<HttpRequest>();
    final frames = <String>[];
    final received = Completer<void>();
    server.listen((request) async {
      requestReceived.complete(request);
      final socket = await WebSocketTransformer.upgrade(request);
      socket.add('shell ready');
      socket.listen((frame) {
        frames.add(frame as String);
        if (frames.length == 2) received.complete();
      });
    });
    final api = DokployApi(
        baseUrl: 'http://127.0.0.1:${server.port}', apiKey: 'secret');
    final session = await api.openTerminal(serverId: 'remote');
    final output = Completer<String>();
    final subscription = session.output.listen((data) {
      if (!output.isCompleted) output.complete(data);
    });
    final request = await requestReceived.future;
    expect(request.headers.value('x-api-key'), 'secret');
    expect(request.uri.path, '/terminal');
    expect(request.uri.queryParameters['serverId'], 'remote');
    expect(request.uri.toString(), isNot(contains('secret')));
    expect(
        await output.future.timeout(const Duration(seconds: 3)), 'shell ready');
    session.write('pwd\r');
    session.resize(90, 30);
    await received.future.timeout(const Duration(seconds: 3));
    expect(frames.first, 'pwd\r');
    expect(jsonDecode(frames.last), {'type': 'resize', 'cols': 90, 'rows': 30});
    await session.close();
    await subscription.cancel();
    await server.close(force: true);
  });

  testWidgets('demo terminal disconnects when app backgrounds', (tester) async {
    await tester.pumpWidget(const ProviderScope(
        child: MaterialApp(
            home: TerminalScreen(title: 'Demo SSH', serverId: 'demo'))));
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();
    expect(find.text('Connected'), findsOneWidget);
    expect(find.byTooltip('Backspace'), findsOneWidget);
    expect(find.text('Enter'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Disconnected'), findsOneWidget);
  });

  testWidgets('container search and terminal entry fit a narrow phone',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const ProviderScope(
        child: MaterialApp(
            home: ServerContainersScreen(
                server: ServerModel(
                    id: 'demo',
                    name: 'Demo host',
                    host: 'local',
                    status: HealthState.healthy,
                    cpu: 0,
                    memory: 0,
                    disk: 0)))));
    await tester.pumpAndSettle();
    expect(find.text('web'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'postgres');
    await tester.pumpAndSettle();
    expect(find.text('web'), findsNothing);
    expect(find.text('postgres', skipOffstage: true), findsNWidgets(2));
    await tester.tap(find.text('Shell'));
    await tester.pumpAndSettle();
    expect(find.byType(TerminalScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.response);
  String response;
  RequestOptions? request;
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    request = options;
    return ResponseBody.fromString(response, 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
  }

  @override
  void close({bool force = false}) {}
}
