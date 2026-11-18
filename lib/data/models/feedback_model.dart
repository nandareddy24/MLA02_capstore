/// Question 1 options: "Was the diagnosis relevant?"
enum DiagnosisRelevance {
  yes('Yes', 'yes'),
  partially('Partially', 'partially'),
  no('No', 'no');

  const DiagnosisRelevance(this.label, this.apiValue);

  final String label;
  final String apiValue;

  static DiagnosisRelevance fromApi(String? value) {
    return DiagnosisRelevance.values.firstWhere(
      (e) => e.apiValue == value || e.name == value,
      orElse: () => DiagnosisRelevance.yes,
    );
  }
}

/// Question 2 options: "Did the recommendation resolve the issue?"
enum ResolutionStatus {
  resolved('Resolved', 'resolved'),
  partiallyResolved('Partially resolved', 'partially_resolved'),
  notResolved('Not resolved', 'not_resolved'),
  notAttempted('Not attempted', 'not_attempted');

  const ResolutionStatus(this.label, this.apiValue);

  final String label;
  final String apiValue;

  static ResolutionStatus fromApi(String? value) {
    return ResolutionStatus.values.firstWhere(
      (e) => e.apiValue == value || e.name == value,
      orElse: () => ResolutionStatus.notAttempted,
    );
  }
}

/// Captures structured post-diagnosis feedback strictly scoped to the
/// authenticated user and corresponding diagnosis record.
class FeedbackModel {
  const FeedbackModel({
    required this.id,
    this.userId = '',
    this.diagnosisId,
    required this.reportId,
    this.diagnosisRelevance = DiagnosisRelevance.yes,
    this.resolutionStatus = ResolutionStatus.notAttempted,
    required this.wasHelpful,
    required this.wasIssueResolved,
    this.stillNeedsProfessionalAssistance = false,
    this.rating = 4,
    required this.comments,
    required this.submittedAt,
  });

  final String id;
  final String userId;
  final String? diagnosisId;
  final String reportId;
  final DiagnosisRelevance diagnosisRelevance;
  final ResolutionStatus resolutionStatus;
  final bool wasHelpful;
  final bool wasIssueResolved;
  final bool stillNeedsProfessionalAssistance;
  final int rating;
  final String comments;
  final DateTime submittedAt;

  Map<String, Object?> toMap() => {
        'id': id,
        'user_id': userId,
        'diagnosis_id': diagnosisId,
        'report_id': reportId,
        'diagnosis_relevance': diagnosisRelevance.apiValue,
        'resolution_status': resolutionStatus.apiValue,
        'was_helpful': wasHelpful ? 1 : 0,
        'was_issue_resolved': wasIssueResolved ? 1 : 0,
        'still_needs_professional_assistance':
            stillNeedsProfessionalAssistance ? 1 : 0,
        'rating': rating,
        'comments': comments,
        'submitted_at': submittedAt.toIso8601String(),
      };

  factory FeedbackModel.fromMap(Map<String, Object?> map) {
    final resolvedBool = (map['was_issue_resolved'] as num).toInt() == 1;
    return FeedbackModel(
      id: map['id'] as String,
      userId: (map['user_id'] as String?) ?? '',
      diagnosisId: map['diagnosis_id'] as String?,
      reportId: map['report_id'] as String,
      diagnosisRelevance: DiagnosisRelevance.fromApi(
        map['diagnosis_relevance'] as String?,
      ),
      resolutionStatus: map['resolution_status'] != null
          ? ResolutionStatus.fromApi(map['resolution_status'] as String?)
          : (resolvedBool
              ? ResolutionStatus.resolved
              : ResolutionStatus.notResolved),
      wasHelpful: ((map['was_helpful'] as num?)?.toInt() ?? 1) == 1,
      wasIssueResolved: resolvedBool,
      stillNeedsProfessionalAssistance:
          ((map['still_needs_professional_assistance'] as num?)?.toInt() ?? 0) ==
              1,
      rating: (map['rating'] as num?)?.toInt() ?? 4,
      comments: (map['comments'] as String?) ?? '',
      submittedAt: DateTime.parse(map['submitted_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        if (diagnosisId != null) 'diagnosis_id': diagnosisId,
        'report_id': reportId,
        'diagnosis_relevance': diagnosisRelevance.apiValue,
        'resolution_status': resolutionStatus.apiValue,
        'was_helpful': wasHelpful,
        'was_issue_resolved': wasIssueResolved,
        'still_needs_professional_assistance':
            stillNeedsProfessionalAssistance,
        'rating': rating,
        'comments': comments,
        'submitted_at': submittedAt.toIso8601String(),
      };
}
