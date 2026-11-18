import 'dart:convert';

import 'package:flutter/services.dart';

import '../../core/errors/error_mapper.dart';
import '../../core/errors/failure.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../models/diagnostic_catalog_model.dart';

/// Supplies supported device categories and categorized symptom definitions
/// from the backend configuration or bundled FixWise structured dataset.
abstract interface class DiagnosticCatalogRepository {
  Future<Result<DiagnosticCatalog>> loadCatalog();
}

class DiagnosticCatalogRepositoryImpl implements DiagnosticCatalogRepository {
  DiagnosticCatalogRepositoryImpl({
    required ApiClient apiClient,
    AssetBundle? assetBundle,
  })  : _apiClient = apiClient,
        _assetBundle = assetBundle ?? rootBundle;

  static const String _bundledCatalogPath =
      'assets/data/diagnostic_catalog.json';

  final ApiClient _apiClient;
  final AssetBundle _assetBundle;
  DiagnosticCatalog? _memoryCache;

  @override
  Future<Result<DiagnosticCatalog>> loadCatalog() async {
    if (_memoryCache != null) {
      return Success(_memoryCache!);
    }

    // Prefer live backend catalog when API is configured so categories stay synced
    // with the deployed ML model's exact supported classes.
    if (_apiClient.isConfigured) {
      try {
        final response = await _apiClient.get<Map<String, dynamic>>(
          ApiEndpoints.diagnosticCatalog,
        );
        final body = response.data;
        if (body != null && body['categories'] is List) {
          final catalog = DiagnosticCatalog.fromJson(body, fromBackend: true);
          if (catalog.supportedCategories.isNotEmpty) {
            _memoryCache = catalog;
            return Success(catalog);
          }
        }
      } catch (_) {
        // Fall through cleanly to bundled structured dataset for offline support.
      }
    }

    try {
      final rawJson = await _assetBundle.loadString(_bundledCatalogPath);
      final decoded = jsonDecode(rawJson);
      if (decoded is! Map<String, dynamic>) {
        return const ErrorResult(
          CacheFailure('Diagnostic catalog configuration is malformed.'),
        );
      }
      final catalog = DiagnosticCatalog.fromJson(decoded, fromBackend: false);
      _memoryCache = catalog;
      return Success(catalog);
    } catch (error) {
      return ErrorResult(ErrorMapper.mapException(error));
    }
  }
}
