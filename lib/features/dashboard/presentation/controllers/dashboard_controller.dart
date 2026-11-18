import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/repositories/diagnosis_repository.dart';
import '../../../../data/repositories/providers.dart';

/// Holds real application data displayed on the FixWise Home Dashboard.
///
/// Deliberately contains no fabricated counts, success percentages, or charts.
class DashboardData {
  const DashboardData({
    required this.recentDiagnoses,
  });

  final List<RecentDiagnosisRecord> recentDiagnoses;
}

class DashboardController extends AsyncNotifier<DashboardData> {
  @override
  Future<DashboardData> build() async {
    final diagnosisRepo = ref.watch(diagnosisRepositoryProvider);
    final result = await diagnosisRepo.getRecentDiagnoses(limit: 3);

    final records = result.when(
      success: (items) => items,
      failure: (err) => throw err,
    );

    return DashboardData(recentDiagnoses: records);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }
}

final dashboardControllerProvider =
    AsyncNotifierProvider<DashboardController, DashboardData>(
  DashboardController.new,
);
