import 'recommendation_model.dart';

/// Decision-support severity tiers defined by FixWise safety rules.
enum DecisionSeverityLevel {
  safe('Safe'),
  medium('Medium'),
  high('High');

  const DecisionSeverityLevel(this.label);

  final String label;

  static DecisionSeverityLevel fromName(String value) {
    return switch (value.toLowerCase()) {
      'safe' || 'low' => DecisionSeverityLevel.safe,
      'high' || 'critical' => DecisionSeverityLevel.high,
      _ => DecisionSeverityLevel.medium,
    };
  }
}

/// Structured technician / emergency escalation guidance.
class EscalationGuidanceModel {
  const EscalationGuidanceModel({
    required this.requiresTechnician,
    required this.stopUsingDevice,
    required this.whenToEscalate,
    this.emergencyGuidance,
  });

  final bool requiresTechnician;
  final bool stopUsingDevice;
  final String whenToEscalate;
  final String? emergencyGuidance;

  Map<String, dynamic> toJson() => {
        'requires_technician': requiresTechnician,
        'stop_using_device': stopUsingDevice,
        'when_to_escalate': whenToEscalate,
        if (emergencyGuidance != null) 'emergency_guidance': emergencyGuidance,
      };

  factory EscalationGuidanceModel.fromJson(Map<String, dynamic> json) {
    return EscalationGuidanceModel(
      requiresTechnician: json['requires_technician'] == true,
      stopUsingDevice: json['stop_using_device'] == true,
      whenToEscalate: (json['when_to_escalate'] ?? '').toString(),
      emergencyGuidance: json['emergency_guidance']?.toString(),
    );
  }
}

/// Complete severity-aware recommendation plan produced by the FixWise
/// Decision Support Engine from expert-reviewed knowledge-base records.
class DecisionSupportPlanModel {
  const DecisionSupportPlanModel({
    required this.diagnosisId,
    required this.reportId,
    required this.predictedFault,
    required this.deviceCategory,
    required this.deviceName,
    required this.severity,
    required this.severityRationale,
    required this.isDangerousFault,
    this.immediateSafetyBanner,
    required this.likelyCause,
    this.firstRecommendedCheck,
    required this.recommendations,
    required this.safetyWarnings,
    required this.escalation,
    required this.expertReviewStatus,
    this.knowledgeBaseRecordId,
  });

  final String diagnosisId;
  final String reportId;
  final String predictedFault;
  final String deviceCategory;
  final String deviceName;
  final DecisionSeverityLevel severity;
  final String severityRationale;
  final bool isDangerousFault;
  final String? immediateSafetyBanner;
  final String likelyCause;
  final RecommendationModel? firstRecommendedCheck;
  final List<RecommendationModel> recommendations;
  final List<String> safetyWarnings;
  final EscalationGuidanceModel escalation;
  final String expertReviewStatus;
  final String? knowledgeBaseRecordId;

  Map<String, dynamic> toJson() => {
        'diagnosis_id': diagnosisId,
        'report_id': reportId,
        'predicted_fault': predictedFault,
        'device_category': deviceCategory,
        'device_name': deviceName,
        'severity': severity.name,
        'severity_rationale': severityRationale,
        'is_dangerous_fault': isDangerousFault,
        if (immediateSafetyBanner != null)
          'immediate_safety_banner': immediateSafetyBanner,
        'likely_cause': likelyCause,
        if (firstRecommendedCheck != null)
          'first_recommended_check': firstRecommendedCheck!.toJson(),
        'recommendations': recommendations.map((r) => r.toJson()).toList(),
        'safety_warnings': safetyWarnings,
        'escalation': escalation.toJson(),
        'expert_review_status': expertReviewStatus,
        if (knowledgeBaseRecordId != null)
          'knowledge_base_record_id': knowledgeBaseRecordId,
      };

  factory DecisionSupportPlanModel.fromJson(Map<String, dynamic> json) {
    final firstCheckRaw = json['first_recommended_check'];
    final recsRaw = json['recommendations'];
    final warningsRaw = json['safety_warnings'];
    final escalationRaw = json['escalation'];

    return DecisionSupportPlanModel(
      diagnosisId: (json['diagnosis_id'] ?? '').toString(),
      reportId: (json['report_id'] ?? '').toString(),
      predictedFault: (json['predicted_fault'] ?? '').toString(),
      deviceCategory: (json['device_category'] ?? '').toString(),
      deviceName: (json['device_name'] ?? '').toString(),
      severity:
          DecisionSeverityLevel.fromName((json['severity'] ?? 'medium').toString()),
      severityRationale: (json['severity_rationale'] ?? '').toString(),
      isDangerousFault: json['is_dangerous_fault'] == true,
      immediateSafetyBanner: json['immediate_safety_banner']?.toString(),
      likelyCause: (json['likely_cause'] ?? '').toString(),
      firstRecommendedCheck: firstCheckRaw is Map<String, dynamic>
          ? RecommendationModel.fromJson(firstCheckRaw)
          : null,
      recommendations: recsRaw is List
          ? recsRaw
              .whereType<Map<String, dynamic>>()
              .map(RecommendationModel.fromJson)
              .toList()
          : const [],
      safetyWarnings: warningsRaw is List
          ? warningsRaw.map((e) => e.toString()).toList()
          : const [],
      escalation: escalationRaw is Map<String, dynamic>
          ? EscalationGuidanceModel.fromJson(escalationRaw)
          : const EscalationGuidanceModel(
              requiresTechnician: true,
              stopUsingDevice: false,
              whenToEscalate:
                  'Contact a qualified technician if the issue persists.',
            ),
      expertReviewStatus:
          (json['expert_review_status'] ?? 'reviewed').toString(),
      knowledgeBaseRecordId: json['knowledge_base_record_id']?.toString(),
    );
  }
}
