import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../../data/models/diagnosis_result_model.dart';
import '../../../../data/models/fault_report_model.dart';
import '../../../../data/models/feedback_model.dart';
import '../../../../data/repositories/providers.dart';
import '../../../dashboard/presentation/controllers/dashboard_controller.dart';
import '../../../history/presentation/controllers/history_controller.dart';

/// Combined preserved snapshot for a single fault report, its original
/// diagnosis result (never recalculated on view), and user feedback.
class DiagnosisViewData {
  const DiagnosisViewData({
    required this.report,
    required this.diagnosis,
    required this.feedback,
    required this.isMlServiceConfigured,
  });

  final FaultReportModel? report;
  final DiagnosisResultModel? diagnosis;
  final FeedbackModel? feedback;
  final bool isMlServiceConfigured;
}

final diagnosisDetailProvider =
    FutureProvider.family<DiagnosisViewData, String>((ref, reportId) async {
  final reportRepo = ref.watch(faultReportRepositoryProvider);
  final diagnosisRepo = ref.watch(diagnosisRepositoryProvider);
  final feedbackRepo = ref.watch(feedbackRepositoryProvider);
  final apiClient = ref.watch(apiClientProvider);

  final reportResult = await reportRepo.getReportById(reportId);
  final report = reportResult.when(
    success: (data) => data,
    failure: (err) => throw err,
  );

  if (report == null) {
    return DiagnosisViewData(
      report: null,
      diagnosis: null,
      feedback: null,
      isMlServiceConfigured: apiClient.isConfigured,
    );
  }

  final diagnosisResult = await diagnosisRepo.getCachedDiagnosis(reportId);
  final diagnosis = diagnosisResult.when(
    success: (data) => data,
    failure: (err) => throw err,
  );

  final feedbackResult = await feedbackRepo.getFeedbackForReport(reportId);
  final feedback = feedbackResult.when<FeedbackModel?>(
    success: (items) => items.isNotEmpty ? items.first : null,
    failure: (_) => null,
  );

  return DiagnosisViewData(
    report: report,
    diagnosis: diagnosis,
    feedback: feedback,
    isMlServiceConfigured: apiClient.isConfigured,
  );
});

class DiagnosisActionState {
  const DiagnosisActionState({
    this.isAnalyzing = false,
    this.failure,
  });

  final bool isAnalyzing;
  final Failure? failure;
}

class DiagnosisActionController extends Notifier<DiagnosisActionState> {
  @override
  DiagnosisActionState build() => const DiagnosisActionState();

  Future<bool> runDiagnosis(FaultReportModel report) async {
    // Hard lock prevents duplicate requests from rapid multi-taps.
    if (state.isAnalyzing) return false;
    state = const DiagnosisActionState(isAnalyzing: true);
    final result =
        await ref.read(diagnosisRepositoryProvider).runDiagnosis(report);

    return result.when(
      success: (_) {
        state = const DiagnosisActionState();
        ref.invalidate(diagnosisDetailProvider(report.id));
        ref.invalidate(dashboardControllerProvider);
        ref.invalidate(historyControllerProvider);
        return true;
      },
      failure: (err) {
        state = DiagnosisActionState(failure: err);
        return false;
      },
    );
  }

  void clearError() {
    if (state.failure != null) {
      state = const DiagnosisActionState();
    }
  }
}

final diagnosisActionProvider =
    NotifierProvider<DiagnosisActionController, DiagnosisActionState>(
  DiagnosisActionController.new,
);
