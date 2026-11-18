import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utilities/date_formatter.dart';
import '../../../../core/utilities/responsive_layout.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading_indicator.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../core/widgets/symptom_chip.dart';
import '../../../../data/models/feedback_model.dart';
import '../../../diagnosis/presentation/controllers/diagnosis_controller.dart';
import '../controllers/feedback_controller.dart';

/// Structured post-diagnosis feedback screen supporting controlled updates
/// and preventing duplicate records for the same diagnosis.
class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({
    super.key,
    required this.reportId,
  });

  final String reportId;

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  final _commentsController = TextEditingController();
  DiagnosisRelevance? _relevance;
  ResolutionStatus? _resolutionStatus;
  bool _hydratedExisting = false;

  @override
  void dispose() {
    _commentsController.dispose();
    super.dispose();
  }

  void _hydrateFromExisting(FeedbackModel existing) {
    if (_hydratedExisting) return;
    _hydratedExisting = true;
    _relevance = existing.diagnosisRelevance;
    _resolutionStatus = existing.resolutionStatus;
    _commentsController.text = existing.comments;
  }

  Future<void> _submit({
    required String? diagnosisId,
    required bool isUpdate,
  }) async {
    FocusScope.of(context).unfocus();
    if (_relevance == null || _resolutionStatus == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please answer both relevance and resolution questions before submitting.',
          ),
        ),
      );
      return;
    }

    final success = await ref.read(feedbackControllerProvider.notifier).submit(
          diagnosisId: diagnosisId,
          reportId: widget.reportId,
          diagnosisRelevance: _relevance!,
          resolutionStatus: _resolutionStatus!,
          comments: _commentsController.text,
        );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isUpdate
                ? 'Feedback updated successfully.'
                : 'Feedback submitted successfully.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedbackAsync = ref.watch(reportFeedbackListProvider(widget.reportId));
    final detailAsync = ref.watch(diagnosisDetailProvider(widget.reportId));
    final submitState = ref.watch(feedbackControllerProvider);
    final theme = Theme.of(context);

    final diagnosisId = detailAsync.asData?.value.diagnosis?.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Feedback')),
      body: feedbackAsync.when(
        loading: () =>
            const AppLoadingIndicator(message: 'Loading feedback status...'),
        error: (error, _) => AppErrorState(
          message: error is Failure
              ? error.message
              : 'Unable to load previous feedback.',
          onRetry: () =>
              ref.invalidate(reportFeedbackListProvider(widget.reportId)),
        ),
        data: (entries) {
          final existing = entries.isNotEmpty ? entries.first : null;
          if (existing != null) {
            _hydrateFromExisting(existing);
          }

          return SingleChildScrollView(
            child: ResponsiveContentContainer(
              maxWidth: 720,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Diagnosis Feedback',
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'Share whether the diagnosis was relevant and whether the recommendations resolved your issue.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.contentVertical),
                  if (existing == null) ...[
                    const AppCard(
                      child: AppEmptyState(
                        icon: LucideIcons.messageSquare,
                        title: 'No feedback submitted yet.',
                        message:
                            'Complete the short form below to record your outcome for this diagnosis.',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ] else ...[
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: AppSpacing.xs,
                            runSpacing: AppSpacing.xs,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const StatusBadge(
                                label: 'Feedback Recorded',
                                tone: BadgeTone.safe,
                                icon: LucideIcons.circleCheck,
                              ),
                              Text(
                                'Updated ${DateFormatter.formatDateTime(existing.submittedAt)}',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'You can update your responses below; updating replaces your previous entry rather than creating duplicates.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (submitState.errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(
                                AppSpacing.inputRadius,
                              ),
                              border: Border.all(
                                color: theme.colorScheme.error.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  LucideIcons.triangleAlert,
                                  size: AppSpacing.iconSm,
                                  color: theme.colorScheme.error,
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Expanded(
                                  child: Text(
                                    submitState.errorMessage!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.error,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],
                        Text(
                          '1. Was the diagnosis relevant?',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: DiagnosisRelevance.values
                              .map(
                                (option) => SymptomChip(
                                  label: option.label,
                                  selected: _relevance == option,
                                  onSelected: (_) =>
                                      setState(() => _relevance = option),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          '2. Did the recommendation resolve the issue?',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: ResolutionStatus.values
                              .map(
                                (option) => SymptomChip(
                                  label: option.label,
                                  selected: _resolutionStatus == option,
                                  onSelected: (_) => setState(
                                    () => _resolutionStatus = option,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        AppTextField(
                          controller: _commentsController,
                          label: '3. Additional comments (Optional)',
                          hint:
                              'Share what helped, parts replaced, or remaining symptoms...',
                          minLines: 3,
                          maxLines: 5,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        PrimaryButton(
                          label: existing == null
                              ? 'Submit Feedback'
                              : 'Update Feedback',
                          icon: LucideIcons.send,
                          isLoading: submitState.isSubmitting,
                          onPressed: () => _submit(
                            diagnosisId: diagnosisId,
                            isUpdate: existing != null,
                          ),
                        ),
                      ],
                    ),
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
