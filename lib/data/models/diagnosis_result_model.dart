import 'dart:convert';

import 'decision_support_plan_model.dart';
import 'fault_report_model.dart';
import 'recommendation_model.dart';

/// Ranked alternative fault category returned by a multi-class classifier.
class AlternativeFaultModel {
  const AlternativeFaultModel({
    required this.faultCategory,
    this.probability,
  });

  final String faultCategory;
  final double? probability;

  Map<String, dynamic> toJson() => {
        'fault_category': faultCategory,
        if (probability != null) 'probability': probability,
      };

  factory AlternativeFaultModel.fromJson(Map<String, dynamic> json) {
    return AlternativeFaultModel(
      faultCategory: (json['fault_category'] ?? '').toString(),
      probability: (json['probability'] as num?)?.toDouble().clamp(0.0, 1.0),
    );
  }
}

/// Transparent evidence signal linking reported inputs to the diagnostic output.
class DiagnosticEvidenceModel {
  const DiagnosticEvidenceModel({
    required this.signalType,
    required this.source,
    required this.detail,
  });

  final String signalType;
  final String source;
  final String detail;

  Map<String, dynamic> toJson() => {
        'signal_type': signalType,
        'source': source,
        'detail': detail,
      };

  factory DiagnosticEvidenceModel.fromJson(Map<String, dynamic> json) {
    return DiagnosticEvidenceModel(
      signalType: (json['signal_type'] ?? 'symptom').toString(),
      source: (json['source'] ?? 'Reported Signal').toString(),
      detail: (json['detail'] ?? '').toString(),
    );
  }
}

/// Contract model for AI-generated fault diagnosis outputs returned from the
/// Python scikit-learn diagnosis service.
///
/// Never populated with hardcoded or fabricated local predictions.
class DiagnosisResultModel {
  const DiagnosisResultModel({
    required this.id,
    required this.reportId,
    required this.primaryFault,
    this.deviceName,
    this.confidence,
    this.confidenceIsCalibrated = false,
    this.severity = FaultSeverity.medium,
    this.severityRationale =
        'Determined by FixWise decision-support safety and operational risk rules.',
    required this.summary,
    required this.modelVersion,
    this.algorithm,
    this.processingTimeMs,
    required this.analyzedAt,
    this.rankedAlternatives = const [],
    this.evidence = const [],
    this.contributingFactors = const [],
    this.isUncertain = false,
    this.uncertaintyMessage,
    this.disclaimer = defaultDisclaimer,
    this.recommendations = const [],
    this.decisionSupportPlan,
  });

  static const String defaultDisclaimer =
      'A predicted fault category is decision support based on reported symptoms '
      'and is not a confirmed physical fault. Verify safely or consult a qualified technician.';

  final String id;
  final String reportId;
  final String primaryFault;
  final String? deviceName;

  /// Only non-null and displayed when calibrated and supported by the model artifact.
  final double? confidence;
  final bool confidenceIsCalibrated;

  /// Determined exclusively by decision-support rules, not by ML confidence.
  final FaultSeverity severity;
  final String severityRationale;

  final String summary;
  final String modelVersion;
  final String? algorithm;
  final double? processingTimeMs;
  final DateTime analyzedAt;
  final List<AlternativeFaultModel> rankedAlternatives;
  final List<DiagnosticEvidenceModel> evidence;
  final List<String> contributingFactors;
  final bool isUncertain;
  final String? uncertaintyMessage;
  final String disclaimer;
  final List<RecommendationModel> recommendations;
  final DecisionSupportPlanModel? decisionSupportPlan;

  bool get hasCalibratedConfidence =>
      confidenceIsCalibrated && confidence != null;

  Map<String, Object?> toMap() => {
        'id': id,
        'report_id': reportId,
        'device_name': deviceName,
        'primary_fault': primaryFault,
        'confidence': confidence,
        'confidence_is_calibrated': confidenceIsCalibrated ? 1 : 0,
        'severity': severity.name,
        'severity_rationale': severityRationale,
        'summary': summary,
        'model_version': modelVersion,
        'algorithm': algorithm,
        'processing_time_ms': processingTimeMs,
        'ranked_alternatives_json': jsonEncode(
          rankedAlternatives.map((a) => a.toJson()).toList(),
        ),
        'evidence_json': jsonEncode(evidence.map((e) => e.toJson()).toList()),
        'contributing_factors_json': jsonEncode(contributingFactors),
        'is_uncertain': isUncertain ? 1 : 0,
        'uncertainty_message': uncertaintyMessage,
        'disclaimer': disclaimer,
        'recommendations_json': jsonEncode(
          recommendations.map((r) => r.toJson()).toList(),
        ),
        'decision_support_plan_json': decisionSupportPlan != null
            ? jsonEncode(decisionSupportPlan!.toJson())
            : null,
        'analyzed_at': analyzedAt.toIso8601String(),
      };

