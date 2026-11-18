import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utilities/validators.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_dropdown_field.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../controllers/fault_report_controller.dart';

/// Step 3: Optional error codes, onset timeframe, operating conditions, and
/// multiline problem description.
class StepAdditionalInfo extends StatefulWidget {
  const StepAdditionalInfo({
    super.key,
    required this.state,
    required this.onUpdate,
  });

  final FaultReportingWorkflowState state;
  final void Function({
    String? errorCode,
    String? problemDescription,
    String? startedWhen,
    bool clearStartedWhen,
    String? operatingConditions,
  }) onUpdate;

  @override
  State<StepAdditionalInfo> createState() => _StepAdditionalInfoState();
}

class _StepAdditionalInfoState extends State<StepAdditionalInfo> {
  late final TextEditingController _errorCodeCtrl;
  late final TextEditingController _conditionsCtrl;
  late final TextEditingController _descriptionCtrl;

  @override
  void initState() {
    super.initState();
    _errorCodeCtrl = TextEditingController(text: widget.state.errorCode);
    _conditionsCtrl =
        TextEditingController(text: widget.state.operatingConditions);
    _descriptionCtrl =
        TextEditingController(text: widget.state.problemDescription);
  }

  @override
  void didUpdateWidget(covariant StepAdditionalInfo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.errorCode != _errorCodeCtrl.text) {
      _errorCodeCtrl.text = widget.state.errorCode;
    }
    if (widget.state.operatingConditions != _conditionsCtrl.text) {
      _conditionsCtrl.text = widget.state.operatingConditions;
    }
    if (widget.state.problemDescription != _descriptionCtrl.text) {
      _descriptionCtrl.text = widget.state.problemDescription;
    }
  }

  @override
  void dispose() {
    _errorCodeCtrl.dispose();
    _conditionsCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final descLength = _descriptionCtrl.text.trim().length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Additional Information', style: theme.textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          'Provide any displayed error codes, onset timing, or technical context to refine the analysis.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.contentVertical),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                controller: _errorCodeCtrl,
                label: 'Error Code (Optional)',
                hint: 'e.g., E-04, OE, F21, 0x000000EF',
                prefixIcon: LucideIcons.terminal,
                textInputAction: TextInputAction.next,
                helperText:
                    'Up to ${AppConstants.maxErrorCodeLength} characters',
                validator: Validators.optionalErrorCode,
                onChanged: (value) => widget.onUpdate(
                  errorCode: value,
                  clearStartedWhen: false,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppDropdownField<String>(
                label: 'When Did the Problem Start? (Optional)',
                hint: 'Select timeframe',
                prefixIcon: LucideIcons.clock,
                value: widget.state.startedWhen,
                items: kProblemOnsetOptions
                    .map(
                      (item) =>
                          DropdownMenuItem(value: item, child: Text(item)),
                    )
                    .toList(),
                onChanged: (value) => widget.onUpdate(
                  startedWhen: value,
                  clearStartedWhen: value == null,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _conditionsCtrl,
                label: 'Operating Conditions (Optional)',
                hint: 'e.g., Occurs while charging, heavy load, or after power outage',
                prefixIcon: LucideIcons.gauge,
                textInputAction: TextInputAction.next,
                helperText:
                    'Up to ${AppConstants.maxOperatingConditionsLength} characters',
                onChanged: (value) => widget.onUpdate(
                  operatingConditions: value,
                  clearStartedWhen: false,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _descriptionCtrl,
                label: 'Problem Description (Optional)',
                hint:
                    'Describe what happened before the fault appeared, frequency, and any prior troubleshooting...',
                minLines: 4,
                maxLines: 6,
                helperText:
                    '$descLength / ${AppConstants.maxProblemDescriptionLength} characters • Sanitized securely on backend',
                onChanged: (value) {
                  setState(() {});
                  widget.onUpdate(
                    problemDescription: value,
                    clearStartedWhen: false,
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
