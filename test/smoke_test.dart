import 'package:flutter_test/flutter_test.dart';
import 'package:dokploy_mobile/data/mock_repository.dart';

void main() {
  test('demo repository exposes a useful dashboard', () async {
    final d = await MockDokployRepository().dashboard();
    expect(d.running, greaterThan(0));
    expect(d.deployments, isNotEmpty);
  });
}
