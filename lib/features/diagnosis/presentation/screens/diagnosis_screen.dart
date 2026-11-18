import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utilities/date_formatter.dart';
import '../../../../core/utilities/responsive_layout.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading_indicator.dart';
import '../../../../core/widgets/diagnosis_result_card.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/secondary_button.dart';
import '../../../../core/widgets/severity_indicator.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../data/models/diagnosis_result_model.dart';
import '../../../../data/models/fault_report_model.dart';
import '../../../../data/models/feedback_model.dart';
import '../controllers/diagnosis_controller.dart';

class DiagnosisScreen extends ConsumerWidget {
  const DiagnosisScreen({
    super.key,
    required this.reportId,
  });

  final String reportId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(diagnosisDetailProvider(reportId));
    final actionState = ref.watch(diagnosisActionProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnosis Results'),
        actions: [
          IconButton(
            tooltip: 'Refresh diagnosis',
            onPressed: () => ref.invalidate(diagnosisDetailProvider(reportId)),
            icon: const Icon(LucideIcons.refreshCw, size: AppSpacing.iconSm),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: detailAsync.when(
        loading: () =>
            const AppLoadingIndicator(message: 'Loading diagnosis record...'),
        error: (error, _) => AppErrorState(
          message: error is Failure
              ? error.message
              : 'Unable to load fault diagnosis record.',
          onRetry: () => ref.invalidate(diagnosisDetailProvider(reportId)),
        ),
        data: (viewData) {
          final report = viewData.report;
          if (report == null) {
            return AppEmptyState(
              icon: LucideIcons.fileSearch,
              title: 'Fault report not found',
              message:
                  'This fault report may have been removed from local storage.',
              actionLabel: 'View History',
              onAction: () => context.go(AppRoutes.history),
            );
          }

          if (actionState.isAnalyzing) {
            return const Center(
              child: AppLoadingIndicator(
                message: 'Analyzing reported symptoms',
              ),
            );
          }

          final diagnosis = viewData.diagnosis;

          return SingleChildScrollView(
            child: ResponsiveContentContainer(
              maxWidth: 760,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Diagnosis Results',
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    '${report.deviceName} • Case ID ${report.id}',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.contentVertical),
                  if (diagnosis != null) ...[
                    // A. Primary Result Card
                    DiagnosisResultCard(
                      diagnosis: diagnosis,
                      fallbackDeviceName: report.deviceName,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Honest Uncertainty & Disclaimer Banner
                    _UncertaintyNoticeCard(diagnosis: diagnosis),
                    const SizedBox(height: AppSpacing.md),

                    // B. Other Possible Causes (Ranked Alternatives)
                    if (diagnosis.rankedAlternatives.isNotEmpty) ...[
                      _OtherPossibleCausesCard(
                        alternatives: diagnosis.rankedAlternatives,
                        showProbability: diagnosis.confidenceIsCalibrated,
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],

                    // C. Evidence Section
                    _EvidenceCard(
                      diagnosis: diagnosis,
                      report: report,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // D. Severity Section (Decision-Support Rules)
                    _SeverityDecisionCard(diagnosis: diagnosis),
                    const SizedBox(height: AppSpacing.md),

                    // Original Device & Reported Context Snapshot
                    _OriginalDeviceSnapshotCard(report: report),
                    const SizedBox(height: AppSpacing.md),

                    // Preserved Safety Warnings (when present in decision support plan)
                    if (diagnosis.decisionSupportPlan != null &&
                        diagnosis.decisionSupportPlan!.safetyWarnings
                            .isNotEmpty) ...[
                      _PreservedSafetyWarningsCard(
                        warnings: diagnosis.decisionSupportPlan!.safetyWarnings,
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],

                    // Preserved User Feedback Section
                    _PreservedFeedbackSummaryCard(
                      feedback: viewData.feedback,
                      onOpenFeedback: () => context.push(
                        AppRoutes.feedbackPath(report.id),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // E. Next Step: View Recommendations
                    PrimaryButton(
                      label: 'View Recommendations',
                      icon: LucideIcons.listChecks,
                      onPressed: () => context.push(
                        AppRoutes.recommendationsPath(report.id),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SecondaryButton(
                      label: viewData.feedback != null
                          ? 'Update Feedback'
                          : 'Submit Feedback',
                      icon: LucideIcons.messageSquare,
                      onPressed: () => context.push(
                        AppRoutes.feedbackPath(report.id),
                      ),
                    ),
                  ] else ...[
                    _FaultSummaryCard(report: report),
                    const SizedBox(height: AppSpacing.contentVertical),
                    _PendingDiagnosisSection(
                      isMlServiceConfigured: viewData.isMlServiceConfigured,
                      actionState: actionState,
                      onRunDiagnosis: () => ref
                          .read(diagnosisActionProvider.notifier)
                          .runDiagnosis(report),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: SecondaryButton(
                            label: 'View Recommendations',
                            icon: LucideIcons.listChecks,
                            onPressed: () => context.push(
                              AppRoutes.recommendationsPath(report.id),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: SecondaryButton(
                            label: 'Log Feedback',
                            icon: LucideIcons.messageSquare,
                            onPressed: () => context.push(
                              AppRoutes.feedbackPath(report.id),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _UncertaintyNoticeCard extends StatelessWidget {
  const _UncertaintyNoticeCard({required this.diagnosis});

  final DiagnosisResultModel diagnosis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWarning = diagnosis.isUncertain;
    final accent = isWarning ? AppColors.warning : AppColors.information;
    final surface = isWarning
        ? AppColors.warningSurface(theme.brightness)
        : AppColors.informationSurface(theme.brightness);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isWarning ? LucideIcons.triangleAlert : LucideIcons.info,
            size: AppSpacing.iconSm,
            color: accent,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isWarning
                      ? 'Diagnostic Uncertainty Notice'
                      : 'Decision Support Notice',
                  style: theme.textTheme.titleSmall?.copyWith(color: accent),
                ),
                if (diagnosis.uncertaintyMessage != null &&
                    diagnosis.uncertaintyMessage!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    diagnosis.uncertaintyMessage!,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  diagnosis.disclaimer,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OtherPossibleCausesCard extends StatelessWidget {
  const _OtherPossibleCausesCard({
    required this.alternatives,
    required this.showProbability,
  });

  final List<AlternativeFaultModel> alternatives;
  final bool showProbability;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Other Possible Causes', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Ranked alternative fault categories returned by the classifier.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          ...alternatives.asMap().entries.map((entry) {
            final rank = entry.key + 2;
            final alt = entry.value;
            final probLabel = (showProbability && alt.probability != null)
                ? '${(alt.probability! * 100).toStringAsFixed(1)}%'
                : 'Ranked #$rank';
            return Padding(
              padding: EdgeInsets.only(
                bottom: entry.key < alternatives.length - 1 ? AppSpacing.sm : 0,
              ),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                  border: Border.all(color: colorScheme.outline),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                        border: Border.all(color: colorScheme.outline),
                      ),
                      child: Text(
                        '#$rank',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        alt.faultCategory,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    StatusBadge(label: probLabel),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _EvidenceCard extends StatelessWidget {
  const _EvidenceCard({
    required this.diagnosis,
    required this.report,
  });

  final DiagnosisResultModel diagnosis;
  final FaultReportModel report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = diagnosis.evidence.isNotEmpty
        ? diagnosis.evidence
        : [
            ...report.symptoms.map(
              (s) => DiagnosticEvidenceModel(
                signalType: 'symptom',
                source: 'Reported Symptom',
                detail: s,
              ),
            ),
            if (report.errorCode != null)
              DiagnosticEvidenceModel(
                signalType: 'error_code',
                source: 'Error Code',
                detail: report.errorCode!,
              ),
          ];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Diagnostic Evidence', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Reported symptoms, error codes, and device context supporting this assessment.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          ...items.map((item) {
            final icon = switch (item.signalType) {
              'error_code' => LucideIcons.terminal,
              'context' => LucideIcons.slidersHorizontal,
              _ => LucideIcons.circleCheck,
            };
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: theme.colorScheme.secondary,
                  ),
                  const SizedBox(width: AppSpacing.xs + 2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.source, style: theme.textTheme.labelSmall),
                        Text(item.detail, style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _SeverityDecisionCard extends StatelessWidget {
  const _SeverityDecisionCard({required this.diagnosis});

  final DiagnosisResultModel diagnosis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Severity Assessment', style: theme.textTheme.titleLarge),
              SeverityIndicator(severity: diagnosis.severity),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            diagnosis.severityRationale,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _OriginalDeviceSnapshotCard extends StatelessWidget {
  const _OriginalDeviceSnapshotCard({required this.report});

  final FaultReportModel report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Original Device & Report', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text('Device: ${report.deviceName}', style: theme.textTheme.bodyMedium),
          if (report.deviceCategory != null)
            Text(
              'Category: ${report.deviceCategory!.replaceAll('_', ' ')}',
              style: theme.textTheme.bodySmall,
            ),
          if (report.errorCode != null)
            Text('Error Code: ${report.errorCode}', style: theme.textTheme.bodySmall),
          if (report.deviceAge != null)
            Text('Device Age: ${report.deviceAge}', style: theme.textTheme.bodySmall),
          if (report.operatingEnvironment != null)
            Text(
              'Environment: ${report.operatingEnvironment}',
              style: theme.textTheme.bodySmall,
            ),
          if (report.startedWhen != null)
            Text(
              'Problem Started: ${report.startedWhen}',
              style: theme.textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}

class _PreservedSafetyWarningsCard extends StatelessWidget {
  const _PreservedSafetyWarningsCard({required this.warnings});

  final List<String> warnings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warningSurface(theme.brightness),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                LucideIcons.triangleAlert,
                size: AppSpacing.iconSm,
                color: AppColors.warning,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text('Safety Warnings', style: theme.textTheme.titleLarge),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ...warnings.map(
            (w) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
              child: Text('• $w', style: theme.textTheme.bodyMedium),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreservedFeedbackSummaryCard extends StatelessWidget {
  const _PreservedFeedbackSummaryCard({
    required this.feedback,
    required this.onOpenFeedback,
  });

  final FeedbackModel? feedback;
  final VoidCallback onOpenFeedback;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text('User Feedback', style: theme.textTheme.titleLarge),
              ),
              TextButton(
                onPressed: onOpenFeedback,
                child: Text(feedback == null ? 'Add' : 'Update'),
              ),
            ],
          ),
          if (feedback == null) ...[
            Text(
              'No feedback submitted yet.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ] else ...[
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                StatusBadge(
                  label: 'Relevance: ${feedback!.diagnosisRelevance.label}',
                  tone: BadgeTone.info,
                ),
                StatusBadge(
                  label: feedback!.resolutionStatus.label,
                  tone: feedback!.resolutionStatus == ResolutionStatus.resolved
                      ? BadgeTone.safe
                      : BadgeTone.warning,
                ),
              ],
            ),
            if (feedback!.comments.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(feedback!.comments, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Submitted ${DateFormatter.formatDateTime(feedback!.submittedAt)}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _FaultSummaryCard extends StatelessWidget {
  const _FaultSummaryCard({required this.report});

  final FaultReportModel report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              StatusBadge(
                label: report.status.label,
                tone: switch (report.status) {
                  FaultReportStatus.pendingDiagnosis => BadgeTone.warning,
                  FaultReportStatus.diagnosed => BadgeTone.info,
                  FaultReportStatus.resolved => BadgeTone.safe,
                },
              ),
              SeverityIndicator(severity: report.severity, showPrefix: true),
              if (report.errorCode != null)
                StatusBadge(
                  label: 'Code: ${report.errorCode}',
                  icon: LucideIcons.terminal,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(report.title, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            '${report.deviceName} • Reported ${DateFormatter.formatDateTime(report.createdAt)}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(report.description, style: theme.textTheme.bodyMedium),
          if (report.symptoms.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            const Divider(),
            const SizedBox(height: AppSpacing.sm),
            Text('Observed Symptoms', style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: report.symptoms
                  .map((s) => StatusBadge(label: s))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _PendingDiagnosisSection extends StatelessWidget {
  const _PendingDiagnosisSection({
    required this.isMlServiceConfigured,
    required this.actionState,
    required this.onRunDiagnosis,
  });

  final bool isMlServiceConfigured;
  final DiagnosisActionState actionState;
  final VoidCallback onRunDiagnosis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.activity,
                size: AppSpacing.iconSm,
                color: colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'AI Fault Diagnosis Engine',
                style: theme.textTheme.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            isMlServiceConfigured
                ? 'Submit this fault report to the Python scikit-learn diagnosis service to obtain probable fault rankings and decision-support evidence.'
                : 'Model integration is pending: no trained FixWise diagnosis backend URL is configured yet. FixWise does not display fabricated predictions.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (actionState.failure != null) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.warningSurface(theme.brightness),
                borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    LucideIcons.triangleAlert,
                    color: AppColors.warning,
                    size: 18,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      actionState.failure!.message,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            label: actionState.failure != null
                ? 'Retry Analysis'
                : 'Analyze Reported Symptoms',
            icon: actionState.failure != null
                ? LucideIcons.refreshCw
                : LucideIcons.activity,
            isLoading: actionState.isAnalyzing,
            onPressed: onRunDiagnosis,
          ),
          if (!isMlServiceConfigured) ...[
            const SizedBox(height: AppSpacing.sm),
            SecondaryButton(
              label: 'Configure Backend URL',
              icon: LucideIcons.settings,
              onPressed: () => context.go(AppRoutes.profile),
            ),
          ],
        ],
      ),
    );
  }
}
