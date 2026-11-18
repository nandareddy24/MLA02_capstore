import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/api_client.dart';
import '../services/decision_support_api_service.dart';
import '../services/diagnosis_api_service.dart';
import '../services/local_database_service.dart';
import '../services/preferences_service.dart';
import '../services/secure_storage_service.dart';
import 'auth_repository.dart';
import 'device_repository.dart';
import 'diagnosis_repository.dart';
import 'diagnostic_catalog_repository.dart';
import 'fault_report_repository.dart';
import 'feedback_repository.dart';

/// Must be overridden in `ProviderScope` during app bootstrap in `main.dart`.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in ProviderScope.',
  );
});

final preferencesServiceProvider = Provider<PreferencesService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return PreferencesService(prefs);
});

final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final localDatabaseServiceProvider = Provider<LocalDatabaseService>((ref) {
  final service = LocalDatabaseService();
  ref.onDispose(service.close);
  return service;
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    preferencesService: ref.watch(preferencesServiceProvider),
    secureStorageService: ref.watch(secureStorageServiceProvider),
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    apiClient: ref.watch(apiClientProvider),
    databaseService: ref.watch(localDatabaseServiceProvider),
    preferencesService: ref.watch(preferencesServiceProvider),
    secureStorageService: ref.watch(secureStorageServiceProvider),
  );
});

final deviceRepositoryProvider = Provider<DeviceRepository>((ref) {
  return DeviceRepositoryImpl(ref.watch(localDatabaseServiceProvider));
});

final diagnosticCatalogRepositoryProvider =
    Provider<DiagnosticCatalogRepository>((ref) {
  return DiagnosticCatalogRepositoryImpl(
    apiClient: ref.watch(apiClientProvider),
  );
});

final faultReportRepositoryProvider = Provider<FaultReportRepository>((ref) {
  return FaultReportRepositoryImpl(
    databaseService: ref.watch(localDatabaseServiceProvider),
    preferencesService: ref.watch(preferencesServiceProvider),
  );
});

final diagnosisApiServiceProvider = Provider<DiagnosisApiService>((ref) {
  return DiagnosisApiService(ref.watch(apiClientProvider));
});

final decisionSupportApiServiceProvider =
    Provider<DecisionSupportApiService>((ref) {
  return DecisionSupportApiService(ref.watch(apiClientProvider));
});

final diagnosisRepositoryProvider = Provider<DiagnosisRepository>((ref) {
  return DiagnosisRepositoryImpl(
    apiService: ref.watch(diagnosisApiServiceProvider),
    databaseService: ref.watch(localDatabaseServiceProvider),
    preferencesService: ref.watch(preferencesServiceProvider),
  );
});

final feedbackRepositoryProvider = Provider<FeedbackRepository>((ref) {
  return FeedbackRepositoryImpl(
    databaseService: ref.watch(localDatabaseServiceProvider),
    apiClient: ref.watch(apiClientProvider),
    preferencesService: ref.watch(preferencesServiceProvider),
  );
});
