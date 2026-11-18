import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utilities/responsive_layout.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading_indicator.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/secondary_button.dart';
import '../../../device_selection/presentation/controllers/device_catalog_provider.dart';
import '../controllers/fault_report_controller.dart';
import '../widgets/step_additional_info.dart';
import '../widgets/step_device_selection.dart';
import '../widgets/step_review_submit.dart';
import '../widgets/step_symptom_selection.dart';
import '../widgets/submission_status_view.dart';
import '../widgets/workflow_progress_header.dart';

/// Guided 4-step Device Selection & Fault Reporting workflow:
/// 1. Select Device
/// 2. Select Symptoms
/// 3. Additional Information
/// 4. Review & Submit
class FaultReportingScreen extends ConsumerStatefulWidget {
  const FaultReportingScreen({
    super.key,
    this.deviceId,
  });

  final String? deviceId;

  @override
  ConsumerState<FaultReportingScreen> createState() =>
      _FaultReportingScreenState();
}

class _FaultReportingScreenState extends ConsumerState<FaultReportingScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  void _onPrimaryAction() {
    final controller = ref.read(faultReportControllerProvider.notifier);
    final state = ref.read(faultReportControllerProvider);

    if (state.currentStep < 3) {
      final advanced = controller.nextStep();
      if (advanced) {
        _scrollToTop();
      }
    } else {
      _submitForAnalysis();
    }
  }

  Future<void> _submitForAnalysis() async {
    FocusScope.of(context).unfocus();
    final reportId = await ref
        .read(faultReportControllerProvider.notifier)
        .submitAndAnalyze();

    if (reportId != null && mounted) {
      context.push(AppRoutes.diagnosisPath(reportId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(diagnosticCatalogProvider);
    final workflow = ref.watch(faultReportControllerProvider);
    final controller = ref.read(faultReportControllerProvider.notifier);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fault Diagnosis'),
        actions: [
          if (!workflow.isSubmitting &&
              (workflow.selectedCategory != null || workflow.currentStep > 0))
            TextButton(
              onPressed: () {
                controller.resetWorkflow();
                _scrollToTop();
              },
              child: const Text('Reset'),
            ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: catalogAsync.when(
        loading: () => const AppLoadingIndicator(
          message: 'Loading supported device catalog...',
        ),
        error: (error, _) => AppErrorState(
          title: 'Unable to load device catalog',
          message: error is Failure
              ? error.message
              : 'Could not read supported device categories and symptoms.',
          onRetry: () => ref.invalidate(diagnosticCatalogProvider),
        ),
        data: (catalog) {
          final supportedCategories = catalog.supportedCategories;
          if (supportedCategories.isEmpty) {
            return const AppEmptyState(
              icon: LucideIcons.smartphone,
              title: 'No supported device categories',
              message:
                  'Configure your FixWise diagnostic catalog to enable fault reporting.',
            );
          }

          if (workflow.isSubmitting) {
            return AnalysisProcessingView(
              deviceLabel: workflow.formattedDeviceName,
            );
          }

          if (workflow.submissionFailure != null) {
            final savedId = workflow.savedReport?.id;
            return AnalysisFailureView(
              failure: workflow.submissionFailure!,
              onRetry: _submitForAnalysis,
              onEditReport: controller.dismissFailure,
              onViewSavedReport: savedId != null
                  ? () {
                      controller.resetWorkflow();
                      context.push(AppRoutes.diagnosisPath(savedId));
                    }
                  : null,
            );
          }

          final primaryLabel = switch (workflow.currentStep) {
            0 || 1 => 'Continue',
            2 => 'Review',
            _ => 'Analyze Problem',
          };

          final primaryIcon = switch (workflow.currentStep) {
            3 => LucideIcons.activity,
            _ => LucideIcons.arrowRight,
          };

          return Column(
            children: [
              WorkflowProgressHeader(currentStep: workflow.currentStep),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  child: ResponsiveContentContainer(
                    maxWidth: 760,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (workflow.validationError != null) ...[
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.dangerousSurface(theme.brightness),
                              borderRadius: BorderRadius.circular(
                                AppSpacing.inputRadius,
                              ),
                              border: Border.all(
                                color:
                                    AppColors.dangerous.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  LucideIcons.triangleAlert,
                                  size: 18,
                                  color: AppColors.dangerous,
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Expanded(
                                  child: Text(
                                    workflow.validationError!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: AppColors.dangerous,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],
                        switch (workflow.currentStep) {
                          0 => StepDeviceSelection(
                              categories: supportedCategories,
                              state: workflow,
                              onSelectCategory: controller.selectCategory,
                              onUpdateDetails: ({
                                String? manufacturer,
                                String? modelName,
                                String? deviceAge,
                                bool clearDeviceAge = false,
                                String? operatingEnvironment,
                                bool clearOperatingEnvironment = false,
                              }) {
                                controller.updateDeviceInfo(
                                  manufacturer: manufacturer,
                                  modelName: modelName,
                                  deviceAge: deviceAge,
                                  clearDeviceAge: clearDeviceAge,
                                  operatingEnvironment: operatingEnvironment,
                                  clearOperatingEnvironment:
                                      clearOperatingEnvironment,
                                );
                              },
                            ),
                          1 => StepSymptomSelection(
                              state: workflow,
                              onToggleSymptom: controller.toggleSymptom,
                              onRemoveSymptom: controller.removeSymptom,
                              onClearAll: controller.clearAllSymptoms,
                            ),
                          2 => StepAdditionalInfo(
                              state: workflow,
                              onUpdate: ({
                                String? errorCode,
                                String? problemDescription,
                                String? startedWhen,
                                bool clearStartedWhen = false,
                                String? operatingConditions,
                              }) {
                                controller.updateAdditionalInfo(
                                  errorCode: errorCode,
                                  problemDescription: problemDescription,
                                  startedWhen: startedWhen,
                                  clearStartedWhen: clearStartedWhen,
                                  operatingConditions: operatingConditions,
                                );
                              },
                            ),
                          _ => StepReviewSubmit(
                              state: workflow,
                              onEditStep: (step) {
                                controller.goToStep(step);
                                _scrollToTop();
                              },
                            ),
                        },
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  border: Border(
                    top: BorderSide(color: colorScheme.outline, width: 1),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenHorizontal,
                      vertical: AppSpacing.sm + 2,
                    ),
                    child: Align(
                      alignment: Alignment.center,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: Row(
                          children: [
                            if (workflow.currentStep > 0) ...[
                              Expanded(
                                child: SecondaryButton(
                                  label: 'Back',
                                  onPressed: () {
                                    controller.previousStep();
                                    _scrollToTop();
                                  },
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                            ],
                            Expanded(
                              flex: 2,
                              child: PrimaryButton(
                                label: primaryLabel,
                                icon: primaryIcon,
                                isLoading: workflow.isSubmitting,
                                onPressed: _onPrimaryAction,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
