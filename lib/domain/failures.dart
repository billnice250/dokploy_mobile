enum DokployFailureKind {
  unauthorized,
  forbidden,
  notFound,
  unsupportedFeature,
  connectionFailed,
  tlsFailure,
  timeout,
  conflict,
  validation,
  server,
  unknown,
}

class DokployFailure implements Exception {
  const DokployFailure({
    required this.kind,
    required this.operation,
    required this.message,
    this.statusCode,
  });

  final DokployFailureKind kind;
  final String operation;
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
