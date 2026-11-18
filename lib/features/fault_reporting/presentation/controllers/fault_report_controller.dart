import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/failure.dart';
import '../../../../data/models/diagnostic_catalog_model.dart';
import '../../../../data/models/fault_report_model.dart';
import '../../../../data/repositories/providers.dart';
import '../../../dashboard/presentation/controllers/dashboard_controller.dart';
import '../../../history/presentation/controllers/history_controller.dart';

/// Standard options for optional device age selection.
const List<String> kDeviceAgeOptions = [
  'Less than 1 year',
  '1–2 years',
  '2–4 years',
  '4–6 years',
  'Over 6 years',
  'Unknown',
];

/// Standard options for optional operating environment selection.
const List<String> kOperatingEnvironmentOptions = [
  'Indoor – Normal',
  'Humid / Damp',
  'High Temperature',
  'Dusty / Workshop',
  'Outdoor / Exposed',
];

/// Standard options for problem onset timeframe.
const List<String> kProblemOnsetOptions = [
  'Just started today',
  'Within the last 2–3 days',
  'Within the last week',
  '2–4 weeks ago',
  'Over a month ago',
  'Intermittent / Recurring',
];

/// Immutable multi-step workflow state preserved when navigating across all 4 steps.
class FaultReportingWorkflowState {
  const FaultReportingWorkflowState({
    this.currentStep = 0,
    this.selectedCategory,
    this.manufacturer = '',
    this.modelName = '',
    this.deviceAge,
    this.operatingEnvironment,
    this.selectedSymptomIds = const {},
    this.errorCode = '',
    this.problemDescription = '',
    this.startedWhen,
    this.operatingConditions = '',
    this.validationError,
    this.isSubmitting = false,
    this.submissionFailure,
    this.savedReport,
  });

  final int currentStep;
  final SupportedDeviceCategory? selectedCategory;
  final String manufacturer;
  final String modelName;
  final String? deviceAge;
  final String? operatingEnvironment;
  final Set<String> selectedSymptomIds;
  final String errorCode;
  final String problemDescription;
  final String? startedWhen;
  final String operatingConditions;
  final String? validationError;
  final bool isSubmitting;
  final Failure? submissionFailure;
  final FaultReportModel? savedReport;

  /// Resolves selected symptom IDs into structured [SymptomItem] objects for the
  /// active category so only valid dataset symptoms are submitted.
  List<SymptomItem> get resolvedSelectedSymptoms {
    final category = selectedCategory;
    if (category == null) return const [];
    final byId = {for (final s in category.allSymptoms) s.id: s};
    return selectedSymptomIds
        .map((id) => byId[id])
        .whereType<SymptomItem>()
        .toList();
  }

  /// Human-readable device display label combining manufacturer, model, and category.
  String get formattedDeviceName {
    final categoryName = selectedCategory?.name ?? 'Device';
    final parts = <String>[
      if (manufacturer.trim().isNotEmpty) manufacturer.trim(),
      if (modelName.trim().isNotEmpty) modelName.trim(),
    ];
    if (parts.isEmpty) return categoryName;
    return '${parts.join(' ')} ($categoryName)';
  }

  FaultReportingWorkflowState copyWith({
    int? currentStep,
    SupportedDeviceCategory? selectedCategory,
    String? manufacturer,
    String? modelName,
    String? deviceAge,
    bool clearDeviceAge = false,
    String? operatingEnvironment,
    bool clearOperatingEnvironment = false,
    Set<String>? selectedSymptomIds,
    String? errorCode,
    String? problemDescription,
    String? startedWhen,
    bool clearStartedWhen = false,
    String? operatingConditions,
    String? validationError,
    bool clearValidationError = false,
    bool? isSubmitting,
    Failure? submissionFailure,
    bool clearSubmissionFailure = false,
    FaultReportModel? savedReport,
    bool clearSavedReport = false,
  }) {
    return FaultReportingWorkflowState(
      currentStep: currentStep ?? this.currentStep,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      manufacturer: manufacturer ?? this.manufacturer,
      modelName: modelName ?? this.modelName,
      deviceAge: clearDeviceAge ? null : (deviceAge ?? this.deviceAge),
      operatingEnvironment: clearOperatingEnvironment
          ? null
          : (operatingEnvironment ?? this.operatingEnvironment),
      selectedSymptomIds: selectedSymptomIds ?? this.selectedSymptomIds,
      errorCode: errorCode ?? this.errorCode,
      problemDescription: problemDescription ?? this.problemDescription,
      startedWhen: clearStartedWhen ? null : (startedWhen ?? this.startedWhen),
      operatingConditions: operatingConditions ?? this.operatingConditions,
      validationError: clearValidationError
          ? null
          : (validationError ?? this.validationError),
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submissionFailure: clearSubmissionFailure
          ? null
          : (submissionFailure ?? this.submissionFailure),
      savedReport: clearSavedReport ? null : (savedReport ?? this.savedReport),
    );
  }
}

