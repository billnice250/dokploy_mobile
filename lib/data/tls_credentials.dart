import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:pkcs7/pkcs7.dart';

import '../domain/models.dart';

class InstanceSecrets {
  const InstanceSecrets({
    this.apiKey = '',
    this.caPemBundle = '',
    this.clientPkcs12,
    this.clientPkcs12Password = '',
  });

  final String apiKey;
  final String caPemBundle;
  final Uint8List? clientPkcs12;
  final String clientPkcs12Password;

  bool get hasCustomCa => caPemBundle.trim().isNotEmpty;
  bool get hasClientCertificate => clientPkcs12?.isNotEmpty == true;
}

String normalizeTrustBundle(Uint8List bytes) {
  if (bytes.isEmpty) throw const FormatException('The CA file is empty.');
  final text = utf8.decode(bytes, allowMalformed: true);
  final certificates = <X509>[];
  if (text.contains('-----BEGIN CERTIFICATE-----')) {
    for (final block in _pemBlocks(
      text,
      '-----BEGIN CERTIFICATE-----',
      '-----END CERTIFICATE-----',
    )) {
      certificates.add(X509.fromPem(block));
    }
  } else {
    final container = text.contains('-----BEGIN PKCS7-----')
        ? Pkcs7.fromPem(text)
        : Pkcs7.fromDer(bytes);
    certificates.addAll(container.certificates);
  }
  if (certificates.isEmpty) {
    throw const FormatException('No X.509 certificates were found.');
  }
  return certificates.map((certificate) => certificate.pem.trim()).join('\n');
}

SecurityContext buildSecurityContext(
  DokployInstance instance,
  InstanceSecrets secrets,
) {
  final context = SecurityContext(withTrustedRoots: true);
  if (instance.hasCustomCa && secrets.hasCustomCa) {
    final blocks = _pemBlocks(
      secrets.caPemBundle,
      '-----BEGIN CERTIFICATE-----',
      '-----END CERTIFICATE-----',
    );
    if (Platform.isIOS) {
      for (final block in blocks) {
        context.setTrustedCertificatesBytes(X509.fromPem(block).der);
      }
    } else {
      context.setTrustedCertificatesBytes(utf8.encode(secrets.caPemBundle));
    }
  }
  if (instance.hasClientCertificate && secrets.hasClientCertificate) {
    final bytes = secrets.clientPkcs12!;
    final password = secrets.clientPkcs12Password.isEmpty
        ? null
        : secrets.clientPkcs12Password;
    context.useCertificateChainBytes(bytes, password: password);
    context.usePrivateKeyBytes(bytes, password: password);
  }
  return context;
}

List<String> _pemBlocks(String input, String begin, String end) {
  final blocks = <String>[];
  var offset = 0;
  while (true) {
    final start = input.indexOf(begin, offset);
    if (start < 0) break;
    final finish = input.indexOf(end, start + begin.length);
    if (finish < 0) {
      throw const FormatException('The PEM certificate is incomplete.');
    }
    final after = finish + end.length;
    blocks.add(input.substring(start, after));
    offset = after;
  }
  return blocks;
}
