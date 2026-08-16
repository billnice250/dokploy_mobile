import 'dart:convert';
import 'dart:typed_data';

import 'package:dokploy_mobile/data/tls_credentials.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pkcs7/pkcs7.dart';

void main() {
  test('normalizes a list of PEM CA certificates', () {
    final pem = utf8.decode(base64Decode(_pemCertificate));
    final normalized = normalizeTrustBundle(
      Uint8List.fromList(utf8.encode('$pem\n$pem')),
    );

    expect(_occurrences(normalized, '-----BEGIN CERTIFICATE-----'), 2);
    expect(() => X509.fromPem(normalized), returnsNormally);
  });

  test('extracts the same X.509 certificate from a DER P7B chain', () {
    final pem = normalizeTrustBundle(base64Decode(_pemCertificate));
    final p7b = normalizeTrustBundle(base64Decode(_p7bChain));

    expect(X509.fromPem(p7b).der, X509.fromPem(pem).der);
  });

  test('shows CN, SHA-1 thumbprint and validity for an imported CA', () {
    final pem = normalizeTrustBundle(base64Decode(_pemCertificate));
    final summary = inspectTrustBundle(pem).single;

    expect(summary.commonName, 'DployGo-Test-CA');
    expect(summary.sha1Thumbprint.split(':'), hasLength(20));
    expect(summary.notAfter.isAfter(summary.notBefore), isTrue);
    expect(
      () => validateCertificateValidity(
        [summary],
        now: DateTime.utc(2026, 8, 16, 12),
      ),
      returnsNormally,
    );
  });

  test('rejects an expired parsed certificate', () {
    final pem = normalizeTrustBundle(base64Decode(_pemCertificate));
    final summary = inspectTrustBundle(pem).single;

    expect(
      () => validateCertificateValidity(
        [summary],
        now: DateTime.utc(2030),
      ),
      throwsFormatException,
    );
  });

  test('rejects files that do not contain certificates', () {
    expect(
      () => normalizeTrustBundle(Uint8List.fromList(utf8.encode('not a CA'))),
      throwsA(anything),
    );
  });
}

int _occurrences(String input, String value) {
  var count = 0;
  var offset = 0;
  while (true) {
    final match = input.indexOf(value, offset);
    if (match < 0) return count;
    count++;
    offset = match + value.length;
  }
}

const _pemCertificate =
    'LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURGVENDQWYyZ0F3SUJBZ0lVSnIwYUFlZXlaRXV5MTVuZ2JUTE1nRmNzOFJVd0RRWUpLb1pJaHZjTkFRRUwKQlFBd0dqRVlNQllHQTFVRUF3d1BSSEJzYjNsSGJ5MVVaWE4wTFVOQk1CNFhEVEkyTURneE5qRXhORFF5TUZvWApEVEkyTURneE56RXhORFF5TUZvd0dqRVlNQllHQTFVRUF3d1BSSEJzYjNsSGJ5MVVaWE4wTFVOQk1JSUJJakFOCkJna3Foa2lHOXcwQkFRRUZBQU9DQVE4QU1JSUJDZ0tDQVFFQW9jTDc0T2JUc3pYTXh3bmlzMkxrVFlmMHd0ZVAKcE1SZmVvU1RaTUNnU1orcWg2RjB5ZS9RbDdqL3NQZTlFTTcxemV4UFVLVER5SGlrSVBQTnN4R1VSN0EzU3JqcgpXN3o0OFVycDhEMDl2YUQ5QXNWZnFlSDh5RlNTMWpmaWlUaDlnMVMwL0tNNU9BUWRVYW4yak5DS0xZV0JOdmw5Cjl3dmMwZEs5R3d5TDFhMlF4ejNUR1dwejBtVm1Ta2JHZE8xRlk5ZTl1aE94Q2hyWTl5S09LT0RFdDN3UzdqN0cKZThtakEzWHRhM3MzWGl5SDFJcGhiWmh4WXAvSlVCWVp4WTc3Y0IyenptOGFldndQWnNpWjFKamJlbmFiN0F5KwpCa2VoODJ1ajRueFdYUVdBRHRLMVhXb1NScFkxVjNhZ3dENmJ0OWkyMEFibnhscjVmdWlIZW1lcEl3SURBUUFCCm8xTXdVVEFkQmdOVkhRNEVGZ1FVbVc4Unk3Q1plWHZ0MU1CVFQ5KzJqU3YrMWtJd0h3WURWUjBqQkJnd0ZvQVUKbVc4Unk3Q1plWHZ0MU1CVFQ5KzJqU3YrMWtJd0R3WURWUjBUQVFIL0JBVXdBd0VCL3pBTkJna3Foa2lHOXcwQgpBUXNGQUFPQ0FRRUFqY1JYRlNjYkk0Q1RqSXZTR1RDNlNmWGxzYkQvN25TYmZ2WjhRbFRoTTNuaFF0SnUvdm8vCkluMU1zM0Uvb2ZsTU1ld3YzS0JhTzcxVDBJdjhIM09ETDU3TXZLMGcxeWpoVGFRc25KUnptT3VWYVprcWgrTEsKcWw4cWlRKzBiQ0ljaElTWmU2bzlnZUJ1ajYrdzlKT0kyQy9CZlJyQ2VsaXBuaXZWaFF0U0JuL3JHYUhZeUptZwpnTWJRUU5CVWxZNzJUREI1QWtZUjh5TTlBNUtQWXA0M01UV1JiSks4VXZUWWY5M3VjeStUK1pLNVJpa3huR2pOCmdROEVCZ2ZDS3F5Y29QK3VnZTVJdE43bGJlamJ3Y1k4VENZRTRKNGFmalczeFdnUHo3akxsWjh6SGZzZ3owNkEKWUE4UkNDYmlKT0U3SjUwU3YzUFNiYzB5VmtsQnczdXNZZz09Ci0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0K';

