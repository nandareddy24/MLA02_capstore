import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utilities/responsive_layout.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading_indicator.dart';
import '../../../../core/widgets/fixwise_brand_mark.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../controllers/dashboard_controller.dart';
import '../widgets/diagnose_action_card.dart';
import '../widgets/help_guidance_sheet.dart';
import '../widgets/quick_access_section.dart';
import '../widgets/recent_diagnosis_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _timeOfDayGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _extractInitials(String? fullName) {
    if (fullName == null || fullName.trim().isEmpty) return 'FW';
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final dashboardAsync = ref.watch(dashboardControllerProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final fullName = authState.user?.fullName.trim();
    final firstName =
        (fullName != null && fullName.isNotEmpty) ? fullName.split(' ').first : null;
    final greeting = firstName != null
        ? '${_timeOfDayGreeting()}, $firstName'
        : _timeOfDayGreeting();

    return Scaffold(
      appBar: AppBar(
        title: const FixWiseBrandMark(size: 30, showWordmark: true),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.screenHorizontal),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
              onTap: () => context.go(AppRoutes.profile),
              child: Semantics(
                button: true,
                label: 'Open profile',
                child: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface(theme.brightness),
                    borderRadius: BorderRadius.circular(
                      AppSpacing.inputRadius,
                    ),
                    border: Border.all(color: colorScheme.outline),
                  ),
                  child: Text(
                    _extractInitials(fullName),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(dashboardControllerProvider.notifier).refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            ResponsiveContentContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    greeting,
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'What would you like to diagnose today?',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.contentVertical),
                  DiagnoseActionCard(
                    onStartDiagnosis: () =>
                        context.go(AppRoutes.deviceSelection),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Quick Access',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  QuickAccessSection(
                    onNewDiagnosis: () =>
                        context.go(AppRoutes.deviceSelection),
                    onHistory: () => context.go(AppRoutes.history),
                    onHelpGuidance: () => showHelpGuidanceSheet(context),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Recent Diagnoses',
                          style: theme.textTheme.titleLarge,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (dashboardAsync.asData?.value.recentDiagnoses.isNotEmpty ==
                          true)
                        TextButton(
                          onPressed: () => context.go(AppRoutes.history),
                          child: const Text('View all'),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  dashboardAsync.when(
                    loading: () => const AppCard(
                      child: AppLoadingIndicator(
                        message: 'Loading recent diagnoses...',
                      ),
                    ),
                    error: (error, _) => AppCard(
                      child: AppErrorState(
                        title: 'Unable to load recent diagnoses',
                        message: error is Failure
                            ? error.message
                            : 'An error occurred while reading diagnosis records.',
                        onRetry: () => ref
                            .read(dashboardControllerProvider.notifier)
                            .refresh(),
                      ),
                    ),
                    data: (data) {
                      if (data.recentDiagnoses.isEmpty) {
                        return const AppCard(
                          child: AppEmptyState(
                            icon: LucideIcons.clipboardList,
                            title: 'No diagnosis records yet.',
                            message: 'Your completed diagnoses will appear here.',
                          ),
                        );
                      }

                      return Column(
                        children: data.recentDiagnoses
                            .map(
                              (record) => Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.sm,
                                ),
                                child: RecentDiagnosisCard(
                                  record: record,
                                  onViewDetails: () => context.push(
                                    AppRoutes.diagnosisPath(record.reportId),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
