import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:pkcs7/pkcs7.dart';
import 'package:pfx_reader/pfx_reader.dart';

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

class CertificateSummary {
  const CertificateSummary({
    required this.commonName,
    required this.sha1Thumbprint,
    required this.notBefore,
    required this.notAfter,
  });

  final String commonName;
  final String sha1Thumbprint;
  final DateTime notBefore;
  final DateTime notAfter;

  bool get isExpired => DateTime.now().toUtc().isAfter(notAfter);
  bool get isNotYetValid => DateTime.now().toUtc().isBefore(notBefore);
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

List<CertificateSummary> inspectTrustBundle(String pemBundle) => _pemBlocks(
      pemBundle,
      '-----BEGIN CERTIFICATE-----',
      '-----END CERTIFICATE-----',
    ).map(X509.fromPem).map(_summaryForX509).toList(growable: false);

Future<CertificateSummary> inspectClientPkcs12(
  Uint8List bytes,
  String password,
) async {
  if (bytes.isEmpty) throw const FormatException('The PKCS#12 file is empty.');
  final context = SecurityContext();
  final normalizedPassword = password.isEmpty ? null : password;
  context.useCertificateChainBytes(bytes, password: normalizedPassword);
  context.usePrivateKeyBytes(bytes, password: normalizedPassword);
  final info = await PfxReader.fromBytes(bytes, password);
  final thumbprint = await _certificateInspector.invokeMethod<String>(
    'pkcs12Sha1Thumbprint',
    {'bytes': bytes, 'password': password},
  );
  if (thumbprint == null || thumbprint.isEmpty) {
    throw const FormatException('Could not calculate certificate thumbprint.');
  }
  final summary = CertificateSummary(
    commonName: info.commonName?.trim().isNotEmpty == true
        ? info.commonName!.trim()
        : info.subjectDN,
    sha1Thumbprint: thumbprint,
    notBefore: info.notBefore.toUtc(),
    notAfter: info.notAfter.toUtc(),
  );
  validateCertificateValidity([summary]);
  return summary;
}

void validateCertificateValidity(
  Iterable<CertificateSummary> certificates, {
  DateTime? now,
}) {
  final current = (now ?? DateTime.now()).toUtc();
  for (final certificate in certificates) {
    if (current.isBefore(certificate.notBefore)) {
      throw FormatException(
        '${certificate.commonName} is not valid until '
        '${certificate.notBefore.toIso8601String()}.',
      );
    }
    if (current.isAfter(certificate.notAfter)) {
      throw FormatException(
        '${certificate.commonName} expired on '
        '${certificate.notAfter.toIso8601String()}.',
      );
    }
  }
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

CertificateSummary _summaryForX509(X509 certificate) {
  const commonNameOid = '2.5.4.3';
  var commonName = '';
  for (final entry in certificate.subject) {
    if (entry.key.objectIdentifierAsString == commonNameOid) {
      commonName = '${entry.value}'.trim();
      break;
    }
  }
  return CertificateSummary(
    commonName: commonName.isEmpty ? 'Unnamed certificate' : commonName,
    sha1Thumbprint: _thumbprint(certificate.der),
    notBefore: certificate.notBefore.toUtc(),
    notAfter: certificate.notAfter.toUtc(),
  );
}

String _thumbprint(List<int> bytes) => sha1
    .convert(bytes)
    .bytes
    .map((value) => value.toRadixString(16).padLeft(2, '0').toUpperCase())
    .join(':');

const _certificateInspector = MethodChannel('dploygo/certificate_inspector');
