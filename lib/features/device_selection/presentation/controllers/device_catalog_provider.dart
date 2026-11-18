import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/diagnostic_catalog_model.dart';
import '../../../../data/repositories/providers.dart';

/// Loads supported device categories and categorized symptom definitions from
/// the backend configuration or bundled FixWise structured knowledge base.
final diagnosticCatalogProvider =
    FutureProvider<DiagnosticCatalog>((ref) async {
  final result =
      await ref.watch(diagnosticCatalogRepositoryProvider).loadCatalog();

  return result.when(
    success: (catalog) => catalog,
    failure: (err) => throw err,
  );
});
