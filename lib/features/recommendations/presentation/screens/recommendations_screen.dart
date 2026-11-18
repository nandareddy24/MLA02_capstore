import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utilities/responsive_layout.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading_indicator.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/recommendation_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../core/widgets/symptom_chip.dart';
import '../../../../data/models/decision_support_plan_model.dart';
import '../../../feedback/presentation/controllers/feedback_controller.dart';
import '../controllers/recommendations_controller.dart';

/// Displays severity-aware, expert-reviewed Recommended Actions for a diagnosed fault.
class RecommendationsScreen extends ConsumerStatefulWidget {
  const RecommendationsScreen({
    super.key,
    required this.reportId,
  });

  final String reportId;

  @override
  ConsumerState<RecommendationsScreen> createState() =>
      _RecommendationsScreenState();
}

class _RecommendationsScreenState extends ConsumerState<RecommendationsScreen> {
  /// Tracks safe steps explicitly checked off by the user. Never pre-populated.
  final Set<String> _completedStepIds = {};

  // Inline post-recommendation feedback state
  bool? _wasHelpful;
  bool? _resolvedProblem;
  bool? _needsProfessionalHelp;
  final TextEditingController _feedbackNotesCtrl = TextEditingController();
  bool _feedbackSubmitted = false;

  @override
  void dispose() {
    _feedbackNotesCtrl.dispose();
    super.dispose();
  }

  void _toggleStepCompleted(String stepId, bool value) {
    setState(() {
      if (value) {
        _completedStepIds.add(stepId);
      } else {
        _completedStepIds.remove(stepId);
      }
    });
  }

