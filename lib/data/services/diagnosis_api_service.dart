import 'package:dio/dio.dart';

import '../../core/errors/error_mapper.dart';
import '../../core/errors/failure.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../models/diagnosis_result_model.dart';
import '../models/fault_report_model.dart';

/// Dedicated API service communicating with the Python ML diagnosis backend.
///
/// Keeps network serialization and backend error contract handling strictly
/// isolated from Flutter presentation widgets and SQLite persistence.
class DiagnosisApiService {
  DiagnosisApiService(this._apiClient);

  final ApiClient _apiClient;

  bool get isConfigured => _apiClient.isConfigured;

  /// Checks whether the Python diagnosis backend is reachable and has a
  /// verified trained model artifact loaded.
  Future<Result<Map<String, dynamic>>> fetchServiceHealth() async {
    if (!_apiClient.isConfigured) {
      return const ErrorResult(ModelNotIntegratedFailure());
    }

    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        ApiEndpoints.health,
        skipAuth: true,
      );
      return Success(response.data ?? const <String, dynamic>{});
    } catch (error) {
      return ErrorResult(ErrorMapper.mapException(error));
    }
  }

  /// Submits a structured [FaultReportModel] payload to `POST /api/v1/diagnosis/analyze`.
  Future<Result<DiagnosisResultModel>> analyzeFault(
    FaultReportModel report,
  ) async {
    if (!_apiClient.isConfigured) {
      return const ErrorResult(ModelNotIntegratedFailure());
    }

    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.analyzeFault,
        data: report.toInferencePayload(),
      );

      final data = response.data;
      if (data == null || data.isEmpty) {
        return const ErrorResult(
          ServerFailure(
            'The diagnosis service returned an empty response.',
            code: 'EMPTY_DIAGNOSIS_RESPONSE',
          ),
        );
      }

      return Success(
        DiagnosisResultModel.fromJson(
          data,
          fallbackReportId: report.id,
          fallbackDeviceName: report.deviceName,
        ),
      );
    } on DioException catch (exception) {
      final statusCode = exception.response?.statusCode;
      final body = exception.response?.data;
      final errorCode =
          body is Map<String, dynamic> ? body['code']?.toString() : null;
      final serverMessage =
          body is Map<String, dynamic> ? body['message']?.toString() : null;

      if (statusCode == 503 || errorCode == 'MODEL_INTEGRATION_PENDING') {
        return ErrorResult(
          ModelNotIntegratedFailure(
            serverMessage ??
                'Model integration is pending on the diagnosis backend. No trained model artifact is currently loaded.',
          ),
        );
      }
      if (statusCode == 422) {
        return ErrorResult(
          ValidationFailure(
            serverMessage ??
                'The fault report payload failed backend validation. Review your inputs and try again.',
          ),
        );
      }
      return ErrorResult(ErrorMapper.mapException(exception));
    } catch (error) {
      return ErrorResult(ErrorMapper.mapException(error));
    }
  }
}
