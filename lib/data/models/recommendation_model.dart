/// Risk classification for an individual recommendation step.
enum RecommendationRiskLevel {
  safe('Safe'),
  caution('Caution'),
  high('High Risk');

  const RecommendationRiskLevel(this.label);

  final String label;

  static RecommendationRiskLevel fromName(String value) {
    return switch (value.toLowerCase()) {
      'safe' || 'low' => RecommendationRiskLevel.safe,
      'high' || 'critical' => RecommendationRiskLevel.high,
      _ => RecommendationRiskLevel.caution,
    };
  }
}

/// Actionable maintenance or decision-support recommendation returned by the
/// reviewed FixWise knowledge base & decision-support engine.
class RecommendationModel {
  const RecommendationModel({
    required this.id,
    this.stepNumber = 1,
    required this.title,
    required this.description,
    required this.priority,
    this.riskLevel = RecommendationRiskLevel.caution,
    this.isCheckable = false,
    this.safetyNote,
    this.estimatedMinutes,
    this.requiredTools = const [],
    this.rankScore,
  });

  final String id;
  final int stepNumber;
  final String title;
  final String description;
  final String priority;
  final RecommendationRiskLevel riskLevel;

  /// True ONLY for low-risk safe checks that a user can reasonably perform and
  /// check off manually. Never auto-completed.
  final bool isCheckable;
  final String? safetyNote;
  final int? estimatedMinutes;
  final List<String> requiredTools;
  final double? rankScore;

  Map<String, dynamic> toJson() => {
        'id': id,
        'step_number': stepNumber,
        'title': title,
        'instructions': description,
        'description': description,
        'priority': priority,
        'risk_level': riskLevel.name,
        'is_checkable': isCheckable,
        'safety_note': safetyNote,
        'estimated_minutes': estimatedMinutes,
        'required_tools': requiredTools,
        if (rankScore != null) 'rank_score': rankScore,
      };

  factory RecommendationModel.fromJson(Map<String, dynamic> json) {
    final toolsRaw = json['required_tools'];
    final risk = RecommendationRiskLevel.fromName(
      (json['risk_level'] ?? json['priority'] ?? 'caution').toString(),
    );
    return RecommendationModel(
      id: (json['id'] ?? '').toString(),
      stepNumber: (json['step_number'] as num?)?.toInt() ?? 1,
      title: (json['title'] ?? '').toString(),
      description:
          (json['instructions'] ?? json['description'] ?? '').toString(),
      priority: (json['priority'] ?? 'medium').toString(),
      riskLevel: risk,
      isCheckable:
          json['is_checkable'] == true && risk == RecommendationRiskLevel.safe,
      safetyNote: json['safety_note']?.toString(),
      estimatedMinutes: (json['estimated_minutes'] as num?)?.toInt(),
      requiredTools: toolsRaw is List
          ? toolsRaw.map((item) => item.toString()).toList()
          : const [],
      rankScore: (json['rank_score'] as num?)?.toDouble(),
    );
  }
}
