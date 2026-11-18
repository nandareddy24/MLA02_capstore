import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/decision_support_plan_model.dart';
import '../../../../data/repositories/providers.dart';

/// Loads the reviewed [DecisionSupportPlanModel] for a diagnosed fault report.
///
/// Prefers the plan cached alongside the verified diagnosis result; if a diagnosis
/// exists without a cached plan and the backend is configured, queries the
/// separate Decision Support Service (`POST /api/v1/decision-support/recommend`).
final decisionSupportPlanProvider =
    FutureProvider.family<DecisionSupportPlanModel?, String>(
  (ref, reportId) async {
    final diagnosisResult = await ref
        .watch(diagnosisRepositoryProvider)
        .getCachedDiagnosis(reportId);

    final diagnosis = diagnosisResult.when(
      success: (d) => d,
      failure: (err) => throw err,
    );

    if (diagnosis == null) {
      return null;
    }

    if (diagnosis.decisionSupportPlan != null) {
      return diagnosis.decisionSupportPlan;
    }

    final reportResult =
        await ref.watch(faultReportRepositoryProvider).getReportById(reportId);
    final report = reportResult.when(
      success: (r) => r,
      failure: (err) => throw err,
    );

    final apiService = ref.watch(decisionSupportApiServiceProvider);
    if (report != null && apiService.isConfigured) {
      final livePlanResult = await apiService.fetchRecommendations(
        diagnosis: diagnosis,
        report: report,
      );
      final livePlan = livePlanResult.when<DecisionSupportPlanModel?>(
        success: (plan) => plan,
        failure: (_) => null,
      );
      if (livePlan != null) {
        return livePlan;
      }
    }

    if (diagnosis.recommendations.isEmpty) {
      return null;
    }

    // Reconstruct a minimal plan solely from cached backend recommendation records.
    return DecisionSupportPlanModel(
      diagnosisId: diagnosis.id,
      reportId: diagnosis.reportId,
      predictedFault: diagnosis.primaryFault,
      deviceCategory: report?.deviceCategory ?? 'device',
      deviceName: diagnosis.deviceName ?? report?.deviceName ?? 'Device',
      severity: DecisionSeverityLevel.fromName(diagnosis.severity.name),
      severityRationale: diagnosis.severityRationale,
      isDangerousFault:
          DecisionSeverityLevel.fromName(diagnosis.severity.name) ==
              DecisionSeverityLevel.high,
      likelyCause: diagnosis.summary,
      firstRecommendedCheck: diagnosis.recommendations.first,
      recommendations: diagnosis.recommendations,
      safetyWarnings: const [
        'Follow manufacturer safety guidelines and disconnect power before performing any physical inspection.',
      ],
      escalation: const EscalationGuidanceModel(
        requiresTechnician: true,
        stopUsingDevice: false,
        whenToEscalate:
            'Contact a qualified technician if the fault persists after completing safe initial checks.',
      ),
      expertReviewStatus: 'reviewed',
    );
  },
);
