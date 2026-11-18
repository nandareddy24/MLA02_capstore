import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/fault_report_model.dart';
import '../../../../data/repositories/diagnosis_repository.dart';
import '../../../../data/repositories/providers.dart';
import '../../../dashboard/presentation/controllers/dashboard_controller.dart';

/// Immutable paginated, filtered diagnosis history state for the authenticated user.
class HistoryState {
  const HistoryState({
    required this.query,
    required this.items,
    required this.totalCount,
    required this.hasMore,
    this.isLoadingMore = false,
  });

  final HistoryQuery query;
  final List<HistoryListItem> items;
  final int totalCount;
  final bool hasMore;
  final bool isLoadingMore;

  bool get hasActiveFilters =>
      query.search.trim().isNotEmpty ||
      query.severity != null ||
      query.dateRange != HistoryDateRange.all;

  HistoryState copyWith({
    HistoryQuery? query,
    List<HistoryListItem>? items,
    int? totalCount,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return HistoryState(
      query: query ?? this.query,
      items: items ?? this.items,
      totalCount: totalCount ?? this.totalCount,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class HistoryController extends AsyncNotifier<HistoryState> {
  HistoryQuery _currentQuery = const HistoryQuery();

  @override
  Future<HistoryState> build() async {
    return _fetchPage(_currentQuery.copyWith(page: 1));
  }

  Future<HistoryState> _fetchPage(HistoryQuery query) async {
    final result =
        await ref.read(diagnosisRepositoryProvider).queryHistory(query);
    return result.when(
      success: (page) => HistoryState(
        query: query,
        items: page.items,
        totalCount: page.totalCount,
        hasMore: page.hasMore,
      ),
      failure: (err) => throw err,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchPage(_currentQuery.copyWith(page: 1)));
  }

  Future<void> setSearch(String value) async {
    _currentQuery = _currentQuery.copyWith(search: value, page: 1);
    state = await AsyncValue.guard(() => _fetchPage(_currentQuery));
  }

  Future<void> setSeverity(FaultSeverity? severity) async {
    _currentQuery = severity == null
        ? _currentQuery.copyWith(clearSeverity: true, page: 1)
        : _currentQuery.copyWith(severity: severity, page: 1);
    state = await AsyncValue.guard(() => _fetchPage(_currentQuery));
  }

  Future<void> setDateRange(HistoryDateRange range) async {
    _currentQuery = _currentQuery.copyWith(dateRange: range, page: 1);
    state = await AsyncValue.guard(() => _fetchPage(_currentQuery));
  }

  Future<void> setSortOrder(HistorySortOrder order) async {
    _currentQuery = _currentQuery.copyWith(sortOrder: order, page: 1);
    state = await AsyncValue.guard(() => _fetchPage(_currentQuery));
  }

  Future<void> resetFilters() async {
    _currentQuery = const HistoryQuery();
    state = await AsyncValue.guard(() => _fetchPage(_currentQuery));
  }

  Future<void> loadMore() async {
    final current = state.asData?.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    final nextQuery = _currentQuery.copyWith(page: current.query.page + 1);
    final result =
        await ref.read(diagnosisRepositoryProvider).queryHistory(nextQuery);

    result.when(
      success: (page) {
        _currentQuery = nextQuery;
        state = AsyncData(
          HistoryState(
            query: nextQuery,
            items: [...current.items, ...page.items],
            totalCount: page.totalCount,
            hasMore: page.hasMore,
            isLoadingMore: false,
          ),
        );
      },
      failure: (_) {
        state = AsyncData(current.copyWith(isLoadingMore: false));
      },
    );
  }

  Future<String?> deleteReport(String id) async {
    final result =
        await ref.read(faultReportRepositoryProvider).deleteReport(id);
    return result.when(
      success: (_) {
        ref.invalidateSelf();
        ref.invalidate(dashboardControllerProvider);
        return null;
      },
      failure: (err) => err.message,
    );
  }
}

final historyControllerProvider =
    AsyncNotifierProvider<HistoryController, HistoryState>(
  HistoryController.new,
);
