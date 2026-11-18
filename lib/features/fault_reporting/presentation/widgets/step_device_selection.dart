import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utilities/responsive_layout.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_dropdown_field.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/symptom_chip.dart';
import '../../../../data/models/diagnostic_catalog_model.dart';
import '../controllers/fault_report_controller.dart';

/// Maps structured dataset `icon_key` strings to consistent Lucide line icons.
IconData resolveDeviceCategoryIcon(String iconKey) {
  return switch (iconKey) {
    'smartphone' => LucideIcons.smartphone,
    'laptop' => LucideIcons.laptop,
    'desktop' => LucideIcons.monitor,
    'television' => LucideIcons.tv,
    'refrigerator' => LucideIcons.snowflake,
    'washing_machine' => LucideIcons.disc,
    'air_conditioner' => LucideIcons.wind,
    _ => LucideIcons.cpu,
  };
}

/// Step 1: Select a supported device category and provide optional device context.
class StepDeviceSelection extends StatefulWidget {
  const StepDeviceSelection({
    super.key,
    required this.categories,
    required this.state,
    required this.onSelectCategory,
    required this.onUpdateDetails,
  });

  final List<SupportedDeviceCategory> categories;
  final FaultReportingWorkflowState state;
  final ValueChanged<SupportedDeviceCategory> onSelectCategory;
  final void Function({
    String? manufacturer,
    String? modelName,
    String? deviceAge,
    bool clearDeviceAge,
    String? operatingEnvironment,
    bool clearOperatingEnvironment,
  }) onUpdateDetails;

  @override
  State<StepDeviceSelection> createState() => _StepDeviceSelectionState();
}

class _StepDeviceSelectionState extends State<StepDeviceSelection> {
  late final TextEditingController _manufacturerCtrl;
  late final TextEditingController _modelCtrl;

  @override
  void initState() {
    super.initState();
    _manufacturerCtrl = TextEditingController(text: widget.state.manufacturer);
    _modelCtrl = TextEditingController(text: widget.state.modelName);
  }

  @override
  void didUpdateWidget(covariant StepDeviceSelection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.manufacturer != _manufacturerCtrl.text) {
      _manufacturerCtrl.text = widget.state.manufacturer;
    }
    if (widget.state.modelName != _modelCtrl.text) {
      _modelCtrl.text = widget.state.modelName;
    }
  }

  @override
  void dispose() {
    _manufacturerCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final selected = widget.state.selectedCategory;
    final screenClass = AppBreakpoints.of(context);
    final columns = switch (screenClass) {
      ScreenSizeClass.compact => 2,
      ScreenSizeClass.medium => 3,
      ScreenSizeClass.expanded => 4,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Select Your Device', style: theme.textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          'Choose from device categories supported by the FixWise diagnostic knowledge base.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.contentVertical),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: widget.categories.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: screenClass == ScreenSizeClass.compact ? 1.35 : 1.45,
          ),
          itemBuilder: (context, index) {
            final category = widget.categories[index];
            final isSelected = selected?.id == category.id;
            return _CategoryCard(
              category: category,
              selected: isSelected,
              onTap: () => widget.onSelectCategory(category),
            );
          },
        ),
        if (selected != null) ...[
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Device Details (Optional)',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Adding manufacturer, model, age, or environment helps narrow down probable faults, though all fields below are optional.',
                  style: theme.textTheme.bodySmall,
                ),
                if (selected.commonManufacturers.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Common Manufacturers',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: selected.commonManufacturers.map((brand) {
                      final active = _manufacturerCtrl.text.trim().toLowerCase() ==
                          brand.toLowerCase();
                      return SymptomChip(
                        label: brand,
                        selected: active,
                        onSelected: (isSelected) {
                          final value = isSelected ? brand : '';
                          _manufacturerCtrl.text = value;
                          widget.onUpdateDetails(
                            manufacturer: value,
                            clearDeviceAge: false,
                            clearOperatingEnvironment: false,
                          );
                        },
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _manufacturerCtrl,
                  label: 'Manufacturer (Optional)',
                  hint: 'e.g., Samsung, Dell, LG',
                  textInputAction: TextInputAction.next,
                  helperText:
                      'Up to ${AppConstants.maxManufacturerLength} characters',
                  onChanged: (value) => widget.onUpdateDetails(
                    manufacturer: value,
                    clearDeviceAge: false,
                    clearOperatingEnvironment: false,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _modelCtrl,
                  label: 'Model Name / Number (Optional)',
                  hint: 'e.g., Galaxy S23, Latitude 5540',
                  textInputAction: TextInputAction.done,
                  helperText:
                      'Up to ${AppConstants.maxModelLength} characters',
                  onChanged: (value) => widget.onUpdateDetails(
                    modelName: value,
                    clearDeviceAge: false,
                    clearOperatingEnvironment: false,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppDropdownField<String>(
                  label: 'Device Age (Optional)',
                  hint: 'Select approximate age',
                  value: widget.state.deviceAge,
                  items: kDeviceAgeOptions
                      .map(
                        (age) => DropdownMenuItem(value: age, child: Text(age)),
                      )
                      .toList(),
                  onChanged: (value) => widget.onUpdateDetails(
                    deviceAge: value,
                    clearDeviceAge: value == null,
                    clearOperatingEnvironment: false,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppDropdownField<String>(
                  label: 'Operating Environment (Optional)',
                  hint: 'Select typical environment',
                  value: widget.state.operatingEnvironment,
                  items: kOperatingEnvironmentOptions
                      .map(
                        (env) => DropdownMenuItem(value: env, child: Text(env)),
                      )
                      .toList(),
                  onChanged: (value) => widget.onUpdateDetails(
                    operatingEnvironment: value,
                    clearDeviceAge: false,
                    clearOperatingEnvironment: value == null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final SupportedDeviceCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: selected
          ? AppColors.primarySurface(theme.brightness)
          : colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        side: BorderSide(
          color: selected ? colorScheme.primary : colorScheme.outline,
          width: selected ? 1.8 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm + 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                resolveDeviceCategoryIcon(category.iconKey),
                size: AppSpacing.iconLg,
                color: selected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                category.name,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: selected ? colorScheme.primary : colorScheme.onSurface,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