  factory DiagnosisResultModel.fromMap(Map<String, Object?> map) {
    final factorsDecoded = jsonDecode(
      (map['contributing_factors_json'] as String?) ?? '[]',
    );
    final recsDecoded = jsonDecode(
      (map['recommendations_json'] as String?) ?? '[]',
    );
    final altsDecoded = jsonDecode(
      (map['ranked_alternatives_json'] as String?) ?? '[]',
    );
    final evidenceDecoded = jsonDecode(
      (map['evidence_json'] as String?) ?? '[]',
    );
    final rawPlan = map['decision_support_plan_json'] as String?;
    final decodedPlan =
        (rawPlan != null && rawPlan.isNotEmpty) ? jsonDecode(rawPlan) : null;

    return DiagnosisResultModel(
      id: map['id'] as String,
      reportId: map['report_id'] as String,
      deviceName: map['device_name'] as String?,
      primaryFault: map['primary_fault'] as String,
      confidence: (map['confidence'] as num?)?.toDouble(),
      confidenceIsCalibrated:
          ((map['confidence_is_calibrated'] as num?)?.toInt() ?? 0) == 1,
      severity: FaultSeverity.fromName((map['severity'] as String?) ?? 'medium'),
      severityRationale: (map['severity_rationale'] as String?) ??
          'Determined by FixWise decision-support rules.',
      summary: map['summary'] as String,
      modelVersion: map['model_version'] as String,
      algorithm: map['algorithm'] as String?,
      processingTimeMs: (map['processing_time_ms'] as num?)?.toDouble(),
      analyzedAt: DateTime.parse(map['analyzed_at'] as String),
      rankedAlternatives: altsDecoded is List
          ? altsDecoded
              .whereType<Map<String, dynamic>>()
              .map(AlternativeFaultModel.fromJson)
              .toList()
          : const [],
      evidence: evidenceDecoded is List
          ? evidenceDecoded
              .whereType<Map<String, dynamic>>()
              .map(DiagnosticEvidenceModel.fromJson)
              .toList()
          : const [],
      contributingFactors: factorsDecoded is List
          ? factorsDecoded.map((e) => e.toString()).toList()
          : const [],
      isUncertain: ((map['is_uncertain'] as num?)?.toInt() ?? 0) == 1,
      uncertaintyMessage: map['uncertainty_message'] as String?,
      disclaimer: (map['disclaimer'] as String?) ?? defaultDisclaimer,
      recommendations: recsDecoded is List
          ? recsDecoded
              .whereType<Map<String, dynamic>>()
              .map(RecommendationModel.fromJson)
              .toList()
          : const [],
      decisionSupportPlan: decodedPlan is Map<String, dynamic>
          ? DecisionSupportPlanModel.fromJson(decodedPlan)
          : null,
    );
  }

  factory DiagnosisResultModel.fromJson(
    Map<String, dynamic> json, {
    required String fallbackReportId,
    String? fallbackDeviceName,
  }) {
    final factorsRaw = json['contributing_factors'];
    final recsRaw = json['recommendations'];
    final altsRaw = json['ranked_alternatives'];
    final evidenceRaw = json['evidence'];
    final uncertaintyRaw = json['uncertainty'];
    final deviceRaw = json['device'];
    final planRaw = json['decision_support_plan'];

    final calibrated = json['confidence_is_calibrated'] == true;
    final rawConfidence = (json['confidence'] as num?)?.toDouble();

    return DiagnosisResultModel(
      id: (json['diagnosis_id'] ?? json['id'] ?? 'diag_$fallbackReportId')
          .toString(),
      reportId: (json['report_id'] ?? fallbackReportId).toString(),
      deviceName: deviceRaw is Map<String, dynamic>
          ? (deviceRaw['name']?.toString() ?? fallbackDeviceName)
          : fallbackDeviceName,
      primaryFault: (json['predicted_fault_category'] ??
              json['primary_fault'] ??
              '')
          .toString(),
      confidence:
          calibrated && rawConfidence != null ? rawConfidence.clamp(0.0, 1.0) : null,
      confidenceIsCalibrated: calibrated,
      severity: FaultSeverity.fromName((json['severity'] ?? 'medium').toString()),
      severityRationale: (json['severity_rationale'] ??
              'Determined by FixWise decision-support safety and operational risk rules.')
          .toString(),
      summary: (json['summary'] ?? '').toString(),
      modelVersion: (json['model_version'] ?? 'unknown').toString(),
      algorithm: json['algorithm']?.toString(),
      processingTimeMs: (json['processing_time_ms'] as num?)?.toDouble(),
      analyzedAt: json['analyzed_at'] != null
          ? DateTime.parse(json['analyzed_at'].toString())
          : DateTime.now(),
      rankedAlternatives: altsRaw is List
          ? altsRaw
              .whereType<Map<String, dynamic>>()
              .map(AlternativeFaultModel.fromJson)
              .toList()
          : const [],
      evidence: evidenceRaw is List
          ? evidenceRaw
              .whereType<Map<String, dynamic>>()
              .map(DiagnosticEvidenceModel.fromJson)
              .toList()
          : const [],
      contributingFactors: factorsRaw is List
          ? factorsRaw.map((e) => e.toString()).toList()
          : const [],
      isUncertain: uncertaintyRaw is Map<String, dynamic>
          ? uncertaintyRaw['is_uncertain'] == true
          : !calibrated,
      uncertaintyMessage: uncertaintyRaw is Map<String, dynamic>
          ? uncertaintyRaw['message']?.toString()
          : null,
      disclaimer: uncertaintyRaw is Map<String, dynamic> &&
              uncertaintyRaw['disclaimer'] is String
          ? uncertaintyRaw['disclaimer'] as String
          : defaultDisclaimer,
      recommendations: recsRaw is List
          ? recsRaw
              .whereType<Map<String, dynamic>>()
              .map(RecommendationModel.fromJson)
              .toList()
          : const [],
      decisionSupportPlan: planRaw is Map<String, dynamic>
          ? DecisionSupportPlanModel.fromJson(planRaw)
          : null,
    );
  }
}
