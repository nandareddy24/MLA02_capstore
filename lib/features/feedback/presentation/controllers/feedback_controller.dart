import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/feedback_model.dart';
import '../../../../data/repositories/providers.dart';
import '../../../dashboard/presentation/controllers/dashboard_controller.dart';
import '../../../diagnosis/presentation/controllers/diagnosis_controller.dart';
import '../../../history/presentation/controllers/history_controller.dart';

final reportFeedbackListProvider =
    FutureProvider.family<List<FeedbackModel>, String>((ref, reportId) async {
  final result = await ref
      .watch(feedbackRepositoryProvider)
      .getFeedbackForReport(reportId);

  return result.when(
    success: (items) => items,
    failure: (err) => throw err,
  );
});

class FeedbackSubmissionState {
  const FeedbackSubmissionState({
    this.isSubmitting = false,
    this.errorMessage,
    this.submittedSuccess = false,
  });

  final bool isSubmitting;
  final String? errorMessage;
  final bool submittedSuccess;
}

class FeedbackController extends Notifier<FeedbackSubmissionState> {
  @override
  FeedbackSubmissionState build() => const FeedbackSubmissionState();

  Future<bool> submit({
    String? diagnosisId,
    required String reportId,
    DiagnosisRelevance diagnosisRelevance = DiagnosisRelevance.yes,
    ResolutionStatus resolutionStatus = ResolutionStatus.notAttempted,
    bool? wasHelpful,
    bool? wasIssueResolved,
    bool stillNeedsProfessionalAssistance = false,
    int rating = 4,
    String comments = '',
  }) async {
    if (state.isSubmitting) return false;
    state = const FeedbackSubmissionState(isSubmitting: true);

    final activeUserId =
        ref.read(preferencesServiceProvider).activeUserId ?? '';
    final resolvedFlag =
        wasIssueResolved ?? (resolutionStatus == ResolutionStatus.resolved);
    final helpfulFlag =
        wasHelpful ?? (diagnosisRelevance != DiagnosisRelevance.no);

    final feedback = FeedbackModel(
      id: 'fb_${DateTime.now().microsecondsSinceEpoch}',
      userId: activeUserId,
      diagnosisId: diagnosisId,
      reportId: reportId,
      diagnosisRelevance: diagnosisRelevance,
      resolutionStatus: resolutionStatus,
      wasHelpful: helpfulFlag,
      wasIssueResolved: resolvedFlag,
      stillNeedsProfessionalAssistance: stillNeedsProfessionalAssistance,
      rating: rating,
      comments: comments.trim(),
      submittedAt: DateTime.now(),
    );

    final result =
        await ref.read(feedbackRepositoryProvider).submitFeedback(feedback);

    return result.when(
      success: (_) {
        state = const FeedbackSubmissionState(submittedSuccess: true);
        ref.invalidate(reportFeedbackListProvider(reportId));
        ref.invalidate(diagnosisDetailProvider(reportId));
        ref.invalidate(dashboardControllerProvider);
        ref.invalidate(historyControllerProvider);
        return true;
      },
      failure: (err) {
        state = FeedbackSubmissionState(errorMessage: err.message);
        return false;
      },
    );
  }
}

final feedbackControllerProvider =
    NotifierProvider<FeedbackController, FeedbackSubmissionState>(
  FeedbackController.new,
);