const _p7bChain =
    'MIIDRAYJKoZIhvcNAQcCoIIDNTCCAzECAQExADALBgkqhkiG9w0BBwGgggMZMIIDFTCCAf2gAwIBAgIUJr0aAeeyZEuy15ngbTLMgFcs8RUwDQYJKoZIhvcNAQELBQAwGjEYMBYGA1UEAwwPRHBsb3lHby1UZXN0LUNBMB4XDTI2MDgxNjExNDQyMFoXDTI2MDgxNzExNDQyMFowGjEYMBYGA1UEAwwPRHBsb3lHby1UZXN0LUNBMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAocL74ObTszXMxwnis2LkTYf0wtePpMRfeoSTZMCgSZ+qh6F0ye/Ql7j/sPe9EM71zexPUKTDyHikIPPNsxGUR7A3SrjrW7z48Urp8D09vaD9AsVfqeH8yFSS1jfiiTh9g1S0/KM5OAQdUan2jNCKLYWBNvl99wvc0dK9GwyL1a2Qxz3TGWpz0mVmSkbGdO1FY9e9uhOxChrY9yKOKODEt3wS7j7Ge8mjA3Xta3s3XiyH1IphbZhxYp/JUBYZxY77cB2zzm8aevwPZsiZ1Jjbenab7Ay+Bkeh82uj4nxWXQWADtK1XWoSRpY1V3agwD6bt9i20Abnxlr5fuiHemepIwIDAQABo1MwUTAdBgNVHQ4EFgQUmW8Ry7CZeXvt1MBTT9+2jSv+1kIwHwYDVR0jBBgwFoAUmW8Ry7CZeXvt1MBTT9+2jSv+1kIwDwYDVR0TAQH/BAUwAwEB/zANBgkqhkiG9w0BAQsFAAOCAQEAjcRXFScbI4CTjIvSGTC6SfXlsbD/7nSbfvZ8QlThM3nhQtJu/vo/In1Ms3E/oflMMewv3KBaO71T0Iv8H3ODL57MvK0g1yjhTaQsnJRzmOuVaZkqh+LKql8qiQ+0bCIchISZe6o9geBuj6+w9JOI2C/BfRrCelipnivVhQtSBn/rGaHYyJmggMbQQNBUlY72TDB5AkYR8yM9A5KPYp43MTWRbJK8UvTYf93ucy+T+ZK5RikxnGjNgQ8EBgfCKqycoP+uge5ItN7lbejbwcY8TCYE4J4afjW3xWgPz7jLlZ8zHfsgz06AYA8RCCbiJOE7J50Sv3PSbc0yVklBw3usYjEA';
