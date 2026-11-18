import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utilities/date_formatter.dart';
import '../../../../core/utilities/responsive_layout.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_confirmation_dialog.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading_indicator.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/secondary_button.dart';
import '../../../../core/widgets/severity_indicator.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../core/widgets/symptom_chip.dart';
import '../../../../data/models/fault_report_model.dart';
import '../../../../data/repositories/diagnosis_repository.dart';
import '../controllers/history_controller.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete(HistoryListItem item) async {
    final confirmed = await AppConfirmationDialog.show(
      context,
      title: 'Delete Diagnosis Record',
      message:
          'Permanently remove "${item.predictedFault}" from your diagnosis history?',
      confirmLabel: 'Delete',
      isDangerous: true,
    );

    if (!confirmed || !mounted) return;
    final error = await ref
        .read(historyControllerProvider.notifier)
        .deleteReport(item.reportId);
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(historyControllerProvider);
    final controller = ref.read(historyControllerProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnosis History'),
        actions: [
          IconButton(
            tooltip: 'Refresh history',
            onPressed: controller.refresh,
            icon: const Icon(LucideIcons.refreshCw, size: AppSpacing.iconSm),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: historyAsync.when(
        loading: () =>
            const AppLoadingIndicator(message: 'Loading diagnosis history...'),
        error: (error, _) => AppErrorState(
          message: error is Failure
              ? error.message
              : 'Unable to read diagnosis records.',
          onRetry: controller.refresh,
        ),
        data: (historyState) {
          final query = historyState.query;

          if (historyState.totalCount == 0 && !historyState.hasActiveFilters) {
            return AppEmptyState(
              icon: LucideIcons.history,
              title: 'No diagnosis records available.',
              message:
                  'Complete a device fault diagnosis to archive your results, recommendations, and feedback here.',
              actionLabel: 'Start Diagnosis',
              actionIcon: LucideIcons.activity,
              onAction: () => context.go(AppRoutes.deviceSelection),
            );
          }

          return RefreshIndicator(
            onRefresh: controller.refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: ResponsiveContentContainer(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenHorizontal,
                      AppSpacing.contentVertical,
                      AppSpacing.screenHorizontal,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Diagnosis History',
                          style: theme.textTheme.headlineMedium,
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          'Showing ${historyState.items.length} of ${historyState.totalCount} ${historyState.totalCount == 1 ? 'record' : 'records'}',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: AppSpacing.contentVertical),
                        AppTextField(
                          controller: _searchController,
                          label: 'Search by Device or Fault Category',
                          hint: 'e.g., Smartphone, Battery Degradation, AC',
                          prefixIcon: LucideIcons.search,
                          onChanged: controller.setSearch,
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  tooltip: 'Clear search',
                                  onPressed: () {
                                    _searchController.clear();
                                    controller.setSearch('');
                                  },
                                  icon: const Icon(
                                    LucideIcons.x,
                                    size: AppSpacing.iconSm,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // Date range filter bar (1W / 1M / 3M / 1Y / All)
                        Text(
                          'Date Range',
                          style: theme.textTheme.labelSmall,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: HistoryDateRange.values
                                .map(
                                  (range) => Padding(
                                    padding: const EdgeInsets.only(
                                      right: AppSpacing.xs,
                                    ),
                                    child: SymptomChip(
                                      label: range.label,
                                      selected: query.dateRange == range,
                                      onSelected: (_) =>
                                          controller.setDateRange(range),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),

                        // Severity filter chips + Sort control
                        Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            SymptomChip(
                              label: 'All Severities',
                              selected: query.severity == null,
                              onSelected: (_) => controller.setSeverity(null),
                            ),
                            ...FaultSeverity.values.map(
                              (sev) => SymptomChip(
                                label: sev.label,
                                selected: query.severity == sev,
                                onSelected: (_) => controller.setSeverity(sev),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.xs,
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Sort Order',
                              style: theme.textTheme.labelSmall,
                            ),
                            SegmentedButton<HistorySortOrder>(
                              segments: HistorySortOrder.values
                                  .map(
                                    (order) => ButtonSegment(
                                      value: order,
                                      label: Text(order.label),
                                    ),
                                  )
                                  .toList(),
                              selected: {query.sortOrder},
                              onSelectionChanged: (sel) =>
                                  controller.setSortOrder(sel.first),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.contentVertical),
                      ],
                    ),
                  ),
                ),
                if (historyState.items.isEmpty)
                  SliverToBoxAdapter(
                    child: ResponsiveContentContainer(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screenHorizontal,
                        0,
                        AppSpacing.screenHorizontal,
                        AppSpacing.xl,
                      ),
                      child: AppCard(
                        child: AppEmptyState(
                          icon: LucideIcons.searchX,
                          title: 'No matching diagnosis records',
                          message:
                              'Adjust your search keyword, severity, or date range filter.',
                          actionLabel: 'Reset Filters',
                          onAction: () {
                            _searchController.clear();
                            controller.resetFilters();
                          },
                        ),
                      ),
                    ),
                  )
                else ...[
                  SliverList.builder(
                    itemCount: historyState.items.length,
                    itemBuilder: (context, index) {
                      final item = historyState.items[index];
                      return ResponsiveContentContainer(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.screenHorizontal,
                          0,
                          AppSpacing.screenHorizontal,
                          AppSpacing.sm,
                        ),
                        child: _HistoryItemCard(
                          item: item,
                          onViewDetails: () => context.push(
                            AppRoutes.diagnosisPath(item.reportId),
                          ),
                          onDelete: () => _confirmDelete(item),
                        ),
                      );
                    },
                  ),
                  if (historyState.hasMore)
                    SliverToBoxAdapter(
                      child: ResponsiveContentContainer(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.screenHorizontal,
                          AppSpacing.xs,
                          AppSpacing.screenHorizontal,
                          AppSpacing.xl,
                        ),
                        child: SecondaryButton(
                          label: 'Load More Records',
                          icon: LucideIcons.chevronDown,
                          isLoading: historyState.isLoadingMore,
                          onPressed: controller.loadMore,
                        ),
                      ),
                    )
                  else
                    const SliverToBoxAdapter(
                      child: SizedBox(height: AppSpacing.xl),
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HistoryItemCard extends StatelessWidget {
  const _HistoryItemCard({
    required this.item,
    required this.onViewDetails,
    required this.onDelete,
  });

  final HistoryListItem item;
  final VoidCallback onViewDetails;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppCard(
      onTap: onViewDetails,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.deviceCategory.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.predictedFault,
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Delete record',
                visualDensity: VisualDensity.compact,
                onPressed: onDelete,
                icon: Icon(
                  LucideIcons.trash2,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            '${item.deviceName} • ${DateFormatter.formatDateTime(item.diagnosedAt)}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              SeverityIndicator(severity: item.severity),
              StatusBadge(
                label: item.status.label,
                tone: switch (item.status) {
                  FaultReportStatus.pendingDiagnosis => BadgeTone.warning,
                  FaultReportStatus.diagnosed => BadgeTone.info,
                  FaultReportStatus.resolved => BadgeTone.safe,
                },
              ),
              if (item.hasFeedback)
                const StatusBadge(
                  label: 'Feedback Logged',
                  tone: BadgeTone.safe,
                  icon: LucideIcons.circleCheck,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const Divider(),
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'View details',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Icon(
                LucideIcons.chevronRight,
                size: AppSpacing.iconSm,
                color: colorScheme.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
