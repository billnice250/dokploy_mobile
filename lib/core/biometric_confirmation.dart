import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import 'app_notice.dart';

enum BiometricConfirmationResult { confirmed, denied, unavailable, failed }

abstract interface class SensitiveOperationAuthorizer {
  Future<BiometricConfirmationResult> confirm({required String reason});
}

class DeviceBiometricAuthorizer implements SensitiveOperationAuthorizer {
  DeviceBiometricAuthorizer([LocalAuthentication? authentication])
      : _authentication = authentication ?? LocalAuthentication();

  final LocalAuthentication _authentication;

  @override
  Future<BiometricConfirmationResult> confirm({required String reason}) async {
    try {
      final supported = await _authentication.isDeviceSupported();
      final canCheck = await _authentication.canCheckBiometrics;
      if (!supported || !canCheck) {
        return BiometricConfirmationResult.unavailable;
      }
      final confirmed = await _authentication.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
      return confirmed
          ? BiometricConfirmationResult.confirmed
          : BiometricConfirmationResult.denied;
    } on PlatformException {
      return BiometricConfirmationResult.failed;
    }
  }
}

final sensitiveOperationAuthorizerProvider =
    Provider<SensitiveOperationAuthorizer>(
  (ref) => DeviceBiometricAuthorizer(),
);

Future<bool> confirmSensitiveOperation(
  BuildContext context,
  WidgetRef ref, {
  required String reason,
}) async {
  final result = await ref
      .read(sensitiveOperationAuthorizerProvider)
      .confirm(reason: reason);
  if (result == BiometricConfirmationResult.confirmed) return true;
  if (!context.mounted) return false;
  final message = switch (result) {
    BiometricConfirmationResult.denied =>
      'Biometric confirmation was cancelled or not recognized.',
    BiometricConfirmationResult.unavailable =>
      'Set up Face ID, Touch ID, or fingerprint authentication before using this operation.',
    BiometricConfirmationResult.failed =>
      'Biometric confirmation could not be completed. Try again.',
    BiometricConfirmationResult.confirmed => '',
  };
  DployGoNotice.show(
    context,
    title: 'Confirmation required',
    message: message,
    tone: DployGoNoticeTone.warning,
  );
  return false;
}
