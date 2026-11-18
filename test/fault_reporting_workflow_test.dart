import 'dart:async';

import 'package:fixwise/core/errors/failure.dart';
import 'package:fixwise/core/theme/app_theme.dart';
import 'package:fixwise/data/models/diagnosis_result_model.dart';
import 'package:fixwise/data/models/diagnostic_catalog_model.dart';
import 'package:fixwise/data/models/fault_report_model.dart';
import 'package:fixwise/data/repositories/diagnosis_repository.dart';
import 'package:fixwise/data/repositories/diagnostic_catalog_repository.dart';
import 'package:fixwise/data/repositories/fault_report_repository.dart';
import 'package:fixwise/data/repositories/providers.dart';
import 'package:fixwise/features/fault_reporting/presentation/screens/fault_reporting_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StubCatalogRepo implements DiagnosticCatalogRepository {
  @override
  Future<Result<DiagnosticCatalog>> loadCatalog() async {
    return const Success(
      DiagnosticCatalog(
        version: '1.0.0',
        categories: [
          SupportedDeviceCategory(
            id: 'smartphone',
            name: 'Smartphone',
            iconKey: 'smartphone',
            isSupported: true,
            commonManufacturers: ['Samsung', 'Apple'],
            symptomGroups: [
              SymptomGroup(
                id: 'power',
                name: 'Power & Battery',
                symptoms: [
                  SymptomItem(id: 'sp_drain', label: 'Rapid battery drain'),
                  SymptomItem(id: 'sp_no_charge', label: 'Not charging'),
                ],
              ),
              SymptomGroup(
                id: 'thermal',
                name: 'Thermal',
                symptoms: [
                  SymptomItem(id: 'sp_heat', label: 'Overheating'),
                ],
              ),
            ],
          ),
          SupportedDeviceCategory(
            id: 'unsupported_printer',
            name: 'Unsupported Printer',
            iconKey: 'other',
            isSupported: false,
            commonManufacturers: [],
            symptomGroups: [],
          ),
        ],
      ),
    );
  }
}

class _InMemoryFaultReportRepo implements FaultReportRepository {
  final List<FaultReportModel> created = [];

  @override
  Future<Result<FaultReportModel>> createReport(FaultReportModel report) async {
    created.add(report);
    return Success(report);
  }

  @override
  Future<Result<void>> deleteReport(String id) async => const Success(null);

  @override
  Future<Result<List<FaultReportModel>>> getAllReports() async =>
      Success(List.unmodifiable(created));

  @override
  Future<Result<FaultReportModel?>> getReportById(String id) async =>
      const Success(null);

  @override
  Future<Result<void>> updateReportStatus(
    String reportId,
    FaultReportStatus status,
  ) async =>
      const Success(null);
}

class _ControlledDiagnosisRepo implements DiagnosisRepository {
  int callCount = 0;
  Completer<Result<DiagnosisResultModel>>? pendingCompleter;
  Failure? failureToReturn;

  @override
  Future<Result<DiagnosisResultModel?>> getCachedDiagnosis(
    String reportId,
  ) async =>
      const Success(null);

  @override
  Future<Result<List<RecentDiagnosisRecord>>> getRecentDiagnoses({
    int limit = 3,
  }) async =>
      const Success([]);

  @override
  Future<Result<PaginatedHistoryResult>> queryHistory(
    HistoryQuery query,
  ) async =>
      Success(
        PaginatedHistoryResult(
          items: const [],
          totalCount: 0,
          page: query.page,
          pageSize: query.pageSize,
          hasMore: false,
        ),
      );

  @override
  Future<Result<DiagnosisResultModel>> runDiagnosis(
    FaultReportModel report,
  ) async {
    callCount += 1;
    if (pendingCompleter != null) {
      return pendingCompleter!.future;
    }
    if (failureToReturn != null) {
      return ErrorResult(failureToReturn!);
    }
    return Success(
      DiagnosisResultModel(
        id: 'diag_1',
        reportId: report.id,
        primaryFault: 'Battery Cell Degradation',
        confidence: 0.88,
        summary: 'Backend verified result.',
        modelVersion: '1.0',
        analyzedAt: DateTime(2026),
      ),
    );
  }
}