class FaultReportController extends Notifier<FaultReportingWorkflowState> {
  @override
  FaultReportingWorkflowState build() => const FaultReportingWorkflowState();

  void selectCategory(SupportedDeviceCategory category) {
    final changed = state.selectedCategory?.id != category.id;
    state = state.copyWith(
      selectedCategory: category,
      selectedSymptomIds: changed ? <String>{} : state.selectedSymptomIds,
      clearValidationError: true,
      clearSubmissionFailure: true,
      clearSavedReport: changed,
    );
  }

  void updateDeviceInfo({
    String? manufacturer,
    String? modelName,
    String? deviceAge,
    bool clearDeviceAge = false,
    String? operatingEnvironment,
    bool clearOperatingEnvironment = false,
  }) {
    state = state.copyWith(
      manufacturer: manufacturer,
      modelName: modelName,
      deviceAge: deviceAge,
      clearDeviceAge: clearDeviceAge,
      operatingEnvironment: operatingEnvironment,
      clearOperatingEnvironment: clearOperatingEnvironment,
      clearValidationError: true,
      clearSavedReport: true,
    );
  }

  void toggleSymptom(String symptomId) {
    final next = Set<String>.from(state.selectedSymptomIds);
    if (next.contains(symptomId)) {
      next.remove(symptomId);
    } else {
      next.add(symptomId);
    }
    state = state.copyWith(
      selectedSymptomIds: next,
      clearValidationError: true,
      clearSavedReport: true,
    );
  }

  void removeSymptom(String symptomId) {
    if (!state.selectedSymptomIds.contains(symptomId)) return;
    final next = Set<String>.from(state.selectedSymptomIds)..remove(symptomId);
    state = state.copyWith(
      selectedSymptomIds: next,
      clearValidationError: true,
      clearSavedReport: true,
    );
  }

  void clearAllSymptoms() {
    state = state.copyWith(
      selectedSymptomIds: <String>{},
      clearSavedReport: true,
    );
  }

  void updateAdditionalInfo({
    String? errorCode,
    String? problemDescription,
    String? startedWhen,
    bool clearStartedWhen = false,
    String? operatingConditions,
  }) {
    state = state.copyWith(
      errorCode: errorCode,
      problemDescription: problemDescription,
      startedWhen: startedWhen,
      clearStartedWhen: clearStartedWhen,
      operatingConditions: operatingConditions,
      clearValidationError: true,
      clearSavedReport: true,
    );
  }

  void goToStep(int step) {
    if (step < 0 || step > 3) return;
    state = state.copyWith(
      currentStep: step,
      clearValidationError: true,
      clearSubmissionFailure: true,
    );
  }

  void previousStep() {
    if (state.currentStep > 0) {
      state = state.copyWith(
        currentStep: state.currentStep - 1,
        clearValidationError: true,
        clearSubmissionFailure: true,
      );
    }
  }

  /// Validates the current step before advancing.
  bool nextStep() {
    final error = _validateStep(state.currentStep);
    if (error != null) {
      state = state.copyWith(validationError: error);
      return false;
    }

    if (state.currentStep < 3) {
      state = state.copyWith(
        currentStep: state.currentStep + 1,
        clearValidationError: true,
      );
    }
    return true;
  }

  String? _validateStep(int step) {
    switch (step) {
      case 0:
        if (state.selectedCategory == null ||
            !state.selectedCategory!.isSupported) {
          return 'Please select a supported device category to continue.';
        }
        if (state.manufacturer.trim().length >
            AppConstants.maxManufacturerLength) {
          return 'Manufacturer must be at most ${AppConstants.maxManufacturerLength} characters.';
        }
        if (state.modelName.trim().length > AppConstants.maxModelLength) {
          return 'Model name must be at most ${AppConstants.maxModelLength} characters.';
        }
        return null;
      case 1:
        if (state.resolvedSelectedSymptoms.isEmpty) {
          return 'Select at least one observed symptom to continue.';
        }
        return null;
      case 2:
        if (state.errorCode.trim().length > AppConstants.maxErrorCodeLength) {
          return 'Error code must be at most ${AppConstants.maxErrorCodeLength} characters.';
        }
        if (state.operatingConditions.trim().length >
            AppConstants.maxOperatingConditionsLength) {
          return 'Operating conditions must be at most ${AppConstants.maxOperatingConditionsLength} characters.';
        }
        if (state.problemDescription.trim().length >
            AppConstants.maxProblemDescriptionLength) {
          return 'Problem description must be at most ${AppConstants.maxProblemDescriptionLength} characters.';
        }
        return null;
      default:
        return null;
    }
  }

