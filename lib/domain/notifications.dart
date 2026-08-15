enum NotificationDeliveryMode { polling, push }

class NotificationPreferences {
  const NotificationPreferences({
    this.enabled = false,
    this.deliveryMode = NotificationDeliveryMode.polling,
    this.pollSeconds = 60,
    this.quietHoursEnabled = false,
    this.quietStartMinutes = 22 * 60,
    this.quietEndMinutes = 7 * 60,
    this.notifyStarted = true,
    this.notifySucceeded = true,
    this.notifyFailed = true,
  });

  final bool enabled;
  final NotificationDeliveryMode deliveryMode;
  final int pollSeconds;
  final bool quietHoursEnabled;
  final int quietStartMinutes;
  final int quietEndMinutes;
  final bool notifyStarted;
  final bool notifySucceeded;
  final bool notifyFailed;

  NotificationPreferences copyWith({
    bool? enabled,
    NotificationDeliveryMode? deliveryMode,
    int? pollSeconds,
    bool? quietHoursEnabled,
    int? quietStartMinutes,
    int? quietEndMinutes,
    bool? notifyStarted,
    bool? notifySucceeded,
    bool? notifyFailed,
  }) =>
      NotificationPreferences(
        enabled: enabled ?? this.enabled,
        deliveryMode: deliveryMode ?? this.deliveryMode,
        pollSeconds: pollSeconds ?? this.pollSeconds,
        quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
        quietStartMinutes: quietStartMinutes ?? this.quietStartMinutes,
        quietEndMinutes: quietEndMinutes ?? this.quietEndMinutes,
        notifyStarted: notifyStarted ?? this.notifyStarted,
        notifySucceeded: notifySucceeded ?? this.notifySucceeded,
        notifyFailed: notifyFailed ?? this.notifyFailed,
      );

  Map<String, Object?> toJson() => {
        'enabled': enabled,
        'deliveryMode': deliveryMode.name,
        'pollSeconds': pollSeconds,
        'quietHoursEnabled': quietHoursEnabled,
        'quietStartMinutes': quietStartMinutes,
        'quietEndMinutes': quietEndMinutes,
        'notifyStarted': notifyStarted,
        'notifySucceeded': notifySucceeded,
        'notifyFailed': notifyFailed,
      };

  factory NotificationPreferences.fromJson(Map<String, Object?> json) {
    final modeName = json['deliveryMode'] as String?;
    return NotificationPreferences(
      enabled: json['enabled'] as bool? ?? false,
      deliveryMode: NotificationDeliveryMode.values.firstWhere(
        (mode) => mode.name == modeName,
        orElse: () => NotificationDeliveryMode.polling,
      ),
      pollSeconds: json['pollSeconds'] as int? ?? 60,
      quietHoursEnabled: json['quietHoursEnabled'] as bool? ?? false,
      quietStartMinutes: json['quietStartMinutes'] as int? ?? 22 * 60,
      quietEndMinutes: json['quietEndMinutes'] as int? ?? 7 * 60,
      notifyStarted: json['notifyStarted'] as bool? ?? true,
      notifySucceeded: json['notifySucceeded'] as bool? ?? true,
      notifyFailed: json['notifyFailed'] as bool? ?? true,
    );
  }

  bool isQuietAt(DateTime time) {
    if (!quietHoursEnabled) return false;
    final minute = time.hour * 60 + time.minute;
    if (quietStartMinutes == quietEndMinutes) return true;
    if (quietStartMinutes < quietEndMinutes) {
      return minute >= quietStartMinutes && minute < quietEndMinutes;
    }
    return minute >= quietStartMinutes || minute < quietEndMinutes;
  }
}

enum NotificationEventKind { started, succeeded, failed }

class NotificationEvent {
  const NotificationEvent({
    required this.id,
    required this.instanceId,
    required this.deploymentId,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.route,
    this.read = false,
  });

  final String id;
  final String instanceId;
  final String deploymentId;
  final NotificationEventKind kind;
  final String title;
  final String body;
  final DateTime createdAt;
  final String route;
  final bool read;

  NotificationEvent copyWith({bool? read}) => NotificationEvent(
        id: id,
        instanceId: instanceId,
        deploymentId: deploymentId,
        kind: kind,
        title: title,
        body: body,
        createdAt: createdAt,
        route: route,
        read: read ?? this.read,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'instanceId': instanceId,
        'deploymentId': deploymentId,
        'kind': kind.name,
        'title': title,
        'body': body,
        'createdAt': createdAt.toIso8601String(),
        'route': route,
        'read': read,
      };

  factory NotificationEvent.fromJson(Map<String, Object?> json) =>
      NotificationEvent(
        id: json['id'] as String,
        instanceId: json['instanceId'] as String,
        deploymentId: json['deploymentId'] as String,
        kind: NotificationEventKind.values.firstWhere(
          (kind) => kind.name == json['kind'],
          orElse: () => NotificationEventKind.started,
        ),
        title: json['title'] as String,
        body: json['body'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        route: json['route'] as String,
        read: json['read'] as bool? ?? false,
      );
}
