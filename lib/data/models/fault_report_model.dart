import 'dart:convert';

enum FaultSeverity {
  low('Low'),
  medium('Medium'),
  high('High'),
  critical('Critical');

  const FaultSeverity(this.label);

  final String label;

  static FaultSeverity fromName(String value) {
    return FaultSeverity.values.firstWhere(
      (s) => s.name == value,
      orElse: () => FaultSeverity.medium,
    );
  }
}

enum FaultReportStatus {
  pendingDiagnosis('Pending Diagnosis'),
  diagnosed('Diagnosed'),
  resolved('Resolved');

  const FaultReportStatus(this.label);

  final String label;

  static FaultReportStatus fromName(String value) {
    return FaultReportStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => FaultReportStatus.pendingDiagnosis,
    );
  }
}

/// Structured fault report captured by the user and persisted locally in SQLite.
class FaultReportModel {
  const FaultReportModel({
    required this.id,
    this.userId = '',
    required this.deviceId,
    required this.deviceName,
    this.deviceCategory,
    this.manufacturer,
    this.modelName,
    this.deviceAge,
    this.operatingEnvironment,
    required this.title,
    required this.description,
    required this.symptoms,
    required this.severity,
    required this.status,
    this.errorCode,
    this.startedWhen,
    this.operatingConditions,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String deviceId;
  final String deviceName;
  final String? deviceCategory;
  final String? manufacturer;
  final String? modelName;
  final String? deviceAge;
  final String? operatingEnvironment;
  final String title;
  final String description;
  final List<String> symptoms;
  final FaultSeverity severity;
  final FaultReportStatus status;
  final String? errorCode;
  final String? startedWhen;
  final String? operatingConditions;
  final DateTime createdAt;

  FaultReportModel copyWith({
    String? id,
    String? userId,
    String? deviceId,
    String? deviceName,
    String? deviceCategory,
    String? manufacturer,
    String? modelName,
    String? deviceAge,
    String? operatingEnvironment,
    String? title,
    String? description,
    List<String>? symptoms,
    FaultSeverity? severity,
    FaultReportStatus? status,
    String? errorCode,
    String? startedWhen,
    String? operatingConditions,
    DateTime? createdAt,
  }) {
    return FaultReportModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      deviceCategory: deviceCategory ?? this.deviceCategory,
      manufacturer: manufacturer ?? this.manufacturer,
      modelName: modelName ?? this.modelName,
      deviceAge: deviceAge ?? this.deviceAge,
      operatingEnvironment: operatingEnvironment ?? this.operatingEnvironment,
      title: title ?? this.title,
      description: description ?? this.description,
      symptoms: symptoms ?? this.symptoms,
      severity: severity ?? this.severity,
      status: status ?? this.status,
      errorCode: errorCode ?? this.errorCode,
      startedWhen: startedWhen ?? this.startedWhen,
      operatingConditions: operatingConditions ?? this.operatingConditions,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'user_id': userId,
        'device_id': deviceId,
        'device_name': deviceName,
        'device_category': deviceCategory,
        'manufacturer': manufacturer,
        'model_name': modelName,
        'device_age': deviceAge,
        'operating_environment': operatingEnvironment,
        'title': title,
        'description': description,
        'symptoms_json': jsonEncode(symptoms),
        'severity': severity.name,
        'status': status.name,
        'error_code': errorCode,
        'started_when': startedWhen,
        'operating_conditions': operatingConditions,
        'created_at': createdAt.toIso8601String(),
      };

  factory FaultReportModel.fromMap(Map<String, Object?> map) {
    final rawSymptoms = map['symptoms_json'] as String? ?? '[]';
    final decoded = jsonDecode(rawSymptoms);
    final symptomsList = decoded is List
        ? decoded.map((item) => item.toString()).toList()
        : <String>[];

    return FaultReportModel(
      id: map['id'] as String,
      userId: (map['user_id'] as String?) ?? '',
      deviceId: map['device_id'] as String,
      deviceName: map['device_name'] as String,
      deviceCategory: map['device_category'] as String?,
      manufacturer: map['manufacturer'] as String?,
      modelName: map['model_name'] as String?,
      deviceAge: map['device_age'] as String?,
      operatingEnvironment: map['operating_environment'] as String?,
      title: map['title'] as String,
      description: map['description'] as String,
      symptoms: symptomsList,
      severity: FaultSeverity.fromName(map['severity'] as String),
      status: FaultReportStatus.fromName(map['status'] as String),
      errorCode: map['error_code'] as String?,
      startedWhen: map['started_when'] as String?,
      operatingConditions: map['operating_conditions'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  /// Structured payload contract sent to the ML diagnosis backend.
  Map<String, dynamic> toInferencePayload() => {
        'report_id': id,
        'device': {
          'id': deviceId,
          'name': deviceName,
          if (deviceCategory != null && deviceCategory!.isNotEmpty)
            'category': deviceCategory,
          if (manufacturer != null && manufacturer!.isNotEmpty)
            'manufacturer': manufacturer,
          if (modelName != null && modelName!.isNotEmpty)
            'model_name': modelName,
          if (deviceAge != null && deviceAge!.isNotEmpty) 'age': deviceAge,
          if (operatingEnvironment != null && operatingEnvironment!.isNotEmpty)
            'operating_environment': operatingEnvironment,
        },
        'title': title,
        'symptoms': symptoms,
        'severity': severity.name,
        'description': description,
        if (errorCode != null && errorCode!.isNotEmpty) 'error_code': errorCode,
        if (startedWhen != null && startedWhen!.isNotEmpty)
          'started_when': startedWhen,
        if (operatingConditions != null && operatingConditions!.isNotEmpty)
          'operating_conditions': operatingConditions,
        'reported_at': createdAt.toIso8601String(),
      };
}