  Future<void> _submitFeedback(DecisionSupportPlanModel plan) async {
    if (_wasHelpful == null ||
        _resolvedProblem == null ||
        _needsProfessionalHelp == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please answer all three feedback questions first.'),
        ),
      );
      return;
    }

    final success = await ref.read(feedbackControllerProvider.notifier).submit(
          diagnosisId: plan.diagnosisId,
          reportId: plan.reportId,
          wasHelpful: _wasHelpful!,
          wasIssueResolved: _resolvedProblem!,
          stillNeedsProfessionalAssistance: _needsProfessionalHelp!,
          rating: _wasHelpful! ? 5 : 2,
          comments: _feedbackNotesCtrl.text,
        );

    if (success && mounted) {
      setState(() => _feedbackSubmitted = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Feedback saved against this diagnosis record.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final planAsync = ref.watch(decisionSupportPlanProvider(widget.reportId));
    final feedbackState = ref.watch(feedbackControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Recommended Actions')),
      body: planAsync.when(
        loading: () =>
            const AppLoadingIndicator(message: 'Loading recommended actions...'),
        error: (error, _) => AppErrorState(
          message: error is Failure
              ? error.message
              : 'Unable to load decision-support recommendations.',
          onRetry: () =>
              ref.invalidate(decisionSupportPlanProvider(widget.reportId)),
        ),
        data: (plan) {
          if (plan == null) {
            return AppEmptyState(
              icon: LucideIcons.listChecks,
              title: 'No recommendations generated yet',
              message:
                  'Severity-aware, reviewed repair recommendations will appear once the diagnosis engine evaluates this fault report.',
              actionLabel: 'Back to Diagnosis',
              actionIcon: LucideIcons.arrowLeft,
              onAction: () => context.pop(),
            );
          }

          return SingleChildScrollView(
            child: ResponsiveContentContainer(
              maxWidth: 760,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Recommended Actions',
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'Guidance derived from expert-reviewed FixWise knowledge-base records.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.contentVertical),

                  // High-Risk / Dangerous Fault Warning Banner
                  if (plan.isDangerousFault) ...[
                    _DangerousFaultBanner(
                      bannerText: plan.immediateSafetyBanner ??
                          'Stop using this device immediately. Avoid DIY repairs and contact a qualified technician.',
                      emergencyGuidance: plan.escalation.emergencyGuidance,
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // A. Fault Summary
                  _FaultSummaryCard(plan: plan),
                  const SizedBox(height: AppSpacing.md),

                  // B. Likely Cause
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Likely Cause', style: theme.textTheme.titleLarge),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          plan.likelyCause,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // C. First Recommended Check
                  if (plan.firstRecommendedCheck != null) ...[
                    Text(
                      'First Recommended Check',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    RecommendationCard(
                      stepNumber: 1,
                      recommendation: plan.firstRecommendedCheck!,
                      isCompleted: _completedStepIds
                          .contains(plan.firstRecommendedCheck!.id),
                      onCompletedChanged: plan.firstRecommendedCheck!.isCheckable
                          ? (val) => _toggleStepCompleted(
                                plan.firstRecommendedCheck!.id,
                                val,
                              )
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  // D. Step-by-Step Guidance
                  Text(
                    'Step-by-Step Guidance',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    plan.isDangerousFault
                        ? 'Follow immediate safety and escalation steps in order.'
                        : 'Ranked by safety, fault relevance, and severity. Check off safe steps as you complete them.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ...plan.recommendations.asMap().entries.map((entry) {
                    final step = entry.value;
                    final stepNo = entry.key + 1;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: RecommendationCard(
                        stepNumber: stepNo,
                        recommendation: step,
                        isCompleted: _completedStepIds.contains(step.id),
                        onCompletedChanged: step.isCheckable
                            ? (val) => _toggleStepCompleted(step.id, val)
                            : null,
                      ),
                    );
                  }),

                  // E. Safety Information
                  if (plan.safetyWarnings.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    _SafetyWarningsCard(warnings: plan.safetyWarnings),
                  ],

                  // F. Escalation Guidance
                  const SizedBox(height: AppSpacing.md),
                  _EscalationCard(escalation: plan.escalation),

                  // G. Post-Recommendation Feedback
                  const SizedBox(height: AppSpacing.lg),
                  _RecommendationFeedbackCard(
                    diagnosisId: plan.diagnosisId,
                    wasHelpful: _wasHelpful,
                    resolvedProblem: _resolvedProblem,
                    needsProfessionalHelp: _needsProfessionalHelp,
                    notesController: _feedbackNotesCtrl,
                    isSubmitting: feedbackState.isSubmitting,
                    submitted: _feedbackSubmitted,
                    onHelpfulChanged: (v) => setState(() => _wasHelpful = v),
                    onResolvedChanged: (v) =>
                        setState(() => _resolvedProblem = v),
                    onNeedsProChanged: (v) =>
                        setState(() => _needsProfessionalHelp = v),
                    onSubmit: () => _submitFeedback(plan),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DangerousFaultBanner extends StatelessWidget {
  const _DangerousFaultBanner({
    required this.bannerText,
    this.emergencyGuidance,
  });

  final String bannerText;
  final String? emergencyGuidance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.dangerousSurface(theme.brightness),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(
          color: AppColors.dangerous,
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            LucideIcons.octagonAlert,
            size: AppSpacing.iconLg,
            color: AppColors.dangerous,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'High-Risk Safety Warning',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.dangerous,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  bannerText,
                  style: theme.textTheme.bodyMedium,
                ),
                if (emergencyGuidance != null &&
                    emergencyGuidance!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    emergencyGuidance!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.dangerous,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FaultSummaryCard extends StatelessWidget {
  const _FaultSummaryCard({required this.plan});

  final DecisionSupportPlanModel plan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final severityTone = switch (plan.severity) {
      DecisionSeverityLevel.safe => BadgeTone.safe,
      DecisionSeverityLevel.medium => BadgeTone.warning,
      DecisionSeverityLevel.high => BadgeTone.dangerous,
    };

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              StatusBadge(
                label: 'Severity: ${plan.severity.label}',
                tone: severityTone,
                icon: plan.severity == DecisionSeverityLevel.high
                    ? LucideIcons.octagonAlert
                    : plan.severity == DecisionSeverityLevel.medium
                        ? LucideIcons.triangleAlert
                        : LucideIcons.circleCheck,
              ),
              StatusBadge(
                label: plan.deviceCategory.replaceAll('_', ' ').toUpperCase(),
                tone: BadgeTone.info,
              ),
              if (plan.expertReviewStatus == 'reviewed')
                const StatusBadge(
                  label: 'Reviewed KB',
                  tone: BadgeTone.safe,
                  icon: LucideIcons.shieldCheck,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(plan.predictedFault, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            plan.severityRationale,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _SafetyWarningsCard extends StatelessWidget {
  const _SafetyWarningsCard({required this.warnings});

  final List<String> warnings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warningSurface(theme.brightness),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.4),
        ),
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
                child: Text(
                  'Safety Information',
                  style: theme.textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ...warnings.map(
            (warning) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• '),
                  Expanded(
                    child: Text(warning, style: theme.textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EscalationCard extends StatelessWidget {
  const _EscalationCard({required this.escalation});

  final EscalationGuidanceModel escalation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppCard(
      borderColor: escalation.stopUsingDevice
          ? AppColors.dangerous.withValues(alpha: 0.5)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.wrench,
                size: AppSpacing.iconSm,
                color: escalation.stopUsingDevice
                    ? AppColors.dangerous
                    : colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'When to Contact a Qualified Technician',
                  style: theme.textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            escalation.whenToEscalate,
            style: theme.textTheme.bodyMedium,
          ),
          if (escalation.emergencyGuidance != null &&
              escalation.emergencyGuidance!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              escalation.emergencyGuidance!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.dangerous,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecommendationFeedbackCard extends StatelessWidget {
  const _RecommendationFeedbackCard({
    required this.diagnosisId,
    required this.wasHelpful,
    required this.resolvedProblem,
    required this.needsProfessionalHelp,
    required this.notesController,
    required this.isSubmitting,
    required this.submitted,
    required this.onHelpfulChanged,
    required this.onResolvedChanged,
    required this.onNeedsProChanged,
    required this.onSubmit,
  });

  final String diagnosisId;
  final bool? wasHelpful;
  final bool? resolvedProblem;
  final bool? needsProfessionalHelp;
  final TextEditingController notesController;
  final bool isSubmitting;
  final bool submitted;
  final ValueChanged<bool> onHelpfulChanged;
  final ValueChanged<bool> onResolvedChanged;
  final ValueChanged<bool> onNeedsProChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (submitted) {
      return AppCard(
        borderColor: AppColors.safe.withValues(alpha: 0.4),
        child: Row(
          children: [
            const Icon(
              LucideIcons.circleCheck,
              color: AppColors.safe,
              size: AppSpacing.iconMd,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Feedback Recorded', style: theme.textTheme.titleMedium),
                  Text(
                    'Saved against diagnosis ID $diagnosisId.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Was This Guidance Helpful?', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Your response is saved against diagnosis ID $diagnosisId to improve decision support.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          _YesNoQuestion(
            question: 'Was this guidance helpful?',
            value: wasHelpful,
            onChanged: onHelpfulChanged,
          ),
          const SizedBox(height: AppSpacing.sm),
          _YesNoQuestion(
            question: 'Did the suggested action resolve the problem?',
            value: resolvedProblem,
            onChanged: onResolvedChanged,
          ),
          const SizedBox(height: AppSpacing.sm),
          _YesNoQuestion(
            question: 'Do you still need professional assistance?',
            value: needsProfessionalHelp,
            onChanged: onNeedsProChanged,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: notesController,
            label: 'Additional Notes (Optional)',
            hint: 'Share what worked or what remained unresolved...',
            minLines: 2,
            maxLines: 4,
          ),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            label: 'Submit Feedback',
            icon: LucideIcons.send,
            isLoading: isSubmitting,
            onPressed: onSubmit,
          ),
        ],
      ),
    );
  }
}

class _YesNoQuestion extends StatelessWidget {
  const _YesNoQuestion({
    required this.question,
    required this.value,
    required this.onChanged,
  });

  final String question;
  final bool? value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(question, style: theme.textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          children: [
            SymptomChip(
              label: 'Yes',
              selected: value == true,
              onSelected: (_) => onChanged(true),
            ),
            SymptomChip(
              label: 'No',
              selected: value == false,
              onSelected: (_) => onChanged(false),
            ),
          ],
        ),
      ],
    );
  }
}