void main() {
  testWidgets(
      'Guided 4-step workflow enforces validation, preserves state, blocks duplicates, and handles backend failures with retry',
      (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final reportRepo = _InMemoryFaultReportRepo();
    final diagnosisRepo = _ControlledDiagnosisRepo()
      ..failureToReturn = const NetworkFailure(
        'Server unreachable. Check your connection.',
      );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          diagnosticCatalogRepositoryProvider
              .overrideWithValue(_StubCatalogRepo()),
          faultReportRepositoryProvider.overrideWithValue(reportRepo),
          diagnosisRepositoryProvider.overrideWithValue(diagnosisRepo),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const FaultReportingScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Step 1: Only supported categories are advertised
    expect(find.text('Select Your Device'), findsOneWidget);
    expect(find.text('Smartphone'), findsOneWidget);
    expect(find.text('Unsupported Printer'), findsNothing);

    // Requires device category before continuing
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(
      find.text('Please select a supported device category to continue.'),
      findsOneWidget,
    );

    // Select Smartphone and tap optional manufacturer chip
    await tester.tap(find.text('Smartphone'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Samsung'));
    await tester.tap(find.text('Samsung'));
    await tester.pumpAndSettle();

    // Advance to Step 2
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Describe the Problem'), findsOneWidget);
    expect(find.text('0 selected'), findsOneWidget);

    // Requires at least one symptom
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(
      find.text('Select at least one observed symptom to continue.'),
      findsOneWidget,
    );

    // Search and select multiple symptoms
    await tester.enterText(find.byType(TextFormField).first, 'Overheat');
    await tester.pumpAndSettle();
    expect(find.text('Overheating'), findsOneWidget);
    expect(find.text('Rapid battery drain'), findsNothing);

    await tester.tap(find.text('Overheating'));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);

    // Clear search and select a second symptom
    await tester.enterText(find.byType(TextFormField).first, '');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rapid battery drain'));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);

    // Advance to Step 3: Additional Information
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Additional Information'), findsWidgets);

    await tester.enterText(find.byType(TextFormField).at(0), 'ERR-BAT-09');
    await tester.enterText(
      find.byType(TextFormField).at(2),
      'Phone gets hot when plugged into fast charger.',
    );
    await tester.pumpAndSettle();

    // Navigate Back to Step 2 and forward again — state must be preserved
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('ERR-BAT-09'), findsOneWidget);

    // Advance to Step 4: Review & Submit
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    expect(find.text('Review & Submit'), findsWidgets);
    expect(find.text('Samsung'), findsOneWidget);
    expect(find.text('ERR-BAT-09'), findsOneWidget);
    expect(find.text('Overheating'), findsOneWidget);
    expect(find.text('Rapid battery drain'), findsOneWidget);

    // Edit button returns cleanly to Step 1
    await tester.tap(find.text('Edit').first);
    await tester.pumpAndSettle();
    expect(find.text('Select Your Device'), findsOneWidget);

    // Return to Step 4
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();

    // Submit with controlled async completer to verify loading screen & no double submit
    diagnosisRepo.pendingCompleter = Completer<Result<DiagnosisResultModel>>();
    await tester.tap(find.text('Analyze Problem'));
    await tester.pump();

    expect(find.text('Analyzing reported symptoms'), findsOneWidget);
    expect(diagnosisRepo.callCount, 1);

    // Resolve with server failure — must NOT fabricate results and must offer Retry
    diagnosisRepo.pendingCompleter!.complete(
      const ErrorResult(
        NetworkFailure('Server unreachable. Check your connection.'),
      ),
    );
    diagnosisRepo.pendingCompleter = null;
    await tester.pumpAndSettle();

    expect(find.text('Unable to Complete Analysis'), findsOneWidget);
    expect(find.text('Retry Analysis'), findsOneWidget);
    expect(reportRepo.created.length, 1);

    // Retry reuses saved report (no duplicate DB insert!)
    await tester.tap(find.text('Retry Analysis'));
    await tester.pumpAndSettle();
    expect(reportRepo.created.length, 1);
    expect(diagnosisRepo.callCount, 2);
  });
}