  /// Persists the structured fault report locally and submits it to the diagnosis
  /// backend. Prevents duplicate submissions and reuses the saved report on retry.
  ///
  /// Returns the diagnosed `reportId` when the backend completes analysis, or `null`
  /// when the backend fails (without ever fabricating diagnostic results).
  Future<String?> submitAndAnalyze() async {
    // Hard guard preventing repeated requests from rapid multi-taps.
    if (state.isSubmitting) return null;

    for (var step = 0; step <= 2; step++) {
      final error = _validateStep(step);
      if (error != null) {
        state = state.copyWith(currentStep: step, validationError: error);
        return null;
      }
    }

    state = state.copyWith(
      isSubmitting: true,
      clearValidationError: true,
      clearSubmissionFailure: true,
    );

    final category = state.selectedCategory!;
    final selectedSymptoms = state.resolvedSelectedSymptoms;
    final symptomLabels = selectedSymptoms.map((s) => s.label).toList();

    FaultReportModel report;
    if (state.savedReport != null) {
      report = state.savedReport!;
    } else {
      final summaryTitle = symptomLabels.length == 1
          ? symptomLabels.first
          : '${symptomLabels.first} (+${symptomLabels.length - 1} more)';

      final cleanDescription = state.problemDescription.trim().isNotEmpty
          ? state.problemDescription.trim()
          : 'Reported symptoms: ${symptomLabels.join(', ')}.';

      final activeUserId =
          ref.read(preferencesServiceProvider).activeUserId ?? '';
      report = FaultReportModel(
        id: 'rep_${DateTime.now().microsecondsSinceEpoch}',
        userId: activeUserId,
        deviceId: 'cat_${category.id}',
        deviceName: state.formattedDeviceName,
        deviceCategory: category.id,
        manufacturer: state.manufacturer.trim().isEmpty
            ? null
            : state.manufacturer.trim(),
        modelName:
            state.modelName.trim().isEmpty ? null : state.modelName.trim(),
        deviceAge: state.deviceAge,
        operatingEnvironment: state.operatingEnvironment,
        title: summaryTitle,
        description: cleanDescription,
        symptoms: symptomLabels,
        severity: FaultSeverity.medium,
        status: FaultReportStatus.pendingDiagnosis,
        errorCode:
            state.errorCode.trim().isEmpty ? null : state.errorCode.trim(),
        startedWhen: state.startedWhen,
        operatingConditions: state.operatingConditions.trim().isEmpty
            ? null
            : state.operatingConditions.trim(),
        createdAt: DateTime.now(),
      );

      final saveResult =
          await ref.read(faultReportRepositoryProvider).createReport(report);
      final saveFailure = saveResult.when<Failure?>(
        success: (_) => null,
        failure: (err) => err,
      );
      if (saveFailure != null) {
        state = state.copyWith(
          isSubmitting: false,
          submissionFailure: saveFailure,
        );
        return null;
      }

      ref.invalidate(historyControllerProvider);
      ref.invalidate(dashboardControllerProvider);
    }

    // Submit structured payload to diagnosis backend.
    final diagnosisResult =
        await ref.read(diagnosisRepositoryProvider).runDiagnosis(report);

    return diagnosisResult.when(
      success: (_) {
        ref.invalidate(dashboardControllerProvider);
        ref.invalidate(historyControllerProvider);
        state = const FaultReportingWorkflowState();
        return report.id;
      },
      failure: (err) {
        state = state.copyWith(
          isSubmitting: false,
          submissionFailure: err,
          savedReport: report,
        );
        return null;
      },
    );
  }

  void dismissFailure() {
    state = state.copyWith(clearSubmissionFailure: true);
  }

  void resetWorkflow() {
    state = const FaultReportingWorkflowState();
  }
}

final faultReportControllerProvider =
    NotifierProvider<FaultReportController, FaultReportingWorkflowState>(
  FaultReportController.new,
);
